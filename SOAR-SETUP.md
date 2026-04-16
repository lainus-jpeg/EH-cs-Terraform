# SOAR Setup and Configuration Guide

## Overview

This guide explains how to set up and configure your Security Orchestration, Automation and Response (SOAR) system with:
- **Email Notifications** via AWS SES
- **WAF IP Blocking** for threat response
- **Prometheus/Alertmanager Integration** for alert automation

## Architecture

```
Prometheus/Alertmanager
         ↓
    Webhook POST
         ↓
API Gateway → Lambda Function (SOAR Orchestrator)
         ↓
    ┌────┴────┐
    ↓         ↓
   SES      WAF v2
(Email)  (IP Blocking)
```

## Step 1: Verify SES Email Address

Before deploying, you must verify an email address in AWS SES.

### Setup:
1. Go to AWS Console → SES (Simple Email Service)
2. Ensure you're in the **correct region** (eu-central-1 for this setup)
3. Go to **Verified identities** → **Create identity**
4. Choose **Email address** and enter your email
5. Click **Create identity**
6. Check your email inbox for verification link and click it
7. The email status should show as **Verified**

### In Terraform:

Update your `terraform.tfvars`:

```hcl
ses_from_email = "your-verified-email@example.com"  # Use your verified SES email
alert_email    = "526307@student.fontys.nl"          # Where to send alerts
```

**Note:** In SES Development/Sandbox mode (default), you can only send to verified emails. Both `ses_from_email` and `alert_email` should be verified.

## Step 2: Set Up WAF IP Set

The Lambda function needs an existing WAF IP set to update.

### Create WAF IP Set:

1. Go to AWS Console → WAF & Shield → Security groups
2. Choose your region (eu-central-1)
3. Go to **IP sets** → **Create IP set**
4. **Name:** `waf-blocklist` (or your preferred name)
5. **IP version:** IPv4
6. **Region:** Regional
7. Create the set (leave addresses empty for now)
8. Note the IP set name

### Update terraform.tfvars:

```hcl
waf_ip_set_name = "waf-blocklist"  # Use your IP set name
```

## Step 3: Deploy Terraform

Deploy the SOAR infrastructure:

```bash
cd infra/terraform/v4/dev

# Set your variables
export TF_VAR_ses_from_email="your-verified-email@example.com"

# Plan
terraform plan

# Apply
terraform apply
```

After successful deployment, you'll see:
- `soar_webhook_url` - Use this in Alertmanager
- `soar_lambda_function_arn` - Lambda function ARN
- `soar_api_gateway_id` - API Gateway ID

## Step 4: Configure Prometheus Alertmanager

Configure Alertmanager to send alerts to your SOAR webhook.

### Alertmanager Configuration (prometheus.yml or alertmanager.yml):

```yaml
global:
  resolve_timeout: 5m

# Define the webhook receiver
receivers:
  - name: 'soar'
    webhook_configs:
      - url: 'https://<API_GATEWAY_ID>.execute-api.eu-central-1.amazonaws.com/dev/alerts'
        send_resolved: true
        headers:
          Content-Type: 'application/json'

# Route alerts to SOAR
route:
  receiver: 'soar'
  group_by: ['alertname', 'cluster']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  routes:
    - receiver: 'soar'
      match:
        severity: 'critical|high'
```

Replace `<API_GATEWAY_ID>` with the actual API Gateway ID from Terraform output.

### Example Alert Configuration:

Configure alerts in Prometheus to include severity and source IP labels:

```yaml
groups:
  - name: security_alerts
    interval: 30s
    rules:
      - alert: SuspiciousTraffic
        expr: increase(connections_from_ip{blocked="true"}[5m]) > 10
        for: 1m
        labels:
          severity: high
          source_ip: "{{ $labels.src_ip }}"
        annotations:
          summary: "Suspicious traffic from IP {{ $labels.src_ip }}"
          description: "Detected suspicious activity from source IP: {{ $labels.src_ip }}"
      
      - alert: BruteForceAttempt
        expr: rate(failed_login_attempts[5m]) > 5
        for: 2m
        labels:
          severity: critical
          source_ip: "{{ $labels.client_ip }}"
        annotations:
          summary: "Brute force attack detected"
          description: "Multiple failed login attempts from {{ $labels.client_ip }}"
```

## Step 5: Test the Setup

### Test Email Notification:

Send a test alert to your webhook:

```bash
curl -X POST https://<API_GATEWAY_ID>.execute-api.eu-central-1.amazonaws.com/dev/alerts \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [
      {
        "status": "firing",
        "labels": {
          "alertname": "TestAlert",
          "severity": "high",
          "source_ip": "192.0.2.1"
        },
        "annotations": {
          "summary": "Test Alert",
          "description": "This is a test alert from IP 192.0.2.1"
        }
      }
    ]
  }'
```

Expected response:
```json
{
  "message": "SOAR orchestration completed",
  "alerts_processed": 1,
  "actions_taken": [
    "📧 Email notification sent for alert: TestAlert",
    "🚫 Blocked IP 192.0.2.1 in WAF blocklist"
  ]
}
```

### Check Email:
- An email should arrive at your `alert_email` address with alert details

### Check CloudWatch Logs:
1. Go to AWS Console → CloudWatch → Log Groups
2. Find `/aws/lambda/soar-alert-orchestrator`
3. Check the logs for execution details

### Check WAF IP Set:
1. Go to AWS WAF & Shield → IP sets
2. Open your IP set
3. You should see blocked IPs listed (e.g., `192.0.2.1/32`)

## Step 6: Update WAF Web ACL

Link the IP set to your WAF Web ACL to actually block traffic.

### In AWS Console:

1. Go to WAF & Shield → Web ACLs
2. Click your existing Web ACL (e.g., `frontend-api-alb-waf-acl`)
3. Go to **Rules** tab
4. Add a new rule:
   - **Name:** Block IPs from Blocklist
   - **Type:** IP reputation list
   - **Statement:** Choose your IP set
   - **Action:** Block
   - **Priority:** High (execute early)
5. Save changes

## Alert Severity Levels

The Lambda function takes different actions based on alert severity:

| Severity | Email | Block IP |
|----------|-------|----------|
| Low/Info | ✓ | ✗ |
| Medium/Warning | ✓ | ✗ |
| High | ✓ | ✓ |
| Critical | ✓ | ✓ |

## Alert Label Parsing

The Lambda looks for source IP in these label names (in order):
1. `source_ip`
2. `sourceIP`
3. `client_ip`
4. `attacker_ip`
5. `src_ip`
6. Extracts from alert description using regex pattern

## Troubleshooting

### Email Not Received
- Check SES is not in Sandbox mode (apply for production access)
- Verify both `ses_from_email` and `alert_email` are verified in SES
- Check CloudWatch logs for errors

### Lambda Timeout
- Check WAF IP set permissions
- Verify WAF IP set exists in the correct region
- Check WAF IP set is not locked

### Webhook Returning 500 Error
- Check Lambda execution role permissions for SES and WAF
- Verify WAF IP set name matches Terraform variable
- Check JSON format in alert payload

### IPs Not Blocking in WAF
- Ensure IP set is linked to a rule in your WAF Web ACL
- Check rule priority (should be high)
- Verify IP format in WAF (should be CIDR, e.g., `192.0.2.1/32`)

## Advanced Configuration

### Rate Limiting
To prevent excessive IP blocking, modify the Lambda to:
- Track recently blocked IPs
- Implement cooldown period
- Set maximum IPs per hour

### Custom Actions
Extend the Lambda to:
- Send to additional channels (Slack, PagerDuty)
- Update security groups instead of WAF
- Create CloudWatch alarms
- Trigger SNS notifications to security team

### Production Mode SES
To send from/to any email address:
1. Go to SES → Account dashboard
2. Apply for production access
3. AWS will review your request (usually 24 hours)
4. Once approved, no verified email requirements

## Monitoring

### CloudWatch Dashboard

Create a dashboard to monitor SOAR:

```hcl
# Add to your Terraform if desired
resource "aws_cloudwatch_dashboard" "soar" {
  dashboard_name = "soar-monitoring"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum" }],
            ["AWS/Lambda", "Errors", { stat = "Sum" }],
            ["AWS/Lambda", "Duration", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
        }
      }
    ]
  })
}
```

## Cost Estimation

- **API Gateway:** ~$0.35/million requests
- **Lambda:** Free tier covers 1 million/month; ~$0.20/million after
- **SES:** ~$0.10 per 1,000 emails (free tier: 62,000/day)
- **WAF:** ~$5.00/month for IP set updates

Total: Generally **$5-20/month** depending on alert volume
