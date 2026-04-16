# SOAR Real-World Examples & Scenarios

## Scenario 1: DDoS Attack Response

### Alert Configuration (Prometheus)

```yaml
- alert: DDoSAttack
  expr: rate(http_requests_total[1m]) > 10000
  for: 30s
  labels:
    severity: critical
    source_ip: "{{ $labels.remote_addr }}"
  annotations:
    summary: "DDoS attack detected from {{ $labels.remote_addr }}"
    description: |
      Unusually high request rate detected.
      Source: {{ $labels.remote_addr }}
      Rate: {{ $value }} req/s
```

### Automatic SOAR Response

1. ✅ **Email Sent** → Security team receives detailed alert with:
   - Source IP
   - Request rate
   - Timestamp
   - Alert severity

2. ✅ **IP Blocked in WAF** → Immediate traffic blocking from attacker IP

3. **Timeline:**
   - T+0s: Alert fires in Prometheus
   - T+1s: Webhook triggers Lambda
   - T+2s: Email sent via SES
   - T+2s: IP added to WAF blocklist
   - Total response time: ~2 seconds

---

## Scenario 2: SQL Injection Attempt

### Alert (for Web Application Firewall bypass attempt)

```yaml
- alert: SQLInjectionAttempt
  expr: increase(waf_blocked_sql_injection[5m]) > 0
  for: 10s
  labels:
    severity: critical
    source_ip: "{{ $labels.client_ip }}"
    attack_type: "sql_injection"
  annotations:
    summary: "SQL injection attack blocked from {{ $labels.client_ip }}"
    description: |
      Multiple SQL injection patterns detected.
      Client IP: {{ $labels.client_ip }}
      Attack Type: SQL Injection
      Details: See WAF logs for payload
```

### SOAR Action

**Email Content:**
```
=== SOAR Alert Notification ===
Status: firing
Severity: CRITICAL
Alert: SQLInjectionAttempt
Source IP: 203.0.113.45

Description: SQL injection attack blocked from 203.0.113.45

Actions Taken:
📧 Email notification sent
🚫 Blocked IP 203.0.113.45 in WAF blocklist
```

**Consequence:**
- Attacker can no longer access your application
- Security team is notified immediately
- Forensics team can review WAF logs

---

## Scenario 3: Brute Force Attack

### Alert Configuration

```yaml
- alert: BruteForceLogin
  expr: |
    sum(rate(auth_failed_total[5m])) by (source_ip) > 10
  for: 1m
  labels:
    severity: high
    source_ip: "{{ $labels.source_ip }}"
    attack_type: "brute_force"
  annotations:
    summary: "Brute force login attempt from {{ $labels.source_ip }}"
    description: |
      {{ $value | humanize }} failed login attempts/sec
      Source: {{ $labels.source_ip }}
      Rate: {{ $value }} attempts/sec
```

### Scenario Details

- **Medium severity:** Email only, no IP block
- **Goal:** Alert security team to monitor
- **Why no block?** May block legitimate users with password trouble

### Email Includes

```
Alert: BruteForceLogin
Severity: HIGH
Source IP: 198.51.100.25

8 failed login attempts per second from 198.51.100.25

Note: Email sent only. IP not automatically blocked.
Please review and manually block if confirmed attack.
```

---

## Scenario 4: Ransomware Detection (via anomalous file access)

### Alert

```yaml
- alert: RansomwareDetection
  expr: rate(file_encryption_patterns_detected[30s]) > 0
  for: 30s
  labels:
    severity: critical
    source_ip: "{{ $labels.instance_ip }}"
    threat_level: "ransomware"
  annotations:
    summary: "Potential ransomware activity detected"
    description: |
      Anomalous file access patterns detected on {{ $labels.instance }}.
      Source: {{ $labels.instance_ip }}
      Action: Immediate network isolation recommended
```

### Automatic Response

✅ **Email Alert** includes:
- Affected instance
- Timeline of suspicious activity
- Recommended actions
- Contact information for incident response team

⚠️ **No automatic IP block** because:
- Internal IP (not external attacker)
- Requires more complex response
- Needs human decision for containment

---

## Scenario 5: Data Exfiltration Attempt

### Alert

```yaml
- alert: DataExfiltration
  expr: sum(rate(outbound_bytes_total{destination="external"}[1m])) by (source_ip) > 104857600
  for: 2m
  labels:
    severity: critical
    source_ip: "{{ $labels.source_ip }}"
    data_direction: "egress"
  annotations:
    summary: "Unusual outbound data transfer from {{ $labels.source_ip }}"
    description: |
      {{ $value | humanize }}B/s of outbound traffic detected.
      Possible data exfiltration from {{ $labels.source_ip }}
      Destination: {{ $labels.destination_ip }}
```

### SOAR Actions

**Email Notification Includes:**
- Volume of data transferred
- Destination IP/domain
- Timestamp
- Affected system
- Immediate recommendations

**Impact:**
- ✅ IP blocked in WAF (prevents future requests)
- ⚠️ May need to also block at network level
- 🔍 Security team initiates forensics

---

## Scenario 6: Compromised API Key Detection

### Alert

```yaml
- alert: CompromisedAPIKey
  expr: increase(api_auth_failures{reason="invalid_key"}[5m]) > 100
  for: 2m
  labels:
    severity: critical
    source_ip: "{{ $labels.remote_addr }}"
    api_endpoint: "{{ $labels.endpoint }}"
  annotations:
    summary: "Multiple API authentication failures from {{ $labels.remote_addr }}"
    description: |
      {{ $value | humanize }} failed API auth attempts.
      Source: {{ $labels.remote_addr }}
      Endpoint: {{ $labels.endpoint }}
      Possible: Compromised API key being tested
```

### Response

**Email contains:**
```
Alert: CompromisedAPIKey
Severity: CRITICAL
Source: 192.0.2.100

100+ failed API authentication attempts

Actions Taken:
📧 Email notification sent
🚫 Blocked IP 192.0.2.100 in WAF

Recommended:
1. Rotate all API keys
2. Enable MFA
3. Review API access logs
4. Check for data access
```

---

## Scenario 7: Rate Limit Bypass Attempt

### Alert

```yaml
- alert: RateLimitBypass
  expr: sum(rate(http_requests_total[1m])) by (source_ip) > 500
  for: 30s
  labels:
    severity: medium
    source_ip: "{{ $labels.source_ip }}"
  annotations:
    summary: "Rate limit exceeded from {{ $labels.source_ip }}"
    description: "{{ $value | humanize }} requests/sec"
```

### SOAR Behavior

**Severity = Medium:**
- ✅ Email sent to security team
- ⚠️ IP NOT automatically blocked
- 🔍 Allows manual review

**Email Example:**
```
Alert: RateLimitBypass
Source IP: 192.0.2.50
Rate: 560 req/sec

Note: This alert does not automatically block.
Severity is medium to allow for legitimate spike review.

Review recommendations:
- Check if legitimate traffic spike
- Identify actual client IP (check for proxies)
- Consider manual blocking if confirmed attack
```

---

## Alert Severity Mapping

```
┌──────────────┬──────────────┬──────────────┐
│ Severity     │ Email Alert  │ WAF Block    │
├──────────────┼──────────────┼──────────────┤
│ INFO/LOW     │ ✗            │ ✗            │
│ MEDIUM       │ ✓            │ ✗            │
│ HIGH         │ ✓            │ ✓            │
│ CRITICAL     │ ✓            │ ✓            │
└──────────────┴──────────────┴──────────────┘
```

---

## Testing Your SOAR Setup

### Test 1: Send Test Email

```bash
curl -X POST https://YOUR_WEBHOOK_URL/alerts \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "TestAlert",
        "severity": "high",
        "source_ip": "TEST_IP_1"
      },
      "annotations": {
        "summary": "SOAR Test Alert",
        "description": "Testing SOAR email functionality"
      }
    }]
  }'
```

**Expected:** Email arrives in 30 seconds

### Test 2: Test IP Blocking

```bash
curl -X POST https://YOUR_WEBHOOK_URL/alerts \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "BlockTest",
        "severity": "critical",
        "source_ip": "198.51.100.42"
      },
      "annotations": {
        "summary": "WAF Block Test",
        "description": "Test IP blocking in WAF"
      }
    }]
  }'

# Check WAF IP set
aws wafv2 get-ip-set \
  --name waf-blocklist \
  --scope REGIONAL \
  --region eu-central-1 \
  --id YOUR_IP_SET_ID \
  | grep Addresses
```

**Expected:** `198.51.100.42/32` appears in IP set

### Test 3: Send Resolved Alert

```bash
curl -X POST https://YOUR_WEBHOOK_URL/alerts \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [{
      "status": "resolved",
      "labels": {
        "alertname": "TestAlert",
        "severity": "high"
      },
      "annotations": {
        "summary": "Alert Resolved",
        "description": "Testing resolved alert handling"
      }
    }]
  }'
```

**Expected:** Processing succeeds (Lambda logs show "resolved" status)

---

## Monitoring Your SOAR

### CloudWatch Dashboard Query

```bash
# Get Lambda invocation count (last hour)
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=soar-alert-orchestrator \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### Check Blocked IPs

```bash
# View all blocked IPs in WAF
aws wafv2 get-ip-set \
  --name waf-blocklist \
  --scope REGIONAL \
  --region eu-central-1 \
  --id YOUR_IP_SET_ID \
  --query 'IPSet.Addresses' \
  --output table
```

### View Lambda Errors

```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/soar-alert-orchestrator \
  --filter-pattern "ERROR" \
  --start-time $(($(date +%s)*1000 - 3600000))
```

---

## Cost Optimization

If running many tests, optimize costs:

```hcl
# In terraform.tfvars
log_retention_days = 1  # For dev/testing
# For production, use:
log_retention_days = 7
```

This keeps only 1 day of logs in dev, reducing CloudWatch costs.
