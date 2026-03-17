variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ALB"
  type        = string
}

variable "frontend_target_group_name" {
  description = "Name of the frontend target group"
  type        = string
}

variable "api_target_group_name" {
  description = "Name of the API target group"
  type        = string
}

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
  description = "Number of consecutive successful health checks required"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks required"
  type        = number
  default     = 3
}

variable "environment" {
  description = "Environment name"
  type        = string
}
