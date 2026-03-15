#!/bin/bash
# Deployment script for API ASG instances
# This script runs as a cron job to pull and deploy latest image from ECR

set -e

# Configuration
REGION="${AWS_REGION:-eu-central-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $REGION)
ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
REPOSITORY_NAME="monitoring-apps-api"
CONTAINER_NAME="api"
CONTAINER_PORT="3000"
LOCAL_PORT="8080"
MAX_RETRIES=3
RETRY_DELAY=5

# Logging
LOG_FILE="/var/log/api-deployment.log"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log "=== API Deployment Started ==="

# Login to ECR
log "Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Get the latest image tag
log "Fetching latest image from ECR..."
IMAGE_URI="$ECR_REGISTRY/$REPOSITORY_NAME:latest"

# Pull image with retry logic
RETRY_COUNT=0
until docker pull $IMAGE_URI; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        log "ERROR: Failed to pull image after $MAX_RETRIES attempts"
        exit 1
    fi
    log "Pull failed, retrying in ${RETRY_DELAY}s... (Attempt $RETRY_COUNT/$MAX_RETRIES)"
    sleep $RETRY_DELAY
done

log "Successfully pulled: $IMAGE_URI"

# Get DB connection from Parameter Store
log "Fetching database credentials from Parameter Store..."
DB_URL=$(aws ssm get-parameter --name /apps/database-url --query 'Parameter.Value' --output text --region $REGION 2>/dev/null || echo "")

if [ -z "$DB_URL" ]; then
    log "WARNING: Database URL not found in Parameter Store. Container will start but may not connect to DB."
fi

# Stop existing container if it's running
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    log "Stopping existing container: $CONTAINER_NAME"
    docker stop $CONTAINER_NAME || true
    docker rm $CONTAINER_NAME || true
fi

# Run new container with environment variables
log "Starting new container: $CONTAINER_NAME"
docker run -d \
    --name $CONTAINER_NAME \
    --restart unless-stopped \
    -p $LOCAL_PORT:$CONTAINER_PORT \
    -e DATABASE_URL="$DB_URL" \
    -e NODE_ENV="production" \
    $IMAGE_URI

log "Container started successfully"

# Clean up old images (keep last 3)
log "Cleaning up old images..."
docker images --format "{{.Repository}}:{{.Tag}}" | grep $REPOSITORY_NAME | tail -n +4 | xargs -r docker rmi || true

log "=== API Deployment Completed Successfully ==="
