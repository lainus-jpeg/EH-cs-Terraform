output "frontend_repository_url" {
  description = "Frontend ECR repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}

output "frontend_repository_arn" {
  description = "Frontend ECR repository ARN"
  value       = aws_ecr_repository.frontend.arn
}

output "api_repository_url" {
  description = "API ECR repository URL"
  value       = aws_ecr_repository.api.repository_url
}

output "api_repository_arn" {
  description = "API ECR repository ARN"
  value       = aws_ecr_repository.api.arn
}
