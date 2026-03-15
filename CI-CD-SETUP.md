# CI/CD Pipeline Setup Guide

## Overview

This guide explains how to set up the CI/CD pipeline for the Frontend and API applications using GitHub Actions and Amazon ECR.

**Pipeline Flow**:
```
Code Push → GitHub Actions → Build Docker Image → Push to ECR → EC2 Instances Pull & Deploy
```

## Prerequisites

1. **GitHub Repositories**:
   - Frontend: https://github.com/lainus-jpeg/EH-cs1-frontend
   - API: https://github.com/lainus-jpeg/EH-cs1-api

2. **AWS Account**: Terraform has already configured:
   - ECR repositories (monitoring-apps-frontend, monitoring-apps-api)
   - GitHub OIDC provider
   - IAM roles for GitHub Actions and EC2

3. **Dockerfiles**: Both repos must have `Dockerfile` in the root (may need editing)

## Step 1: Deploy Terraform

```bash
cd z:\Semester 3\github rep case1\infra\terraform\v4\dev
terraform plan
terraform apply
```

This creates:
- ECR repositories
- GitHub OIDC provider
- IAM roles

## Step 2: Configure GitHub Secrets

For BOTH the Frontend and API repositories, add these secrets:

### In GitHub Repository Settings → Secrets and Variables → Actions:

1. **AWS_REGION**:
   - Value: `eu-central-1`

2. **AWS_ACCOUNT_ID**:
   - Value: Get from AWS Console or run:
   ```bash
   aws sts get-caller-identity --query Account --output text
   ```

3. **AWS_GITHUB_OIDC_ROLE_ARN**:
   - Value: From Terraform outputs or:
   ```bash
   cd z:\Semester 3\github rep case1\infra\terraform\v4\dev
   terraform output github_oidc_role_arn
   ```

## Step 3: Copy GitHub Actions Workflows

Copy the workflows to both repositories:

**For Frontend Repository** (`EH-cs1-frontend/.github/workflows/`):
- Copy: [frontend-ecr-push.yml](frontend-ecr-push.yml)

**For API Repository** (`EH-cs1-api/.github/workflows/`):
- Copy: [api-ecr-push.yml](api-ecr-push.yml)

Or manually create them in GitHub UI.

## Step 4: Create Dockerfiles (if needed)

### Frontend Dockerfile Example:
```dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY package*.json ./
RUN npm ci --only=production
EXPOSE 3000
CMD ["npm", "run", "preview"]
```

### API Dockerfile Example:
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3001
CMD ["node", "app.js"]
```

## Step 5: Setup AWS Systems Manager Parameter Store

For the API to access the database, create a parameter in Parameter Store:

```bash
aws ssm put-parameter \
  --name /apps/database-url \
  --value "postgresql://user:password@rds-endpoint:5432/dbname" \
  --type "SecureString" \
  --region eu-central-1
```

Replace with your actual RDS endpoint from Terraform outputs.

## Step 6: Test the Pipeline

1. **Push to main branch**:
   ```bash
   git add .
   git commit -m "Add deployment workflows"
   git push origin main
   ```

2. **Monitor GitHub Actions**:
   - Go to the repository → Actions tab
   - Watch the workflow execute

3. **Verify ECR**:
   ```bash
   aws ecr describe-images --repository-name monitoring-apps-frontend --region eu-central-1
   aws ecr describe-images --repository-name monitoring-apps-api --region eu-central-1
   ```

## How It Works

### On Code Push:
1. GitHub Actions triggers workflow
2. Builds Docker image
3. Logs into ECR using OIDC
4. Pushes image with git SHA and "latest" tags

### On EC2 Instances:
- Cron job runs every 5 minutes
- Checks for new "latest" image in ECR
- Pulls new image
- Stops old container
- Starts new container from new image
- Cleans up old images

### Logs:
- **Frontend**: `/var/log/frontend-deployment.log`, `/var/log/frontend-cron.log`
- **API**: `/var/log/api-deployment.log`, `/var/log/api-cron.log`

SSH into instances and check:
```bash
ssh -i monitoring-key.pem ec2-user@<instance-ip>
sudo tail -f /var/log/frontend-deployment.log
sudo docker ps
sudo docker logs frontend
```

## Troubleshooting

### GitHub Actions fails with "Invalid OIDC"
- Verify GitHub repos match the subjects in IAM role
- Check AWS_GITHUB_OIDC_ROLE_ARN secret is correct

### ECR push fails with "Permission denied"
- Verify GitHub secret values (AWS_ACCOUNT_ID, AWS_REGION)
- Check IAM role has ecr:PutImage permission
- Run: `aws sts get-caller-identity` to verify credentials

### Container doesn't start on EC2
- SSH into instance
- Check cron logs: `sudo cat /var/log/frontend-cron.log`
- Check Docker logs: `sudo docker logs frontend`
- Verify ECR credentials: `sudo docker login` (should work with IAM role)

### Database connection fails in API
- Verify Parameter Store has `/apps/database-url`
- Check RDS security group allows EC2 access
- Verify RDS endpoint and credentials are correct

## Updating Configurations

### To change deployment frequency:
Edit the cron schedule in `/modules/asg/scripts/setup-*.sh`:
```bash
# Current: every 5 minutes
*/5 * * * * /opt/deployment/deploy-*.sh

# Change to every 10 minutes:
*/10 * * * * /opt/deployment/deploy-*.sh

# Or every hour:
0 * * * * /opt/deployment/deploy-*.sh
```

### To add environment variables to containers:
1. Add to Parameter Store: `aws ssm put-parameter --name /apps/api-env-var --value "value"`
2. Update `deploy-api.sh` to fetch and set:
```bash
VAR=$(aws ssm get-parameter --name /apps/api-env-var --query 'Parameter.Value' --output text)
docker run -e MY_VAR="$VAR" ...
```

## Security Best Practices

✅ **Done**:
- OIDC authentication (no long-lived credentials)
- Secrets in Parameter Store (encrypted)
- ECR image scanning enabled
- Least-privilege IAM roles

🔄 **Recommended**:
- Enable image signing for ECR images
- Set up CloudWatch alarms for deployment failures
- Add VPC endpoints for ECR (reduce internet egress)
- Implement image vulnerability scanning

## Next Steps

1. Copy workflows to GitHub repositories
2. Add secrets to both repositories
3. Create Parameter Store `/apps/database-url`
4. Push code to main branch
5. Monitor first deployment in GitHub Actions
