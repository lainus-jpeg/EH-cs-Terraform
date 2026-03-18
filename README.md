# Multi-VPC Network Infrastructure

Production-ready Terraform configuration for a multi-VPC AWS infrastructure with monitoring, load balancing, and auto-scaling.

## Architecture

- **monitoring-vpc** (10.10.0.0/16): Monitoring & Prometheus
  - Public subnets: Monitoring Subnet Pub (10.10.0.0/24, 10.10.1.0/24)
  - Private subnets: Monitoring Subnet Priv (10.10.10.0/24, 10.10.11.0/24)
- **apps-vpc** (10.20.0.0/16): Application servers & RDS
  - Public subnets (DMZ): 10.20.0.0/24, 10.20.1.0/24
  - Private app subnets: 10.20.10.0/24, 10.20.11.0/24
  - Private DB subnets: 10.20.20.0/24, 10.20.21.0/24
- **VPC Peering**: monitoring-vpc ↔ apps-vpc connectivity
- **Load Balancer**: ALB for frontend & API traffic
- **Auto-scaling**: Frontend & API ASGs with CPU-based scaling

## Components

### Monitoring Stack
- **Prometheus**: Metrics collection & alerting (`module.monitoring.aws_instance.monitoring`)
- **Grafana**: Visualization (`module.monitoring.aws_instance.grafana`)
- **Node Exporter**: Host metrics on all instances
- **Alerts**: 4 pre-configured rules (InstanceDown, HighCPU, HighMemory, DiskAlmostFull)

### Application Infrastructure
- **Frontend ASG**: Desired capacity 1 (min 1, max 3), port 80 → 3000
- **API ASG**: Desired capacity 1 (min 1, max 3), port 8000
- **RDS PostgreSQL**: Postgres 17.6, db.t3.micro, 20GB storage, single-AZ
- **ALB**: Routes traffic based on path rules, health checks every 30s

## Deployment

### Terraform Infrastructure

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

### Infrastructure & Application CI/CD Pipeline

This Terraform configuration includes **two integrated CI/CD pipelines**:

#### **1. Terraform Infrastructure Pipeline** (Automated)
- **Workflows**: `.github/workflows/terraform-plan.yml` & `terraform-apply.yml`
- **Trigger**: Changes to `*.tf`, `terraform.tfvars`, or `*.sh` files on pull requests/merges to `main`
- **Authentication**: AWS OIDC (OpenID Connect) - no hardcoded credentials
- **Process**:
  - PR: Runs `terraform plan` and posts results as PR comment
  - Merge to main: Automatically runs `terraform apply`

#### **2. Application Docker Build & Push Pipeline** (Automated)
- **Frontend Workflow**: `EH-cs1-frontend/.github/workflows/frontend-ecr-push.yml`
- **API Workflow**: `EH-cs1-api/.github/workflows/api-ecr-push.yml`
- **Process**:
  1. Builds Docker images from application Dockerfiles
  2. Pushes to ECR repositories:
     - `monitoring-apps-frontend` (Frontend app)
     - `monitoring-apps-api` (API server)
  3. EC2 instances automatically pull latest images from ECR and deploy

### Initial CI/CD Setup

1. **Run Terraform** to provision infrastructure:
   ```bash
   terraform apply
   ```
   This creates:
   - ECR repositories
   - GitHub OIDC provider for secure authentication
   - IAM roles for GitHub Actions and EC2 instances

2. **Add GitHub Secrets** to both application repositories:
   - `AWS_REGION`: `eu-central-1`
   - `AWS_ACCOUNT_ID`: (Get from `terraform output` or AWS Console)
   - `AWS_GITHUB_OIDC_ROLE_ARN`: (Get from `terraform output github_oidc_role_arn`)

3. **Copy GitHub Actions Workflows** to application repositories:
   - Copy `frontend-ecr-push.yml` → `EH-cs1-frontend/.github/workflows/`
   - Copy `api-ecr-push.yml` → `EH-cs1-api/.github/workflows/`

4. **Push code** to trigger automatic builds and deployments

See [CI-CD-SETUP.md](./CI-CD-SETUP.md) and [GITHUB_ACTIONS_SETUP.md](./GITHUB_ACTIONS_SETUP.md) for detailed setup instructions.

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

## Key Variables (terraform.tfvars)

- `aws_region`: eu-central-1
- `environment`: dev
- `project_name`: spoke-hub-network
- `instance_type`: t3.micro
- Frontend ASG: min 1, max 3, desired 1
- API ASG: min 1, max 3, desired 1
- RDS: Postgres 17.6, db.t3.micro, 20GB, no backup retention (cost-optimized)
- ALB port: 80 (HTTP)
- Health check: every 30s with 2 healthy/3 unhealthy thresholds

See `variables.tf` and `terraform.tfvars` for all configurable options.

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
