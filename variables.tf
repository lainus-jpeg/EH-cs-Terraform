variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "monitoring-apps"
}

variable "availability_zones" {
  description = "Availability zones for the region"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

# Monitoring VPC Variables
variable "monitoring_vpc_cidr" {
  description = "CIDR block for Monitoring VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "monitoring_public_subnet_cidrs" {
  description = "CIDR blocks for Monitoring public subnets"
  type        = list(string)
  default     = ["10.10.0.0/24", "10.10.1.0/24"]
}

variable "monitoring_private_subnet_cidrs" {
  description = "CIDR blocks for Monitoring private subnets"
  type        = list(string)
  default     = ["10.10.10.0/24", "10.10.11.0/24"]
}

# Apps VPC Variables
variable "apps_vpc_cidr" {
  description = "CIDR block for Apps VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "apps_public_subnet_cidrs" {
  description = "CIDR blocks for Apps VPC public subnets (DMZ)"
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "apps_private_app_subnet_cidrs" {
  description = "CIDR blocks for Apps VPC private app subnets"
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "apps_private_db_subnet_cidrs" {
  description = "CIDR blocks for Apps VPC private DB subnets"
  type        = list(string)
  default     = ["10.20.20.0/24", "10.20.21.0/24"]
}

# RDS Variables
variable "rds_engine" {
  description = "RDS database engine"
  type        = string
  default     = "postgres"
}

variable "rds_engine_version" {
  description = "RDS engine version"
  type        = string
  default     = "15.4"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 7
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

# EC2 Variables
variable "instance_type" {
  description = "EC2 instance type for ASG"
  type        = string
  default     = "t3.micro"
}

variable "ami_owner" {
  description = "AMI owner filter for Amazon Linux 2023"
  type        = string
  default     = "amazon"
}

variable "ami_name_filter" {
  description = "AMI name filter for Amazon Linux 2023"
  type        = string
  default     = "al2023-ami-*"
}

# ASG Variables
variable "frontend_asg_min_size" {
  description = "Frontend ASG minimum size"
  type        = number
  default     = 1
}

variable "frontend_asg_max_size" {
  description = "Frontend ASG maximum size"
  type        = number
  default     = 3
}

variable "frontend_asg_desired_capacity" {
  description = "Frontend ASG desired capacity"
  type        = number
  default     = 1
}

variable "api_asg_min_size" {
  description = "API ASG minimum size"
  type        = number
  default     = 1
}

variable "api_asg_max_size" {
  description = "API ASG maximum size"
  type        = number
  default     = 3
}

variable "api_asg_desired_capacity" {
  description = "API ASG desired capacity"
  type        = number
  default     = 1
}

# ALB Variables
variable "alb_port" {
  description = "Port for ALB to listen on"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Health check path for target groups"
  type        = string
  default     = "/"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive health checks successes required"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive health check failures required"
  type        = number
  default     = 3
}

# VPC Peering Variables
variable "enable_vpc_peering" {
  description = "Enable VPC peering between Hub and Spoke"
  type        = bool
  default     = true
}

# Apps VPC Gateway Variables
variable "apps_enable_internet_gateway" {
  description = "Enable Internet Gateway for Apps VPC"
  type        = bool
  default     = true
}

variable "apps_enable_nat_gateway" {
  description = "Enable NAT Gateway for Apps VPC private subnets"
  type        = bool
  default     = true
}
