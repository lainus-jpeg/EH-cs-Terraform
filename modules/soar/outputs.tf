output "webhook_url" {
  description = "Webhook URL for Prometheus Alertmanager"
  value       = "https://${aws_api_gateway_rest_api.soar_webhook.id}.execute-api.${var.aws_region}.amazonaws.com/dev/alerts"
}

output "lambda_function_arn" {
  description = "ARN of SOAR Lambda function"
  value       = aws_lambda_function.soar_orchestrator.arn
}

output "sns_topic_arn" {
  description = "ARN of SNS topic for alerts"
  value       = aws_sns_topic.soar_alerts.arn
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_api_gateway_rest_api.soar_webhook.id
}

output "waf_ip_set_id" {
  description = "WAFv2 IP Set ID for blocklist"
  value       = aws_wafv2_ip_set.blocklist.id
}

output "waf_ip_set_arn" {
  description = "WAFv2 IP Set ARN for blocklist"
  value       = aws_wafv2_ip_set.blocklist.arn
}

output "waf_ip_set_name" {
  description = "WAFv2 IP Set name for blocklist"
  value       = aws_wafv2_ip_set.blocklist.name
}
