# SOAR Module - Security Orchestration, Automation and Response
# Orchestrates security responses based on alert severity

# Lambda execution role
resource "aws_iam_role" "soar_lambda_role" {
  name_prefix = "soar-lambda-role-"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "soar-lambda-role"
  }
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.soar_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# SNS permissions for publishing alerts
resource "aws_iam_role_policy" "lambda_sns_policy" {
  name   = "soar-lambda-sns-policy"
  role   = aws_iam_role.soar_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.soar_alerts.arn
      }
    ]
  })
}

# WAF permissions for IP blocking
resource "aws_iam_role_policy" "lambda_waf_policy" {
  name   = "soar-lambda-waf-policy"
  role   = aws_iam_role.soar_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetIPSet",
          "wafv2:UpdateIPSet"
        ]
        Resource = "arn:aws:wafv2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:regional/ipset/*"
      },
      {
        Effect = "Allow"
        Action = [
          "wafv2:ListIPSets"
        ]
        Resource = "*"
      }
    ]
  })
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Lambda function for SOAR orchestration
resource "aws_lambda_function" "soar_orchestrator" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "soar-alert-orchestrator"
  role          = aws_iam_role.soar_lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN       = aws_sns_topic.soar_alerts.arn
      WAF_IP_SET_NAME     = aws_wafv2_ip_set.blocklist.name
      WAF_IP_SET_ID       = aws_wafv2_ip_set.blocklist.id
      AWS_REGION_NAME     = var.aws_region
      WAF_SCOPE           = "REGIONAL"
    }
  }

  tags = {
    Name = "soar-alert-orchestrator"
  }
}

# Create WAF IP set for blocklist
resource "aws_wafv2_ip_set" "blocklist" {
  name               = var.waf_ip_set_name
  description        = "IP set for SOAR-blocked malicious IPs"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = []  # Start empty, will be populated by Lambda

  tags = {
    Name = "soar-blocklist"
  }
}

# Archive Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda.zip"
}

# API Gateway for Alertmanager webhook
resource "aws_api_gateway_rest_api" "soar_webhook" {
  name        = "soar-webhook-${var.environment}"
  description = "Webhook for Prometheus Alertmanager"

  tags = {
    Name = "soar-webhook"
  }
}

# API Gateway resource
resource "aws_api_gateway_resource" "alerts" {
  rest_api_id = aws_api_gateway_rest_api.soar_webhook.id
  parent_id   = aws_api_gateway_rest_api.soar_webhook.root_resource_id
  path_part   = "alerts"
}

# API Gateway POST method
resource "aws_api_gateway_method" "alerts_post" {
  rest_api_id      = aws_api_gateway_rest_api.soar_webhook.id
  resource_id      = aws_api_gateway_resource.alerts.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = var.require_api_key
}

# API Gateway integration with Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id      = aws_api_gateway_rest_api.soar_webhook.id
  resource_id      = aws_api_gateway_resource.alerts.id
  http_method      = aws_api_gateway_method.alerts_post.http_method
  type             = "AWS_PROXY"
  integration_http_method = "POST"
  uri              = aws_lambda_function.soar_orchestrator.invoke_arn
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar_orchestrator.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.soar_webhook.execution_arn}/*/*"
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "soar" {
  rest_api_id = aws_api_gateway_rest_api.soar_webhook.id
  stage_name  = var.environment

  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]

  triggers = {
    redeployment = aws_api_gateway_rest_api.soar_webhook.body
  }
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "soar_lambda_logs" {
  name              = "/aws/lambda/soar-alert-orchestrator"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "soar-lambda-logs"
  }
}

# SNS topic for email notifications (fallback)
resource "aws_sns_topic" "soar_alerts" {
  name_prefix = "soar-alerts-"
  display_name = "SOAR Alerts"

  tags = {
    Name = "soar-alerts"
  }
}

# SNS email subscription
resource "aws_sns_topic_subscription" "soar_alerts_email" {
  topic_arn = aws_sns_topic.soar_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
