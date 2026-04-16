# Alertmanager SOAR Integration Quick Reference

## Get Your SOAR Webhook URL

After Terraform deployment, retrieve the webhook URL:

```bash
terraform output soar_webhook_url
```

Output will look like:
```
https://abc123def456.execute-api.eu-central-1.amazonaws.com/dev/alerts
```

## Configuration Options

### Option 1: Complete Alertmanager Config

Create/update `/etc/alertmanager/alertmanager.yml`:

```yaml
global:
  resolve_timeout: 5m
  slack_api_url: ''  # Optional: if using Slack

templates:
  - '/etc/alertmanager/templates/*.tmpl'

route:
  receiver: 'default'
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  routes:
    # Critical/High severity → SOAR
    - receiver: 'soar'
      match:
        severity: 'critical|high'
      group_wait: 5s
    
    # All alerts → Default receiver (optional)
    - receiver: 'default'
      continue: true

receivers:
  - name: 'default'
    # Add your default receiver config (email, Slack, etc.)
    
  - name: 'soar'
    webhook_configs:
      - url: 'https://abc123def456.execute-api.eu-central-1.amazonaws.com/dev/alerts'
        send_resolved: true

inhibit_rules: []
```

### Option 2: Just Add SOAR Receiver

If you have an existing Alertmanager config, add SOAR as a receiver:

```yaml
receivers:
  - name: 'soar'
    webhook_configs:
      - url: 'https://YOUR_WEBHOOK_URL/alerts'
        send_resolved: true
        headers:
          Content-Type: 'application/json'
        
        # Optional: Retry configuration
        send_resolved: true
        http_sd_configs: []

# In your route section, add:
routes:
  - receiver: 'soar'
    match:
      severity: 'critical|high'
    continue: false
```

### Option 3: Docker Compose Setup

If running Alertmanager in Docker:

```yaml
version: '3.8'

services:
  alertmanager:
    image: prom/alertmanager:latest
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager.yml:/etc/alertmanager/alertmanager.yml
      - alertmanager-data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  alertmanager-data:
```

## Alert Format Expected by SOAR

Alertmanager sends alerts in this format:

```json
{
  "alerts": [
    {
      "status": "firing",
      "labels": {
        "alertname": "DDoSAttack",
        "severity": "critical",
        "source_ip": "203.0.113.45",
        "instance": "prod-server-1"
      },
      "annotations": {
        "summary": "DDoS attack detected",
        "description": "Unusual traffic spike from 203.0.113.45"
      },
      "startsAt": "2026-04-07T10:30:00Z",
      "endsAt": "0001-01-01T00:00:00Z"
    }
  ]
}
```

## Key Alert Labels

For optimal SOAR response, include these labels in your alerts:

```yaml
labels:
  severity: "critical"     # critical | high | medium | low
  source_ip: "203.0.113.45" # Any of: source_ip, sourceIP, client_ip, attacker_ip, src_ip
  alert_type: "security"   # For categorization
```

## Testing the Integration

### Manual Webhook Test

```bash
WEBHOOK_URL="https://your-api-gateway-id.execute-api.eu-central-1.amazonaws.com/dev/alerts"

curl -X POST $WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [
      {
        "status": "firing",
        "labels": {
          "alertname": "TestAlert",
          "severity": "high",
          "source_ip": "192.0.2.123"
        },
        "annotations": {
          "summary": "Test alert",
          "description": "Testing SOAR integration from IP 192.0.2.123"
        }
      }
    ]
  }'
```

### Check Lambda Logs

```bash
# View recent logs
aws logs tail /aws/lambda/soar-alert-orchestrator --follow

# Or search for errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/soar-alert-orchestrator \
  --filter-pattern "Error"
```

## Reload Alertmanager

After updating config:

```bash
# If running as systemd service
sudo systemctl reload alertmanager

# If running in Docker
docker-compose restart alertmanager

# Or send HUP signal
kill -HUP $(pidof alertmanager)
```

## Alertmanager Health Check

```bash
# Check if Alertmanager is responding
curl http://localhost:9093/-/healthy

# View current config
curl http://localhost:9093/api/v1/alerts

# View triggered alerts
curl http://localhost:9093/api/v1/alerts/groups
```

## AWS API Gateway Testing

If webhook returns errors, test the API Gateway:

```bash
# Get API Gateway details
terraform output soar_api_gateway_id

# Test the endpoint
aws apigateway test-invoke-method \
  --rest-api-id YOUR_API_ID \
  --resource-id RESOURCE_ID \
  --http-method POST \
  --body '{...alert json...}'
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| 404 on webhook | Verify full URL: `terraform output soar_webhook_url` |
| 429 Too Many Requests | Alertmanager sending too fast; increase `group_wait` |
| 500 Internal Server Error | Check Lambda logs; verify SES/WAF permissions |
| Email not received | Check SES sandbox mode; verify email verified |
| IPs not blocking in WAF | Ensure IP set linked to WAF Web ACL rule |

## Advanced: Custom Alert Rules

Example Prometheus alert rules that work well with SOAR:

```yaml
groups:
  - name: soar-security
    interval: 30s
    rules:
      # Web Server Attack Detection
      - alert: HTTPAttack
        expr: rate(http_requests_total{status=~"40[013]"}[5m]) > 100
        for: 1m
        labels:
          severity: high
          source_ip: "{{ $labels.client_ip }}"
        annotations:
          summary: "HTTP attack from {{ $labels.client_ip }}"
          
      # Database Attack Detection
      - alert: SQLInjectionAttempt
        expr: increase(http_requests_total{path=~".*union.*"}[5m]) > 5
        for: 30s
        labels:
          severity: critical
          source_ip: "{{ $labels.remote_addr }}"
        annotations:
          summary: "SQL injection attempt from {{ $labels.remote_addr }}"

      # Port Scanning Detection
      - alert: PortScan
        expr: count(increase(tcp_connections_total{status="rejected"}[1m])) by (source_ip) > 50
        for: 1m
        labels:
          severity: high
          source_ip: "{{ $labels.source_ip }}"
        annotations:
          summary: "Port scan detected from {{ $labels.source_ip }}"
```

## Next Steps

1. ✅ Update `alertmanager.yml` with SOAR webhook
2. ✅ Reload Alertmanager
3. ✅ Send test alert to verify integration
4. ✅ Monitor CloudWatch logs for successful processing
5. ✅ Verify IPs appear in WAF blocklist
6. ✅ Verify emails arrive at alert address
7. ✅ Link WAF IP set to Web ACL rule to enforce blocking
