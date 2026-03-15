variable "instance_name" {
  description = "Name of the monitoring EC2 instance"
  type        = string
  default     = "monitoring-instance"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_owner" {
  description = "Owner of the AMI"
  type        = string
  default     = "137112412989"  # Amazon
}

variable "ami_name_filter" {
  description = "AMI name filter"
  type        = string
  default     = "al2023-ami-*"
}

variable "monitoring_vpc_id" {
  description = "Monitoring VPC ID"
  type        = string
}

variable "monitoring_vpc_cidr" {
  description = "Monitoring VPC CIDR block"
  type        = string
}

variable "apps_vpc_cidr" {
  description = "Apps VPC CIDR block"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch instance in"
  type        = string
}

variable "apps_vpc_app_sg_id" {
  description = "Apps VPC app security group ID"
  type        = string
}

variable "apps_vpc_id" {
  description = "Spoke VPC ID"
  type        = string
}

variable "prometheus_retention" {
  description = "Prometheus data retention period in days"
  type        = number
  default     = 15
}

variable "aws_region" {
  description = "AWS region where resources are deployed"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
