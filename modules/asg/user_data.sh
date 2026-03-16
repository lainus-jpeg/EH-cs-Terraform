#!/bin/bash

# Log the startup
echo "User data script started at $(date)" >> /var/log/user-data.log 2>&1

# Update system
yum update -y >> /var/log/user-data.log 2>&1

# Install Docker
amazon-linux-extras install docker -y >> /var/log/user-data.log 2>&1 || echo "docker install failed" >> /var/log/user-data.log

# Start Docker service
systemctl start docker >> /var/log/user-data.log 2>&1 || echo "docker start failed" >> /var/log/user-data.log
systemctl enable docker >> /var/log/user-data.log 2>&1 || echo "docker enable failed" >> /var/log/user-data.log

# Install and start SSM Agent for remote access
echo "Installing SSM Agent..." >> /var/log/user-data.log 2>&1
yum install -y amazon-ssm-agent >> /var/log/user-data.log 2>&1
systemctl enable amazon-ssm-agent >> /var/log/user-data.log 2>&1
systemctl start amazon-ssm-agent >> /var/log/user-data.log 2>&1
echo "SSM Agent started" >> /var/log/user-data.log 2>&1

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" >> /var/log/user-data.log 2>&1
unzip awscliv2.zip >> /var/log/user-data.log 2>&1
./aws/install >> /var/log/user-data.log 2>&1
rm -rf aws awscliv2.zip >> /var/log/user-data.log 2>&1

# Install Node Exporter for Prometheus monitoring
echo "Installing Node Exporter..." >> /var/log/user-data.log 2>&1
yum install -y node_exporter >> /var/log/user-data.log 2>&1 || {
  NODE_EXPORTER_VERSION="1.7.0"
  NODE_EXPORTER_BINARY="node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64"
  cd /tmp
  curl -L "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${NODE_EXPORTER_BINARY}.tar.gz" -o ${NODE_EXPORTER_BINARY}.tar.gz >> /var/log/user-data.log 2>&1
  tar xzf ${NODE_EXPORTER_BINARY}.tar.gz >> /var/log/user-data.log 2>&1
  cp ${NODE_EXPORTER_BINARY}/node_exporter /usr/local/bin/ >> /var/log/user-data.log 2>&1
  chmod +x /usr/local/bin/node_exporter >> /var/log/user-data.log 2>&1
  rm -rf ${NODE_EXPORTER_BINARY}* >> /var/log/user-data.log 2>&1
}

# Create Node Exporter systemd service
cat > /etc/systemd/system/node-exporter.service << 'NODEEOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/node_exporter --collector.uname.release=true
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
NODEEOF

systemctl daemon-reload >> /var/log/user-data.log 2>&1
systemctl start node-exporter >> /var/log/user-data.log 2>&1
systemctl enable node-exporter >> /var/log/user-data.log 2>&1
echo "Node Exporter started" >> /var/log/user-data.log 2>&1

# Create deployment script
cat > /usr/local/bin/deploy-docker.sh << 'EOF'
#!/bin/bash

LOG_FILE=/var/log/deploy-docker.log

{
  echo "Deployment started at $(date)"
  
  # Get instance metadata
  INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
  AVAILABILITY_ZONE=$(ec2-metadata --availability-zone | cut -d " " -f 2)
  REGION=${AVAILABILITY_ZONE%?}  # Remove last character (a/b/c) from AZ
  
  echo "Instance ID: $INSTANCE_ID"
  echo "Region: $REGION"
  
  # Wait for tags to propagate (retry up to 30 times, 2 seconds each)
  # Try Name tag first, then aws:autoscaling:groupName tag
  INSTANCE_NAME=""
  ASG_NAME=""
  
  for i in {1..30}; do
    # Get all tags efficiently
    TAG_DATA=$(aws ec2 describe-instances \
      --instance-ids "$INSTANCE_ID" \
      --region "$REGION" \
      --query 'Reservations[0].Instances[0].Tags' \
      --output json 2>/dev/null)
    
    # Extract Name tag value
    INSTANCE_NAME=$(echo "$TAG_DATA" | grep -o '"Key":"Name"' -A 2 | grep -o '"Value":"[^"]*' | cut -d'"' -f4)
    
    # Extract aws:autoscaling:groupName tag value
    ASG_NAME=$(echo "$TAG_DATA" | grep -o '"Key":"aws:autoscaling:groupName"' -A 2 | grep -o '"Value":"[^"]*' | cut -d'"' -f4)
    
    if [ ! -z "$INSTANCE_NAME" ] || [ ! -z "$ASG_NAME" ]; then
      [ ! -z "$INSTANCE_NAME" ] && echo "Instance Name tag retrieved: $INSTANCE_NAME"
      [ ! -z "$ASG_NAME" ] && echo "ASG Name tag retrieved: $ASG_NAME"
      break
    fi
    
    if [ $i -lt 30 ]; then
      echo "Waiting for tags to propagate... (attempt $i/30)"
      sleep 2
    fi
  done
  
  echo "Final Instance Name: $INSTANCE_NAME"
  echo "Final ASG Name from tag: $ASG_NAME"
  
  # Determine which image to deploy based on instance name or ASG name
  if [[ "$INSTANCE_NAME" == *"Frontend"* ]]; then
    PARAM_NAME="/apps/frontend/image-uri"
    APP_NAME="frontend"
    APP_PORT="80"
  elif [[ "$INSTANCE_NAME" == *"API"* ]]; then
    PARAM_NAME="/apps/api/image-uri"
    APP_NAME="api"
    APP_PORT="3000"
  elif [[ "$ASG_NAME" == *"frontend"* ]]; then
    PARAM_NAME="/apps/frontend/image-uri"
    APP_NAME="frontend"
    APP_PORT="80"
  elif [[ "$ASG_NAME" == *"api"* ]]; then
    PARAM_NAME="/apps/api/image-uri"
    APP_NAME="api"
    APP_PORT="3000"
  else
    echo "ERROR: Could not determine instance type from Name tag: '$INSTANCE_NAME' or ASG tag: '$ASG_NAME'"
    echo "Attempting last resort: querying ASG API..."
    
    # Last resort: query ASG directly
    ASG_NAME=$(aws autoscaling describe-auto-scaling-instances \
      --region "$REGION" \
      --query "AutoScalingInstances[?InstanceId=='$INSTANCE_ID'].AutoScalingGroupName" \
      --output text 2>/dev/null || echo "")
    
    echo "ASG Name from API query: $ASG_NAME"
    
    if [[ "$ASG_NAME" == *"frontend"* ]]; then
      PARAM_NAME="/apps/frontend/image-uri"
      APP_NAME="frontend"
      APP_PORT="80"
    elif [[ "$ASG_NAME" == *"api"* ]]; then
      PARAM_NAME="/apps/api/image-uri"
      APP_NAME="api"
      APP_PORT="3000"
    else
      echo "ERROR: Cannot determine app type. Name tag='$INSTANCE_NAME', ASG tag='$ASG_NAME', API ASG='$ASG_NAME'"
      exit 1
    fi
  fi
  
  echo "Detected app: $APP_NAME with port $APP_PORT"
  echo "Parameter name: $PARAM_NAME"
  
  # Get image URI from Parameter Store
  echo "Attempting to retrieve image URI from: $PARAM_NAME"
  IMAGE_URI=$(aws ssm get-parameter --name "$PARAM_NAME" --region "$REGION" --query 'Parameter.Value' --output text 2>&1)
  IMAGE_URI_EXIT=$?
  
  echo "SSM get-parameter exit code: $IMAGE_URI_EXIT"
  echo "Retrieved IMAGE_URI: $IMAGE_URI"
  
  if [ $IMAGE_URI_EXIT -ne 0 ] || [ -z "$IMAGE_URI" ] || [[ "$IMAGE_URI" == "None" ]]; then
    echo "WARNING: Failed to get image URI from SSM Parameter Store: $PARAM_NAME"
    echo "SSM error output: $IMAGE_URI"
    echo "Using default latest images..."
    IMAGE_URI="697568497210.dkr.ecr.$REGION.amazonaws.com/monitoring-apps-$APP_NAME:latest"
    echo "Fallback IMAGE_URI: $IMAGE_URI"
  fi
  
  echo "Final Image URI: $IMAGE_URI"
  
  # Get ECR registry
  ECR_REGISTRY=$(echo $IMAGE_URI | cut -d'/' -f1)
  
  # Login to ECR
  echo "Logging into ECR: $ECR_REGISTRY"
  aws ecr get-login-password --region "$REGION" 2>/dev/null | docker login --username AWS --password-stdin "$ECR_REGISTRY" >> $LOG_FILE 2>&1
  
  if [ $? -ne 0 ]; then
    echo "WARNING: ECR login failed, but continuing..."
  fi
  
  # Stop existing container if running
  echo "Stopping existing container: $APP_NAME"
  docker stop "$APP_NAME" >> $LOG_FILE 2>&1 || true
  docker rm "$APP_NAME" >> $LOG_FILE 2>&1 || true
  
  # Pull and run new image
  echo "Pulling image: $IMAGE_URI"
  docker pull "$IMAGE_URI" >> $LOG_FILE 2>&1
  PULL_EXIT=$?
  
  if [ $PULL_EXIT -ne 0 ]; then
    echo "ERROR: Failed to pull image: $IMAGE_URI (exit code: $PULL_EXIT)"
    docker images >> $LOG_FILE 2>&1
    exit 1
  fi
  
  echo "Image pull successful (exit code: $PULL_EXIT)"
  docker images | grep "$APP_NAME" >> $LOG_FILE 2>&1
  
  echo "Running container: $APP_NAME on port $APP_PORT"
  
  # For API, get database credentials from SSM Parameter Store
  if [ "$APP_NAME" == "api" ]; then
    echo "Retrieving database credentials from SSM Parameter Store..."
    
    DB_SERVER=$(aws ssm get-parameter --name "/apps/rds/host" --region "$REGION" --query 'Parameter.Value' --output text 2>/dev/null || echo "localhost")
    DB_PORT=$(aws ssm get-parameter --name "/apps/rds/port" --region "$REGION" --query 'Parameter.Value' --output text 2>/dev/null || echo "5432")
    DB_NAME=$(aws ssm get-parameter --name "/apps/rds/dbname" --region "$REGION" --query 'Parameter.Value' --output text 2>/dev/null || echo "appdb")
    DB_USER=$(aws ssm get-parameter --name "/apps/rds/username" --region "$REGION" --query 'Parameter.Value' --output text 2>/dev/null || echo "postgres")
    DB_PASSWORD=$(aws ssm get-parameter --name "/apps/rds/password" --region "$REGION" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "password")
    
    echo "DB Connection: host=$DB_SERVER:$DB_PORT, db=$DB_NAME, user=$DB_USER"
    echo "Running container with database credentials..."
    
    docker run -d \
      --name "$APP_NAME" \
      -p "$APP_PORT:$APP_PORT" \
      --restart=always \
      -e "DB_SERVER=$DB_SERVER" \
      -e "DB_PORT=$DB_PORT" \
      -e "DB_NAME=$DB_NAME" \
      -e "DB_USER=$DB_USER" \
      -e "DB_PASSWORD=$DB_PASSWORD" \
      -e "EMAIL_USER=${EMAIL_USER:-}" \
      -e "EMAIL_PASS=${EMAIL_PASS:-}" \
      -e "WEBHOOK_URL=${WEBHOOK_URL:-}" \
      -e "PORT=3000" \
      "$IMAGE_URI" >> $LOG_FILE 2>&1
  else
    # For Frontend, no special env vars needed
    docker run -d \
      --name "$APP_NAME" \
      -p "$APP_PORT:$APP_PORT" \
      --restart=always \
      "$IMAGE_URI" >> $LOG_FILE 2>&1
  fi
  
  if [ $? -eq 0 ]; then
    echo "SUCCESS: Container started successfully"
    docker ps >> $LOG_FILE
    echo "Deployment completed at $(date)"
  else
    echo "ERROR: Failed to start container"
    docker logs "$APP_NAME" >> $LOG_FILE 2>&1
    exit 1
  fi
  
} >> $LOG_FILE 2>&1

EOF

chmod +x /usr/local/bin/deploy-docker.sh
echo "Deployment script created" >> /var/log/user-data.log 2>&1

# Run deployment for the first time
/usr/local/bin/deploy-docker.sh >> /var/log/user-data.log 2>&1

# --- Install Node Exporter (for Prometheus) ---
useradd --no-create-home --shell /bin/false node_exporter || true

curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.linux-amd64.tar.gz >> /var/log/user-data.log 2>&1 || echo "node_exporter download failed" >> /var/log/user-data.log
tar xzf node_exporter-1.8.1.linux-amd64.tar.gz >> /var/log/user-data.log 2>&1 || echo "node_exporter tar failed" >> /var/log/user-data.log
cp node_exporter-1.8.1.linux-amd64/node_exporter /usr/local/bin/ >> /var/log/user-data.log 2>&1 || echo "node_exporter copy failed" >> /var/log/user-data.log
chown node_exporter:node_exporter /usr/local/bin/node_exporter >> /var/log/user-data.log 2>&1 || echo "node_exporter chown failed" >> /var/log/user-data.log

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
