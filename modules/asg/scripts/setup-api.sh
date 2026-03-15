#!/bin/bash
# Setup script for API ASG instances
# Run once at instance startup to configure Docker and deployment automation

set -e

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting API ASG instance setup..."

# Install Docker
log "Installing Docker..."
yum update -y
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install AWS CLI (should already be present on Amazon Linux 2023)
log "Verifying AWS CLI is installed..."
aws --version

# Create deployment script directory
log "Creating deployment directory..."
mkdir -p /opt/deployment
cp /tmp/deploy-api.sh /opt/deployment/deploy-api.sh
chmod +x /opt/deployment/deploy-api.sh

# Set up CloudWatch Logs agent
log "Setting up application logging..."
mkdir -p /var/log
chmod 755 /var/log

# Create cron job to deploy every 5 minutes
log "Setting up cron job for continuous deployment..."
CRON_JOB="*/5 * * * * /opt/deployment/deploy-api.sh >> /var/log/api-cron.log 2>&1"
(crontab -u root -l 2>/dev/null; echo "$CRON_JOB") | crontab -u root -

# Enable and start cron
systemctl enable crond
systemctl start crond

log "API ASG instance setup completed successfully!"
