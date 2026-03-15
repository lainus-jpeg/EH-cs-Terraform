#!/bin/bash

# Log all output
exec > >(tee /var/log/user-data.log) 2>&1

echo "User data script started at $(date)"

# Update and install Docker
yum install -y docker >> /var/log/user-data.log 2>&1 || echo "docker install failed"
systemctl start docker >> /var/log/user-data.log 2>&1 || echo "docker start failed"
systemctl enable docker >> /var/log/user-data.log 2>&1 || echo "docker enable failed"

# Install docker-compose standalone binary
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >> /var/log/user-data.log 2>&1
chmod +x /usr/local/bin/docker-compose >> /var/log/user-data.log 2>&1 || echo "docker-compose chmod failed"

# Add ec2-user to docker group
usermod -a -G docker ec2-user

# Create monitoring directories
mkdir -p /opt/monitoring/prometheus
mkdir -p /opt/monitoring/grafana

# Create Prometheus config file
cat > /opt/monitoring/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  scrape_timeout: 30s
  external_labels:
    cluster: 'spoke-hub-network'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    scrape_timeout: 30s
    ec2_sd_configs:
      - region: ${aws_region}
        port: 9100
    relabel_configs:
      # Use private IP as the scrape address
      - source_labels: [__meta_ec2_private_ip]
        target_label: __address__
        replacement: "$1:9100"
      # Tag with instance ID
      - source_labels: [__meta_ec2_instance_id]
        target_label: instance_id
      # Tag with availability zone
      - source_labels: [__meta_ec2_availability_zone]
        target_label: availability_zone
      # Tag with VPC ID
      - source_labels: [__meta_ec2_vpc_id]
        target_label: vpc_id
EOF

# Create docker compose file for Prometheus and Grafana
cat > /opt/monitoring/docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - /opt/monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
    restart: unless-stopped
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    volumes:
      - grafana_data:/var/lib/grafana
      - /opt/monitoring/grafana/provisioning:/etc/grafana/provisioning
    depends_on:
      - prometheus
    restart: unless-stopped
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    restart: unless-stopped
    networks:
      - monitoring

volumes:
  prometheus_data:
  grafana_data:

networks:
  monitoring:
    driver: bridge
EOF

# Create Grafana provisioning directory
mkdir -p /opt/monitoring/grafana/provisioning/datasources
mkdir -p /opt/monitoring/grafana/provisioning/dashboards

# Create Prometheus datasource for Grafana
cat > /opt/monitoring/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

# Pull Docker images
docker pull prom/prometheus:latest
docker pull grafana/grafana:latest
docker pull prom/node-exporter:latest

# Start the monitoring stack
cd /opt/monitoring
docker-compose up -d

echo "Docker containers started"
echo "Prometheus URL: http://$(hostname -I | awk '{print $1}'):9090"
echo "Grafana URL: http://$(hostname -I | awk '{print $1}'):3000"
echo "Grafana credentials: admin / admin"

echo "User data script completed at $(date)"
