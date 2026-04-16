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

# Create prometheus user
useradd --no-create-home --shell /bin/false prometheus || true
useradd --no-create-home --shell /bin/false node_exporter || true

# Install Prometheus
echo "Installing Prometheus..."
cd /tmp
curl -LO https://github.com/prometheus/prometheus/releases/download/v2.53.0/prometheus-2.53.0.linux-amd64.tar.gz
tar xzf prometheus-2.53.0.linux-amd64.tar.gz
mkdir -p /etc/prometheus /var/lib/prometheus
cp prometheus-2.53.0.linux-amd64/prometheus /usr/local/bin/
cp prometheus-2.53.0.linux-amd64/promtool /usr/local/bin/
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Create Prometheus config
cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 30s
  scrape_timeout: 10s
  evaluation_interval: 15s
  external_labels:
    cluster: 'spoke-hub-network'

rule_files:
  - '/etc/prometheus/alerts.yml'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    ec2_sd_configs:
      - region: ${aws_region}
        port: 9100
        filters:
          - name: tag:PrometheusSync
            values: ["true"]
    relabel_configs:
      - source_labels: [__meta_ec2_private_ip]
        target_label: __address__
        replacement: '$1:9100'
        regex: '(.*)'
      - source_labels: [__meta_ec2_instance_id]
        target_label: instance_id
      - source_labels: [__meta_ec2_availability_zone]
        target_label: availability_zone
      - source_labels: [__meta_ec2_tag_aws_autoscaling_groupName]
        target_label: asg_name
EOF

# Create Prometheus alert rules
cat > /etc/prometheus/alerts.yml << 'EOF'
groups:
  - name: node-exporter-alerts
    interval: 15s
    rules:
      - alert: InstanceDown
        expr: up{job="node-exporter"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Instance down (most important)"
          description: "Node exporter target is not reachable on {{ $labels.instance }} (instance down or networking issue)"

      - alert: HighCPU
        expr: 100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage for 5 minutes"
          description: "CPU usage is {{ $value | humanize }}% on {{ $labels.instance }}"

      - alert: HighMemory
        expr: 100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage for 5 minutes"
          description: "Memory usage is {{ $value | humanize }}% on {{ $labels.instance }}"

      - alert: DiskAlmostFull
        expr: 100 * (1 - (node_filesystem_avail_bytes{mountpoint="/",fstype!="tmpfs"} / node_filesystem_size_bytes{mountpoint="/",fstype!="tmpfs"})) > 80
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "Disk almost full on {{ $labels.instance }}"
          description: "Disk usage is {{ $value | humanize }}% on {{ $labels.instance }}"

      - alert: DDoSAttackDetected
        expr: rate(node_network_receive_bytes_total{device=~"eth0|ens.*"}[5m]) > 100000000
        for: 3m
        labels:
          severity: critical
          attack_type: "DDoS"
        annotations:
          summary: "Potential DDoS attack detected on {{ $labels.instance }}"
          description: "Network traffic exceeds threshold: {{ $value | humanize }}B/s on device {{ $labels.device }} for 3 minutes"

      - alert: ExcessiveNetworkTraffic
        expr: rate(node_network_receive_bytes_total{device=~"eth0|ens.*"}[5m]) > 50000000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Excessive network traffic on {{ $labels.instance }}"
          description: "Network receive rate is {{ $value | humanize }}B/s on device {{ $labels.device }}"
EOF

chown prometheus:prometheus /etc/prometheus/prometheus.yml /etc/prometheus/alerts.yml

# Prometheus systemd service
cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=15d \
  --web.console.libraries=/usr/share/prometheus/console_libraries \
  --web.console.templates=/usr/share/prometheus/consoles

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Start Prometheus and Node Exporter immediately
systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

# Install Node Exporter
echo "Installing Node Exporter..."
cd /tmp
curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.linux-amd64.tar.gz
tar xzf node_exporter-1.8.1.linux-amd64.tar.gz
cp node_exporter-1.8.1.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Install Node Exporter
echo "Installing Node Exporter..."
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

# Start services
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

echo "Prometheus available at http://$(hostname -I | awk '{print $1}'):9090"
echo "Grafana available at http://$(hostname -I | awk '{print $1}'):3000"
echo "User data script completed at $(date)"
