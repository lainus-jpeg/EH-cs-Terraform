# WAF Web ACL to protect the ALB with SOAR blocklist
resource "aws_wafv2_web_acl" "alb_waf" {
  name  = "apps-alb-waf-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: Block IPs from SOAR blocklist
  rule {
    name     = "block-soar-ips"
    priority = 0

    action {
      block {}
    }

    statement {
      ip_set_reference_statement {
        arn = module.soar.waf_ip_set_arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "block-soar-ips"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Rules - Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "apps-alb-waf-acl"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "apps-alb-waf-acl"
  }
}

# Associate WAF Web ACL with ALB
resource "aws_wafv2_web_acl_association" "alb_waf_association" {
  resource_arn = module.alb.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.alb_waf.arn
}

# CloudWatch Log Group for WAF
resource "aws_cloudwatch_log_group" "waf_log_group" {
  name              = "/aws/wafv2/apps-alb"
  retention_in_days = 7

  tags = {
    Name = "waf-logs"
  }
}
