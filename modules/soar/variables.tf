variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "ses_from_email" {
  description = "SES verified email address for sending alerts"
  type        = string
}

variable "alert_email" {
  description = "Email address to receive security alerts"
  type        = string
}

variable "waf_ip_set_name" {
  description = "Name of the AWS WAFv2 IP set for blocklist (will be created if doesn't exist)"
  type        = string
  default     = "soar-blocklist"
}

variable "require_api_key" {
  description = "Require API key for webhook"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}
