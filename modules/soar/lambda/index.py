import json
import boto3
import os
from datetime import datetime
import re

# Initialize AWS clients
sns_client = boto3.client('sns', region_name=os.environ.get('AWS_REGION_NAME', 'eu-central-1'))
waf_client = boto3.client('wafv2', region_name=os.environ.get('AWS_REGION_NAME', 'eu-central-1'))

# Environment variables
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
WAF_IP_SET_NAME = os.environ['WAF_IP_SET_NAME']
WAF_IP_SET_ID = os.environ['WAF_IP_SET_ID']
WAF_SCOPE = os.environ['WAF_SCOPE']


def extract_source_ip(alert):
    """Extract source IP from alert labels"""
    labels = alert.get('labels', {})
    
    # Try multiple label names where source IP might be stored
    ip_candidates = [
        labels.get('source_ip'),
        labels.get('sourceIP'),
        labels.get('client_ip'),
        labels.get('attacker_ip'),
        labels.get('src_ip'),
    ]
    
    for ip in ip_candidates:
        if ip and is_valid_ip(ip):
            return ip
    
    # Try to extract from description
    description = alert.get('annotations', {}).get('description', '')
    ip_match = re.search(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b', description)
    if ip_match:
        return ip_match.group(0)
    
    return None


def is_valid_ip(ip):
    """Validate IPv4 address"""
    parts = ip.split('.')
    if len(parts) != 4:
        return False
    try:
        return all(0 <= int(part) <= 255 for part in parts)
    except ValueError:
        return False


def get_waf_ip_set():
    """Get current WAF IP set"""
    try:
        response = waf_client.get_ip_set(
            Name=WAF_IP_SET_NAME,
            Scope=WAF_SCOPE,
            Id=WAF_IP_SET_ID
        )
        return response
    except Exception as e:
        print(f"Error getting WAF IP set: {str(e)}")
        return None


def update_waf_ip_set(ip_address):
    """Add IP to WAF blocklist"""
    try:
        # Get current IP set
        response = waf_client.get_ip_set(
            Name=WAF_IP_SET_NAME,
            Scope=WAF_SCOPE,
            Id=WAF_IP_SET_ID
        )
        
        ip_set = response['IPSet']
        addresses = set(ip_set['Addresses'])
        
        # Add new IP (in CIDR format)
        ip_in_cidr = f"{ip_address}/32"
        if ip_in_cidr not in addresses:
            addresses.add(ip_in_cidr)
            
            # Update IP set
            waf_client.update_ip_set(
                Name=WAF_IP_SET_NAME,
                Scope=WAF_SCOPE,
                Id=WAF_IP_SET_ID,
                Addresses=list(addresses),
                LockToken=response['LockToken']
            )
            
            print(f"Successfully added {ip_address} to WAF blocklist")
            return True
        else:
            print(f"IP {ip_address} already in WAF blocklist")
            return True
            
    except Exception as e:
        print(f"Error updating WAF IP set: {str(e)}")
        raise


def send_email_alert(alerts_list, actions_taken):
    """Send email notification about alerts via SNS"""
    try:
        # Format alerts for email
        subject = f"Security Alert - SOAR Response - {len(alerts_list)} alert(s)"
        
        email_body = f"""
SECURITY ALERT - SOAR RESPONSE TRIGGERED
========================================

Alert Count: {len(alerts_list)}
Timestamp: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC

ALERTS:
-------
"""
        
        for alert in alerts_list:
            labels = alert.get('labels', {})
            annotations = alert.get('annotations', {})
            status = alert.get('status', 'unknown')
            severity = labels.get('severity', 'unknown')
            alert_name = labels.get('alertname', 'N/A')
            description = annotations.get('description', 'N/A')
            source_ip = extract_source_ip(alert)
            
            email_body += f"""
Alert: {alert_name}
Status: {status}
Severity: {severity}
Description: {description}
Source IP: {source_ip or 'N/A'}
---
"""
        
        email_body += f"""
ACTIONS TAKEN:
--------------
"""
        
        for action in actions_taken:
            email_body += f"{action}\n"
        
        email_body += f"""

Review and take appropriate action.
Time: {datetime.utcnow().isoformat()}
"""
        
        # Publish to SNS
        response = sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=email_body
        )
        
        print(f"Alert published to SNS. MessageId: {response['MessageId']}")
        return True
        
    except Exception as e:
        print(f"Error publishing to SNS: {str(e)}")
        raise


def lambda_handler(event, context):
    """
    Main Lambda handler for SOAR orchestration
    Triggered by Prometheus/Alertmanager webhook
    """
    try:
        print(f"Received event: {json.dumps(event)}")
        
        # Parse request body
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event.get('body', {})
        
        alerts = body.get('alerts', [])
        if not alerts:
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'No alerts to process'})
            }
        
        actions_taken = []
        ips_to_block = []
        
        # Process each alert
        for alert in alerts:
            labels = alert.get('labels', {})
            severity = labels.get('severity', 'unknown').lower()
            source_ip = extract_source_ip(alert)
            
            print(f"Processing alert: {labels.get('alertname')} (severity: {severity}, IP: {source_ip})")
            
            # Email notification for all alerts
            try:
                actions_taken.append(f"📧 Email notification sent for alert: {labels.get('alertname')}")
            except Exception as e:
                print(f"Error preparing email action: {str(e)}")
            
            # WAF IP blocking for critical/high severity
            if severity in ['high', 'critical'] and source_ip:
                ips_to_block.append(source_ip)
        
        # Send email with all alert details
        try:
            send_email_alert(alerts, actions_taken)
        except Exception as e:
            print(f"Error sending email: {str(e)}")
            actions_taken.append(f"❌ Email failed: {str(e)}")
        
        # Block IPs from high/critical severity alerts
        if ips_to_block:
            print(f"Blocking IPs: {ips_to_block}")
            for ip in set(ips_to_block):  # Remove duplicates
                try:
                    update_waf_ip_set(ip)
                    actions_taken.append(f"🚫 Blocked IP {ip} in WAF blocklist")
                except Exception as e:
                    print(f"Failed to block IP {ip}: {str(e)}")
                    actions_taken.append(f"⚠️ Failed to block IP {ip}: {str(e)}")
        
        # Return success response
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'SOAR orchestration completed',
                'alerts_processed': len(alerts),
                'actions_taken': actions_taken
            })
        }
        
    except Exception as e:
        print(f"Error in SOAR orchestrator: {str(e)}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Error processing alerts',
                'error': str(e)
            })
        }
