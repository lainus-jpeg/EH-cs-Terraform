output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "List of private app subnet IDs"
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "List of private DB subnet IDs"
  value       = aws_subnet.private_db[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (monitoring)"
  value       = concat(aws_subnet.private_app[*].id, aws_subnet.private_db[*].id, aws_subnet.private[*].id)
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = aws_route_table.private[*].id
}

output "private_app_route_table_ids" {
  description = "List of private app route table IDs"
  value       = aws_route_table.private_app[*].id
}

output "public_route_table_ids" {
  description = "List of public route table IDs"
  value       = aws_route_table.public[*].id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = try(aws_nat_gateway.main[0].id, null)
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = try(aws_internet_gateway.main[0].id, null)
}
