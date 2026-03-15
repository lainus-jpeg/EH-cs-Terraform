#!/bin/bash

# Log all output
exec > >(tee /var/log/user-data.log) 2>&1

echo "User data script started at $(date)"

# Update system
yum update -y

# Install and enable AWS SSM Agent
echo "Installing AWS SSM Agent..."
dnf install -y amazon-ssm-agent || true
systemctl enable amazon-ssm-agent || true
systemctl restart amazon-ssm-agent || true

# Install Grafana from official repo
echo "Installing Grafana..."
cat > /etc/yum.repos.d/grafana.repo << 'EOF'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

dnf install -y grafana

# Create Grafana provisioning directories
mkdir -p /etc/grafana/provisioning/datasources
mkdir -p /etc/grafana/provisioning/dashboards

# Create Prometheus datasource configuration
cat > /etc/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://${prometheus_ip}:9090
    jsonData:
      timeInterval: 10s
    editable: true
    isDefault: true
    testData:
      enabled: false
EOF

# Also ensure the file is created with proper syntax
cat > /etc/grafana/provisioning/datasources/prometheus.yml << 'EODF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://${prometheus_ip}:9090
    isDefault: true
    editable: true
EODF

# Create dashboard provisioning config
cat > /etc/grafana/provisioning/dashboards/dashboards.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

# Create compact Node Exporter Dashboard
cat > /etc/grafana/provisioning/dashboards/node-exporter-dashboard.json << 'EOF'
{"title":"Node Exporter","uid":"node-exporter-dashboard","version":1,"timezone":"","panels":[{"id":1,"type":"row","gridPos":{"h":1,"w":24,"x":0,"y":0},"title":"Row 1 — Availability"},{"id":2,"type":"stat","title":"Targets UP","gridPos":{"h":8,"w":12,"x":0,"y":1},"datasource":"Prometheus","targets":[{"expr":"count(up==1)"}],"options":{"colorMode":"background","graphMode":"none","reduceOptions":{"values":false,"calcs":["lastNotNull"]}},"fieldConfig":{"defaults":{"color":{"mode":"thresholds"}},"overrides":[]}},{"id":3,"type":"stat","title":"Uptime","gridPos":{"h":8,"w":12,"x":12,"y":1},"datasource":"Prometheus","targets":[{"expr":"(time()-max(node_boot_time_seconds))/3600","legendFormat":"hours"}],"options":{"colorMode":"background","graphMode":"none","reduceOptions":{"values":false,"calcs":["lastNotNull"]}},"fieldConfig":{"defaults":{"color":{"mode":"thresholds"},"unit":"h"},"overrides":[]}},{"id":4,"type":"row","gridPos":{"h":1,"w":24,"x":0,"y":9},"title":"Row 2 — Compute"},{"id":5,"type":"timeseries","title":"CPU %","gridPos":{"h":8,"w":8,"x":0,"y":10},"datasource":"Prometheus","targets":[{"expr":"100-(avg by(instance)(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])))*100","legendFormat":"{{instance}}"}],"fieldConfig":{"defaults":{"unit":"percent"},"overrides":[]},"options":{"legend":{"displayMode":"table"}}},{"id":6,"type":"timeseries","title":"Memory %","gridPos":{"h":8,"w":8,"x":8,"y":10},"datasource":"Prometheus","targets":[{"expr":"((node_memory_MemTotal_bytes-node_memory_MemAvailable_bytes)/node_memory_MemTotal_bytes)*100","legendFormat":"{{instance}}"}],"fieldConfig":{"defaults":{"unit":"percent"},"overrides":[]},"options":{"legend":{"displayMode":"table"}}},{"id":7,"type":"timeseries","title":"Disk %","gridPos":{"h":8,"w":8,"x":16,"y":10},"datasource":"Prometheus","targets":[{"expr":"((node_filesystem_size_bytes{fstype!=\"tmpfs\"}-node_filesystem_avail_bytes{fstype!=\"tmpfs\"})/node_filesystem_size_bytes{fstype!=\"tmpfs\"})*100","legendFormat":"{{device}}"}],"fieldConfig":{"defaults":{"unit":"percent"},"overrides":[]},"options":{"legend":{"displayMode":"table"}}},{"id":8,"type":"row","gridPos":{"h":1,"w":24,"x":0,"y":18},"title":"Row 3 — Network"},{"id":9,"type":"timeseries","title":"Network In","gridPos":{"h":8,"w":12,"x":0,"y":19},"datasource":"Prometheus","targets":[{"expr":"rate(node_network_receive_bytes_total{device!=\"lo\"}[5m])","legendFormat":"{{device}}@{{instance}}"}],"fieldConfig":{"defaults":{"unit":"Bps"},"overrides":[]},"options":{"legend":{"displayMode":"table"}}},{"id":10,"type":"timeseries","title":"Network Out","gridPos":{"h":8,"w":12,"x":12,"y":19},"datasource":"Prometheus","targets":[{"expr":"rate(node_network_transmit_bytes_total{device!=\"lo\"}[5m])","legendFormat":"{{device}}@{{instance}}"}],"fieldConfig":{"defaults":{"unit":"Bps"},"overrides":[]},"options":{"legend":{"displayMode":"table"}}}],"refresh":"30s","schemaVersion":27,"style":"dark","tags":["node-exporter"],"templating":{"list":[]},"time":{"from":"now-6h","to":"now"},"timepicker":{}}
EOF
EOF

chown -R grafana:grafana /etc/grafana/provisioning
chmod -R 755 /etc/grafana/provisioning
chmod 644 /etc/grafana/provisioning/datasources/*.yml
chmod 644 /etc/grafana/provisioning/dashboards/*.yml
chmod 644 /etc/grafana/provisioning/dashboards/*.json

# Create Grafana systemd service
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

# Wait for Grafana to be ready
sleep 15

# Check Grafana logs
echo "=== Grafana Service Status ==="
systemctl status grafana-server
echo "=== Grafana Logs ==="
tail -20 /var/log/grafana/grafana.log || echo "No logs yet"

# Install Node Exporter
echo "Installing Node Exporter..."
useradd --no-create-home --shell /bin/false node_exporter || true
cd /tmp
curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.linux-amd64.tar.gz
tar xzf node_exporter-1.8.1.linux-amd64.tar.gz
cp node_exporter-1.8.1.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Node Exporter systemd service
cat > /etc/systemd/system/node_exporter.service << 'EOF'
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
EOF

# Start Node Exporter
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

echo "Grafana available at http://$(hostname -I | awk '{print $1}'):3000"
echo "User data script completed at $(date)"
