variable "asg_name" {
  description = "Name of the Auto Scaling Group"
  type        = string
}

variable "display_name" {
  description = "Display name for instances (shown in console)"
  type        = string
  default     = ""
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ASG"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for instances"
  type        = string
}

variable "target_group_arn" {
  description = "Target group ARN"
  type        = string
}

variable "target_group_name" {
  description = "Target group name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_owner" {
  description = "AMI owner filter"
  type        = string
  default     = "amazon"
}

variable "ami_name_filter" {
  description = "AMI name filter"
  type        = string
  default     = "al2023-ami-*"
}

variable "environment" {
  description = "Environment name"
  type        = string
}
