# GitHub Actions OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name = "github-actions-oidc"
  }
}

# GitHub Actions IAM Role for ECR Push
resource "aws_iam_role" "github_actions_ecr_push" {
  name = "github-actions-ecr-push"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:lainus-jpeg/EH-cs1-api:ref:refs/heads/main",
              "repo:lainus-jpeg/EH-cs1-api:ref:refs/heads/develop",
              "repo:lainus-jpeg/EH-cs1-frontend:ref:refs/heads/main",
              "repo:lainus-jpeg/EH-cs1-frontend:ref:refs/heads/develop",
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name = "github-actions-ecr-push"
  }
}

# Permissions for GitHub Actions to push to ECR
resource "aws_iam_role_policy" "github_actions_ecr_push_policy" {
  name = "github-actions-ecr-push-policy"
  role = aws_iam_role.github_actions_ecr_push.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/apps/*"
      }
    ]
  })
}

# Monitoring VPC Module
module "monitoring_vpc" {
  source = "./modules/vpc"

  vpc_name              = "monitoring-vpc"
  vpc_cidr              = var.monitoring_vpc_cidr
  enable_nat_gateway    = false
  enable_internet_gateway = true
  
  public_subnet_cidrs   = var.monitoring_public_subnet_cidrs
  public_subnet_name    = "Monitoring Subnet Pub"
  private_subnet_cidrs  = var.monitoring_private_subnet_cidrs
  private_subnet_name   = "Monitoring Subnet Priv"
  availability_zones    = var.availability_zones

  environment = var.environment
}

# Apps VPC Module
module "apps_vpc" {
  source = "./modules/vpc"

  vpc_name              = "apps-vpc"
  vpc_cidr              = var.apps_vpc_cidr
  enable_nat_gateway    = var.apps_enable_nat_gateway
  enable_internet_gateway = var.apps_enable_internet_gateway
  nat_gateway_subnet    = 0  # Deploy NAT Gateway in first (AZ1) public subnet only
  
  public_subnet_cidrs      = var.apps_public_subnet_cidrs
  public_subnet_name       = "DMZ"
  private_app_subnet_cidrs = var.apps_private_app_subnet_cidrs
  private_app_subnet_name  = "ASG Apps Subnet Priv"
  private_db_subnet_cidrs  = var.apps_private_db_subnet_cidrs
  private_db_subnet_name   = "DB Subnet Priv"
  availability_zones       = var.availability_zones

  environment = var.environment
}

# Security Groups Module
module "security_groups" {
  source = "./modules/security_groups"

  apps_vpc_id   = module.apps_vpc.vpc_id
  monitoring_vpc_id     = module.monitoring_vpc.vpc_id
  apps_vpc_cidr = var.apps_vpc_cidr
  monitoring_vpc_cidr   = var.monitoring_vpc_cidr

  alb_port = var.alb_port
  
  environment = var.environment
}

# Application Load Balancer Module
module "alb" {
  source = "./modules/alb"

  alb_name             = "apps-alb"
  vpc_id               = module.apps_vpc.vpc_id
  public_subnet_ids    = module.apps_vpc.public_subnet_ids
  security_group_id    = module.security_groups.alb_security_group_id

  frontend_target_group_name = "apps-frontend-tg"
  api_target_group_name      = "apps-api-tg"
  
  alb_port            = var.alb_port
  health_check_path   = var.health_check_path
  health_check_interval = var.health_check_interval
  health_check_timeout  = var.health_check_timeout
  health_check_healthy_threshold   = var.health_check_healthy_threshold
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold

  environment = var.environment
}

# Frontend Module
module "frontend" {
  source = "./modules/asg"

  asg_name            = "ASG-frontend"
  display_name        = "Frontend-server"
  min_size            = var.frontend_asg_min_size
  max_size            = var.frontend_asg_max_size
  desired_capacity    = var.frontend_asg_desired_capacity
  
  vpc_id              = module.apps_vpc.vpc_id
  subnet_ids          = module.apps_vpc.private_app_subnet_ids
  security_group_id   = module.security_groups.app_security_group_id
  
  target_group_arn    = module.alb.frontend_target_group_arn
  target_group_name   = module.alb.frontend_target_group_name
  
  instance_type       = var.instance_type
  ami_owner           = var.ami_owner
  ami_name_filter     = var.ami_name_filter

  environment = var.environment
}

# API Module
module "api" {
  source = "./modules/asg"

  asg_name            = "ASG-api"
  display_name        = "API-server"
  min_size            = var.api_asg_min_size
  max_size            = var.api_asg_max_size
  desired_capacity    = var.api_asg_desired_capacity
  
  vpc_id              = module.apps_vpc.vpc_id
  subnet_ids          = module.apps_vpc.private_app_subnet_ids
  security_group_id   = module.security_groups.app_security_group_id
  
  target_group_arn    = module.alb.api_target_group_arn
  target_group_name   = module.alb.api_target_group_name
  
  instance_type       = var.instance_type
  ami_owner           = var.ami_owner
  ami_name_filter     = var.ami_name_filter

  environment = var.environment
}

# RDS Module
module "rds" {
  source = "./modules/rds"

  identifier              = "apps-postgres-db"
  engine                  = var.rds_engine
  engine_version          = var.rds_engine_version
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  
  vpc_id                  = module.apps_vpc.vpc_id
  db_subnet_group_name    = "apps-db-subnet-group"
  db_subnet_ids           = module.apps_vpc.private_db_subnet_ids
  
  security_group_id       = module.security_groups.rds_security_group_id
  
  multi_az                = var.rds_multi_az
  backup_retention_period = var.rds_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"
  
  skip_final_snapshot     = true
  final_snapshot_identifier = null

  environment = var.environment
}

# VPC Peering Module
module "vpc_peering" {
  count = var.enable_vpc_peering ? 1 : 0
  
  source = "./modules/vpc_peering"

  requester_vpc_id = module.apps_vpc.vpc_id
  accepter_vpc_id  = module.monitoring_vpc.vpc_id

  requester_route_table_ids = module.apps_vpc.private_app_route_table_ids
  accepter_route_table_ids  = concat(module.monitoring_vpc.private_route_table_ids, module.monitoring_vpc.public_route_table_ids)

  requester_vpc_cidr = var.apps_vpc_cidr
  accepter_vpc_cidr  = var.monitoring_vpc_cidr

  environment = var.environment
}

# Monitoring Module (Prometheus + Grafana)
module "monitoring" {
  source = "./modules/monitoring"

  instance_name          = "${var.project_name}-monitoring"
  instance_type          = "t3.micro"
  monitoring_vpc_id      = module.monitoring_vpc.vpc_id
  monitoring_vpc_cidr    = var.monitoring_vpc_cidr
  apps_vpc_cidr          = var.apps_vpc_cidr
  apps_vpc_id            = module.apps_vpc.vpc_id
  subnet_id              = module.monitoring_vpc.public_subnet_ids[0]
  apps_vpc_app_sg_id     = module.security_groups.app_security_group_id
  prometheus_retention   = 15
  aws_region             = var.aws_region
  
  environment = var.environment
}

# SOAR Module (Security Orchestration, Automation and Response)
module "soar" {
  source = "./modules/soar"

  environment         = var.environment
  aws_region          = var.aws_region
  ses_from_email      = var.ses_from_email
  alert_email         = var.alert_email
  waf_ip_set_name     = var.waf_ip_set_name
  require_api_key     = var.require_api_key
  log_retention_days  = var.log_retention_days
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"
  
  environment = var.environment
}

# IAM Role for EC2 to pull from ECR
resource "aws_iam_role" "ec2_ecr_pull" {
  name = "ec2-ecr-pull"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# SSM Parameters for Docker image URIs
resource "aws_ssm_parameter" "frontend_image_uri" {
  name            = "/apps/frontend/image-uri"
  description     = "Frontend Docker image URI in ECR"
  type            = "String"
  value           = "${module.ecr.frontend_repository_url}:latest"
  overwrite       = true
  tier            = "Standard"
  
  tags = {
    Name = "frontend-image-uri"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "api_image_uri" {
  name            = "/apps/api/image-uri"
  description     = "API Docker image URI in ECR"
  type            = "String"
  value           = "${module.ecr.api_repository_url}:latest"
  overwrite       = true
  tier            = "Standard"
  
  tags = {
    Name = "api-image-uri"
    Environment = var.environment
  }
}

# SSM Parameters for Database Credentials
resource "aws_ssm_parameter" "db_server" {
  name            = "/apps/api/DB_SERVER"
  description     = "RDS database server address"
  type            = "String"
  value           = module.rds.rds_address
  overwrite       = true
  tier            = "Standard"
  
  tags = {
    Name = "db-server"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "db_port" {
  name            = "/apps/api/DB_PORT"
  description     = "RDS database port"
  type            = "String"
  value           = tostring(module.rds.rds_port)
  overwrite       = true
  tier            = "Standard"
  
  tags = {
    Name = "db-port"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "db_name" {
  name            = "/apps/api/DB_NAME"
  description     = "RDS database name"
  type            = "String"
  value           = module.rds.rds_database_name
  overwrite       = true
  tier            = "Standard"
  
  tags = {
    Name = "db-name"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "db_user" {
  name            = "/apps/api/DB_USER"
  description     = "RDS database username"
  type            = "String"
  value           = module.rds.rds_username
  overwrite       = true
  tier            = "Standard"
  
  tags = {
    Name = "db-user"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "db_password" {
  name            = "/apps/api/DB_PASSWORD"
  description     = "RDS database password"
  type            = "SecureString"
  value           = module.rds.rds_password
  overwrite       = true
  tier            = "Standard"
  
  tags = {
    Name = "db-password"
    Environment = var.environment
  }
}

# SOAR Webhook URL for failed login alerts
resource "aws_ssm_parameter" "soar_webhook_url" {
  name            = "/apps/api/SOAR_WEBHOOK_URL"
  description     = "SOAR webhook URL for security alerts"
  type            = "String"
  value           = module.soar.webhook_url
  overwrite       = true
  tier            = "Standard"
  
  tags = {
    Name = "soar-webhook-url"
    Environment = var.environment
  }
}

# Policy update for EC2 to read from SSM Parameter Store
resource "aws_iam_role_policy" "ec2_ssm_read" {
  name = "ec2-ssm-read-policy"
  role = aws_iam_role.ec2_ecr_pull.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          aws_ssm_parameter.frontend_image_uri.arn,
          aws_ssm_parameter.api_image_uri.arn,
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/apps/api/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# Policy for EC2 to pull from ECR
resource "aws_iam_role_policy" "ec2_ecr_pull" {
  name = "ec2-ecr-pull-policy"
  role = aws_iam_role.ec2_ecr_pull.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken"
        ]
        Resource = [
          module.ecr.frontend_repository_arn,
          module.ecr.api_repository_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/apps/*"
      }
    ]
  })
}

# Data source for AWS account ID
data "aws_caller_identity" "current" {}


