aws_region     = "eu-central-1"
environment    = "dev"
project_name  = "spoke-hub-network"

# Availability Zones
availability_zones = ["eu-central-1a", "eu-central-1b"]

# Monitoring VPC
monitoring_vpc_cidr                = "10.10.0.0/16"
monitoring_public_subnet_cidrs     = ["10.10.0.0/24", "10.10.1.0/24"]
monitoring_private_subnet_cidrs    = ["10.10.10.0/24", "10.10.11.0/24"]

# Apps VPC
apps_vpc_cidr                  = "10.20.0.0/16"
apps_public_subnet_cidrs       = ["10.20.0.0/24", "10.20.1.0/24"]
apps_private_app_subnet_cidrs  = ["10.20.10.0/24", "10.20.11.0/24"]
apps_private_db_subnet_cidrs   = ["10.20.20.0/24", "10.20.21.0/24"]

# RDS Configuration - Budget Friendly
rds_engine              = "postgres"
rds_engine_version      = "17.6"
rds_instance_class      = "db.t3.micro"
rds_allocated_storage   = 20
rds_backup_retention_period = 0
rds_multi_az            = false

# EC2 Configuration - Budget Friendly
instance_type = "t3.micro"

# ASG Configuration
frontend_asg_min_size             = 1
frontend_asg_max_size             = 3
frontend_asg_desired_capacity     = 1

api_asg_min_size                  = 1
api_asg_max_size                  = 3
api_asg_desired_capacity          = 1

# ALB Configuration
alb_port                           = 80
health_check_path                  = "/"
health_check_interval              = 30
health_check_timeout               = 5
health_check_healthy_threshold     = 2
health_check_unhealthy_threshold   = 3

# VPC Peering
enable_vpc_peering = true

# SOAR Configuration (Security Orchestration, Automation and Response)
ses_from_email  = "lianderjimenez420@gmail.com"
alert_email     = "lianderjimenez420@gmail.com"
waf_ip_set_name = "soar-blocklist"
require_api_key = false
log_retention_days = 7
