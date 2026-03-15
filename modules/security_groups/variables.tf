variable "apps_vpc_id" {
  description = "Apps VPC ID"
  type        = string
}

variable "monitoring_vpc_id" {
  description = "Monitoring VPC ID"
  type        = string
}

variable "apps_vpc_cidr" {
  description = "Apps VPC CIDR block"
  type        = string
}

variable "monitoring_vpc_cidr" {
  description = "Monitoring VPC CIDR block"
  type        = string
}

variable "alb_port" {
  description = "Port for ALB to listen on"
  type        = number
  default     = 80
}

variable "environment" {
  description = "Environment name"
  type        = string
}
