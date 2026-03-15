output "instance_id" {
  description = "ID of the Prometheus EC2 instance"
  value       = aws_instance.monitoring.id
}

output "instance_private_ip" {
  description = "Private IP of the Prometheus instance"
  value       = aws_instance.monitoring.private_ip
}

output "instance_public_ip" {
  description = "Public IP of the Prometheus instance"
  value       = aws_instance.monitoring.public_ip
}

output "grafana_instance_id" {
  description = "ID of the Grafana EC2 instance"
  value       = aws_instance.grafana.id
}

output "grafana_instance_private_ip" {
  description = "Private IP of the Grafana instance"
  value       = aws_instance.grafana.private_ip
}

output "grafana_instance_public_ip" {
  description = "Public IP of the Grafana instance"
  value       = aws_instance.grafana.public_ip
}

output "security_group_id" {
  description = "ID of the monitoring security group"
  value       = aws_security_group.monitoring.id
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${aws_instance.monitoring.public_ip}:9090"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://${aws_instance.grafana.public_ip}:3000"
}

output "grafana_default_credentials" {
  description = "Grafana default credentials (change after first login)"
  value       = "admin / admin"
}

# test