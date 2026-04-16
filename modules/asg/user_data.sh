#!/bin/bash

# Log the startup
LOG_FILE="/var/log/user-data.log"
echo "User data script started at $(date)" >> $LOG_FILE 2>&1

# Set up logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log "=== Starting Instance Initialization ==="

# Update system
log "Updating system packages..."
yum update -y >> $LOG_FILE 2>&1

# Install and start SSM Agent
log "Installing SSM Agent..."
yum install -y amazon-ssm-agent >> $LOG_FILE 2>&1
systemctl start amazon-ssm-agent >> $LOG_FILE 2>&1
systemctl enable amazon-ssm-agent >> $LOG_FILE 2>&1

# Install Docker
log "Installing Docker..."
yum install -y docker >> $LOG_FILE 2>&1 || { log "Docker installation failed"; exit 1; }
systemctl start docker >> $LOG_FILE 2>&1
systemctl enable docker >> $LOG_FILE 2>&1
usermod -a -G docker ec2-user >> $LOG_FILE 2>&1

# Verify AWS CLI is available
log "Verifying AWS CLI..."
aws --version >> $LOG_FILE 2>&1

# Deploy application from ECR
log "=== Starting Application Deployment from ECR ==="

# Configuration
REGION="eu-central-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION 2>/dev/null || echo "")

if [ -z "$ACCOUNT_ID" ]; then
    log "ERROR: Could not retrieve AWS Account ID. EC2 instance may not have proper IAM role."
    exit 1
fi

ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# Detect repository name from instance tags
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
INSTANCE_NAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --region $REGION --query 'Tags[0].Value' --output text 2>/dev/null || echo "")

if [[ "$INSTANCE_NAME" == *"Frontend"* ]] || [[ "$INSTANCE_NAME" == *"frontend"* ]]; then
    REPOSITORY_NAME="monitoring-apps-frontend"
else
    REPOSITORY_NAME="monitoring-apps-api"
fi

MAX_RETRIES=3
RETRY_DELAY=10

# Set container and port configuration based on repository type
if [[ "$REPOSITORY_NAME" == *"api"* ]]; then
    CONTAINER_NAME="api"
    CONTAINER_PORT="3000"
    LOCAL_PORT="8080"
else
    CONTAINER_NAME="frontend-app"
    CONTAINER_PORT="80"
    LOCAL_PORT="80"
fi

log "ECR Registry: $ECR_REGISTRY"
log "Repository: $REPOSITORY_NAME"
log "Container: $CONTAINER_NAME, Ports: $LOCAL_PORT:$CONTAINER_PORT"

# Login to ECR with retries
log "Logging into ECR..."
RETRY_COUNT=0
until aws ecr get-login-password --region $REGION 2>/dev/null | docker login --username AWS --password-stdin $ECR_REGISTRY >> $LOG_FILE 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge 3 ]; then
        log "ERROR: Failed to login to ECR after 3 attempts. Continuing with httpd fallback..."
        break
    fi
    log "ECR login failed, retrying in $RETRY_DELAY seconds... (Attempt $RETRY_COUNT/3)"
    sleep $RETRY_DELAY
done

# Pull and deploy image
IMAGE_URI="$ECR_REGISTRY/$REPOSITORY_NAME:latest"
log "Pulling image: $IMAGE_URI"

RETRY_COUNT=0
until docker pull $IMAGE_URI >> $LOG_FILE 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        log "WARNING: Failed to pull Docker image after $MAX_RETRIES attempts. Starting httpd fallback..."
        break
    fi
    log "Pull failed, retrying in $RETRY_DELAY seconds... (Attempt $RETRY_COUNT/$MAX_RETRIES)"
    sleep $RETRY_DELAY
done

# Check if image was pulled successfully
if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$IMAGE_URI"; then
    log "Image pulled successfully. Stopping any existing container..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
    
    # Fetch database credentials and SOAR webhook URL from SSM Parameter Store (for API containers)
    DB_SERVER=""
    DB_PORT=""
    DB_NAME=""
    DB_USER=""
    DB_PASSWORD=""
    SOAR_WEBHOOK_URL=""
    
    if [[ "$REPOSITORY_NAME" == *"api"* ]]; then
        log "Fetching database credentials from SSM Parameter Store..."
        DB_SERVER=$(aws ssm get-parameter --name /apps/api/DB_SERVER --query 'Parameter.Value' --output text --region $REGION 2>/dev/null || echo "")
        DB_PORT=$(aws ssm get-parameter --name /apps/api/DB_PORT --query 'Parameter.Value' --output text --region $REGION 2>/dev/null || echo "5432")
        DB_NAME=$(aws ssm get-parameter --name /apps/api/DB_NAME --query 'Parameter.Value' --output text --region $REGION 2>/dev/null || echo "appdb")
        DB_USER=$(aws ssm get-parameter --name /apps/api/DB_USER --query 'Parameter.Value' --output text --region $REGION 2>/dev/null || echo "postgres")
        DB_PASSWORD=$(aws ssm get-parameter --name /apps/api/DB_PASSWORD --with-decryption --query 'Parameter.Value' --output text --region $REGION 2>/dev/null || echo "")
        SOAR_WEBHOOK_URL=$(aws ssm get-parameter --name /apps/api/SOAR_WEBHOOK_URL --query 'Parameter.Value' --output text --region $REGION 2>/dev/null || echo "")
        
        if [ -z "$DB_SERVER" ] || [ -z "$DB_PASSWORD" ]; then
            log "WARNING: Database credentials not fully loaded from SSM Parameter Store"
        else
            log "Database credentials loaded successfully"
        fi
        
        if [ -z "$SOAR_WEBHOOK_URL" ]; then
            log "WARNING: SOAR_WEBHOOK_URL not loaded from SSM Parameter Store"
        else
            log "SOAR webhook URL loaded successfully"
        fi
    fi
    
    log "Starting application container..."
    
    # Build docker run command with optional environment variables
    DOCKER_RUN_CMD="docker run -d --name $CONTAINER_NAME --restart unless-stopped -p $LOCAL_PORT:$CONTAINER_PORT"
    
    if [ -n "$DB_SERVER" ]; then
        DOCKER_RUN_CMD="$DOCKER_RUN_CMD -e DB_SERVER=\"$DB_SERVER\" -e DB_PORT=\"$DB_PORT\" -e DB_NAME=\"$DB_NAME\" -e DB_USER=\"$DB_USER\" -e DB_PASSWORD=\"$DB_PASSWORD\""
    fi
    
    if [ -n "$SOAR_WEBHOOK_URL" ]; then
        DOCKER_RUN_CMD="$DOCKER_RUN_CMD -e SOAR_WEBHOOK_URL=\"$SOAR_WEBHOOK_URL\""
    fi
    
    DOCKER_RUN_CMD="$DOCKER_RUN_CMD $IMAGE_URI"
    
    eval $DOCKER_RUN_CMD >> $LOG_FILE 2>&1
    
    log "Container started successfully. Application is running."
else
    log "WARNING: Could not pull Docker image. Starting httpd fallback..."
    # Fallback: Install httpd if Docker deployment fails
    yum install -y httpd >> $LOG_FILE 2>&1
    mkdir -p /var/www/html
    cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>Application Loading</title>
</head>
<body>
    <h1>Application is initializing...</h1>
    <p>If you see this message, the Docker image is still being pulled or the deployment is in progress.</p>
</body>
</html>
HTMLEOF
    systemctl start httpd >> $LOG_FILE 2>&1
    systemctl enable httpd >> $LOG_FILE 2>&1
fi

# --- Node Exporter (for Prometheus) ---
log "Setting up Node Exporter..."
useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true

curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.linux-amd64.tar.gz >> $LOG_FILE 2>&1 || { log "node_exporter download failed"; }
tar xzf node_exporter-1.8.1.linux-amd64.tar.gz >> $LOG_FILE 2>&1 || { log "node_exporter tar failed"; }
cp node_exporter-1.8.1.linux-amd64/node_exporter /usr/local/bin/ >> $LOG_FILE 2>&1 || { log "node_exporter copy failed"; }
chown node_exporter:node_exporter /usr/local/bin/node_exporter >> $LOG_FILE 2>&1 || { log "node_exporter chown failed"; }

cat >/etc/systemd/system/node_exporter.service <<'EOFNE'
[Unit]
Description=Node Exporter
After=network-online.target
Wants=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100

[Install]
WantedBy=multi-user.target
EOFNE

systemctl daemon-reload >> /var/log/user-data.log 2>&1 || echo "systemctl daemon-reload failed" >> /var/log/user-data.log
systemctl enable node_exporter >> /var/log/user-data.log 2>&1 || echo "node_exporter enable failed" >> /var/log/user-data.log
systemctl start node_exporter >> /var/log/user-data.log 2>&1 || echo "node_exporter start failed" >> /var/log/user-data.log

echo "User data script completed at $(date)" >> /var/log/user-data.log 2>&1
