variable "requester_vpc_id" {
  description = "Requester VPC ID (Apps VPC)"
  type        = string
}

variable "accepter_vpc_id" {
  description = "Accepter VPC ID (Monitoring VPC)"
  type        = string
}

variable "requester_route_table_ids" {
  description = "List of route table IDs in requester VPC"
  type        = list(string)
}

variable "accepter_route_table_ids" {
  description = "List of route table IDs in accepter VPC"
  type        = list(string)
}

variable "requester_vpc_cidr" {
  description = "CIDR block of requester VPC"
  type        = string
}

variable "accepter_vpc_cidr" {
  description = "CIDR block of accepter VPC"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}
