#!/bin/bash
set -e
exec > /var/log/user-data.log 2>&1
exec 2>&1

echo "[INFO] Starting Grafana setup at $(date)"

# Update system packages
echo "[INFO] Updating packages..."
yum update -y || dnf update -y || true

# Install Docker
echo "[INFO] Installing Docker..."
yum install -y docker || dnf install -y docker
if [ $? -ne 0 ]; then
  echo "[ERROR] Failed to install Docker"
  exit 1
fi

# Install Docker Compose plugin
echo "[INFO] Installing Docker Compose plugin..."
yum install -y docker-compose-plugin || dnf install -y docker-compose-plugin
if [ $? -ne 0 ]; then
  echo "[ERROR] Failed to install Docker Compose plugin"
  exit 1
fi

# Enable and start Docker daemon
echo "[INFO] Enabling and starting Docker service..."
systemctl daemon-reload
systemctl enable docker
systemctl start docker

# Wait for Docker to be ready
echo "[INFO] Waiting for Docker to start..."
for i in {1..30}; do
  if docker ps > /dev/null 2>&1; then
    echo "[INFO] Docker is ready"
    break
  fi
  echo "[INFO] Waiting... ($i/30)"
  sleep 2
done

# Create Grafana directories
echo "[INFO] Creating Grafana working directory..."
mkdir -p /opt/grafana
chmod 755 /opt/grafana
cd /opt/grafana

# Write docker-compose.yml
echo "[INFO] Writing docker-compose.yml..."
cat > docker-compose.yml <<'YAML'
services:
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=grafana-piechart-panel
    ports:
      - "0.0.0.0:3000:3000"
    restart: unless-stopped
    volumes:
      - grafana_data:/var/lib/grafana
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/api/health"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 40s

volumes:
  grafana_data:
YAML

# Pull image to cache
echo "[INFO] Pulling Grafana image..."
docker pull grafana/grafana:latest

# Start Grafana
echo "[INFO] Starting Grafana with docker compose up..."
docker compose up -d

# Verify container started
sleep 10
if docker ps | grep -q grafana; then
  echo "[INFO] ✓ Grafana container is running"
else
  echo "[ERROR] Grafana container failed to start"
  docker compose logs
  exit 1
fi

echo "[INFO] Setup complete! Grafana should be accessible at http://<instance-public-ip>:3000"
echo "[INFO] Default login: admin / admin"
echo "[INFO] Docker service status:"
systemctl status docker --no-pager
echo "[INFO] Grafana container status:"
docker ps | grep grafana || echo "Container not found!"