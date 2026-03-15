# Monitoring VPC Outputs
output "monitoring_vpc_id" {
  description = "Monitoring VPC ID"
  value       = module.monitoring_vpc.vpc_id
}

output "monitoring_vpc_cidr" {
  description = "Monitoring VPC CIDR block"
  value       = module.monitoring_vpc.vpc_cidr
}

output "monitoring_subnet_ids" {
  description = "Monitoring private subnet IDs"
  value       = module.monitoring_vpc.private_subnet_ids
}

# Apps VPC Outputs
output "apps_vpc_id" {
  description = "Apps VPC ID"
  value       = module.apps_vpc.vpc_id
}

output "apps_vpc_cidr" {
  description = "Apps VPC CIDR block"
  value       = module.apps_vpc.vpc_cidr
}

output "apps_public_subnet_ids" {
  description = "Apps VPC public subnet IDs"
  value       = module.apps_vpc.public_subnet_ids
}

output "apps_private_app_subnet_ids" {
  description = "Apps VPC private app subnet IDs"
  value       = module.apps_vpc.private_app_subnet_ids
}

output "apps_private_db_subnet_ids" {
  description = "Apps VPC private DB subnet IDs"
  value       = module.apps_vpc.private_db_subnet_ids
}

# ALB Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = module.rds.rds_endpoint
  sensitive   = true
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.rds_database_name
}

# Security Groups Outputs
output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = module.security_groups.alb_security_group_id
}

output "app_security_group_id" {
  description = "App instances security group ID"
  value       = module.security_groups.app_security_group_id
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = module.security_groups.rds_security_group_id
}

# VPC Peering Outputs
output "vpc_peering_connection_id" {
  description = "VPC Peering Connection ID"
  value       = var.enable_vpc_peering ? module.vpc_peering[0].peering_connection_id : null
}

# Frontend Outputs
output "frontend_asg_name" {
  description = "Frontend Auto Scaling Group name"
  value       = module.frontend.asg_name
}

output "frontend_asg_id" {
  description = "Frontend Auto Scaling Group ID"
  value       = module.frontend.asg_id
}

# API Outputs
output "api_asg_name" {
  description = "API Auto Scaling Group name"
  value       = module.api.asg_name
}

output "api_asg_id" {
  description = "API Auto Scaling Group ID"
  value       = module.api.asg_id
}

# Monitoring Stack Outputs
output "monitoring_instance_id" {
  description = "Monitoring EC2 instance ID"
  value       = module.monitoring.instance_id
}

output "monitoring_instance_private_ip" {
  description = "Monitoring instance private IP"
  value       = module.monitoring.instance_private_ip
}

output "monitoring_instance_public_ip" {
  description = "Monitoring instance public IP (Grafana and Prometheus accessible from internet)"
  value       = module.monitoring.instance_public_ip
}

output "prometheus_url" {
  description = "Prometheus URL (public access)"
  value       = module.monitoring.prometheus_url
}

output "grafana_url" {
  description = "Grafana URL (public access)"
  value       = module.monitoring.grafana_url
}

output "grafana_default_credentials" {
  description = "Grafana default login credentials"
  value       = "admin / admin (change after first login)"
}

# CI/CD Outputs
output "frontend_ecr_repository_url" {
  description = "Frontend ECR repository URL"
  value       = module.ecr.frontend_repository_url
}

output "api_ecr_repository_url" {
  description = "API ECR repository URL"
  value       = module.ecr.api_repository_url
}

output "github_oidc_role_arn" {
  description = "GitHub Actions OIDC role ARN (add to GitHub secrets as AWS_GITHUB_OIDC_ROLE_ARN)"
  value       = aws_iam_role.github_actions.arn
}

output "aws_account_id" {
  description = "AWS Account ID (add to GitHub secrets as AWS_ACCOUNT_ID)"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region (add to GitHub secrets as AWS_REGION)"
  value       = var.aws_region
}

output "ci_cd_setup_documentation" {
  description = "Path to CI/CD setup documentation"
  value       = "See CI-CD-SETUP.md in the terraform directory for complete setup instructions"
}
