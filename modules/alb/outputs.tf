output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "alb_id" {
  description = "ID of the load balancer"
  value       = aws_lb.main.id
}

output "frontend_target_group_arn" {
  description = "ARN of frontend target group"
  value       = aws_lb_target_group.frontend.arn
}

output "frontend_target_group_name" {
  description = "Name of frontend target group"
  value       = aws_lb_target_group.frontend.name
}

output "api_target_group_arn" {
  description = "ARN of API target group"
  value       = aws_lb_target_group.api.arn
}

output "api_target_group_name" {
  description = "Name of API target group"
  value       = aws_lb_target_group.api.name
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}
