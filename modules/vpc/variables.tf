variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones for the VPC"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = []
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private app subnets"
  type        = list(string)
  default     = []
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for private database subnets"
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (monitoring)"
  type        = list(string)
  default     = []
}

variable "enable_internet_gateway" {
  description = "Enable Internet Gateway"
  type        = bool
  default     = false
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = false
}

variable "nat_gateway_subnet" {
  description = "Index of public subnet for NAT Gateway (0-based)"
  type        = number
  default     = 0
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# Subnet naming variables (optional overrides)
variable "public_subnet_name" {
  description = "Custom name for public subnets"
  type        = string
  default     = ""
}

variable "private_app_subnet_name" {
  description = "Custom name for private app subnets"
  type        = string
  default     = ""
}

variable "private_db_subnet_name" {
  description = "Custom name for private DB subnets"
  type        = string
  default     = ""
}

variable "private_subnet_name" {
  description = "Custom name for private subnets (monitoring)"
  type        = string
  default     = ""
}
