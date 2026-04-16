output "rds_endpoint" {
  description = "The connection endpoint for the RDS database"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "rds_address" {
  description = "The address of the RDS database"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "The port of the RDS database"
  value       = aws_db_instance.main.port
}

output "rds_database_name" {
  description = "The name of the database"
  value       = aws_db_instance.main.db_name
}

output "rds_instance_id" {
  description = "The RDS instance ID"
  value       = aws_db_instance.main.id
}

output "rds_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.main.name
}

output "rds_username" {
  description = "The master username for the database"
  value       = aws_db_instance.main.username
}

output "rds_password" {
  description = "The master password for the database"
  value       = random_password.rds_password.result
  sensitive   = true
}
