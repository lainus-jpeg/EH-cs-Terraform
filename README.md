# Spoke-Hub Network Infrastructure

Production-ready Terraform configuration for a multi-VPC AWS infrastructure with monitoring, load balancing, and auto-scaling.

## Architecture

- **Hub VPC** (10.10.0.0/16): Monitoring & Prometheus
- **Spoke VPC** (10.20.0.0/16): Application servers & RDS
- **VPC Peering**: Hub ↔ Spoke connectivity
- **Load Balancer**: ALB for frontend & API traffic
- **Auto-scaling**: Frontend & API ASGs with CPU-based scaling

## Components

### Monitoring Stack
- **Prometheus**: Metrics collection & alerting (`module.monitoring.aws_instance.monitoring`)
- **Grafana**: Visualization (`module.monitoring.aws_instance.grafana`)
- **Node Exporter**: Host metrics on all instances
- **Alerts**: 4 pre-configured rules (InstanceDown, HighCPU, HighMemory, DiskAlmostFull)

### Application Infrastructure
- **Frontend ASG**: Desired capacity 1, port 80 → 3000
- **API ASG**: Desired capacity 1, port 8080 → 8000
- **RDS PostgreSQL**: Multi-AZ, automated backups, CloudWatch alarms
- **ALB**: Routes traffic based on path rules

## Deployment

```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply configuration
terraform apply

# Replace specific components
terraform apply -replace='module.monitoring'
terraform apply -replace='module.monitoring.aws_instance.grafana'
terraform apply -replace='module.frontend_asg'
```

## Access Points

### Monitoring
- **Prometheus**: http://<monitoring-public-ip>:9090
- **Grafana**: http://<grafana-public-ip>:3000
  - Default login: admin/admin
  - Datasource: Prometheus (auto-provisioned)
  - Dashboard: Node Exporter Full Dashboard (auto-provisioned)

### Application
- **Frontend**: http://<alb-dns-name>/
- **API**: http://<alb-dns-name>/api/

## Alert Rules

| Alert | Severity | Condition | Duration |
|-------|----------|-----------|----------|
| InstanceDown | Critical | Node-exporter unreachable | 2 min |
| HighCPU | Warning | CPU > 80% | 5 min |
| HighMemory | Warning | Memory > 85% | 5 min |
| DiskAlmostFull | Critical | Disk > 80% | 10 min |

View alerts at: **Prometheus → Alerts**

## Key Variables

- `aws_region`: eu-central-1
- `environment`: dev
- `instance_type`: t3.micro
- `prometheus_retention`: 15d

See `variables.tf` for all configurable options.

## Troubleshooting

**Grafana showing "No data":**
- Check Prometheus datasource URL is correct (private IP of monitoring instance)
- Wait 1-2 minutes after restart for metrics to populate

**Instances not scraped by Prometheus:**
- Verify ASG instances have `PrometheusSync=true` tag
- Check security group allows port 9100 from monitoring instance

**Alerts not firing:**
- Access Prometheus Alerts page to verify rule status
- Check Prometheus logs: `systemctl status prometheus`

## Useful Commands

```bash
# SSH into instances
ssh -i monitoring-key.pem ec2-user@<instance-ip>

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# View Prometheus alerts
curl http://localhost:9090/api/v1/rules

# Manual Prometheus restart
sudo systemctl restart prometheus

# Manual Grafana restart
sudo systemctl restart grafana-server
```

## File Structure

```
.
├── main.tf              # Main Terraform configuration
├── variables.tf         # Variable definitions
├── outputs.tf           # Output definitions
├── provider.tf          # AWS provider configuration
├── terraform.tfvars     # Variable values
└── modules/             # Terraform modules
    ├── vpc/
    ├── security_groups/
    ├── alb/
    ├── asg/
    ├── rds/
    ├── monitoring/
    └── vpc_peering/
```
