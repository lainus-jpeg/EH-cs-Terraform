# Generate random password for RDS
resource "random_password" "rds_password" {
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store RDS password in Secrets Manager
resource "aws_secretsmanager_secret" "rds_password" {
  name_prefix             = "${var.identifier}-password-"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.identifier}-secret"
  }
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id = aws_secretsmanager_secret.rds_password.id
  secret_string = jsonencode({
    username = "postgres"
    password = random_password.rds_password.result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })
}

# Store RDS credentials in SSM Parameter Store for easy container access
resource "aws_ssm_parameter" "rds_password" {
  name  = "/apps/rds/password"
  type  = "SecureString"
  value = random_password.rds_password.result

  tags = {
    Name = "RDS-Password"
  }
}

resource "aws_ssm_parameter" "rds_host" {
  name  = "/apps/rds/host"
  type  = "String"
  value = aws_db_instance.main.address

  tags = {
    Name = "RDS-Host"
  }
}

resource "aws_ssm_parameter" "rds_port" {
  name  = "/apps/rds/port"
  type  = "String"
  value = tostring(aws_db_instance.main.port)

  tags = {
    Name = "RDS-Port"
  }
}

resource "aws_ssm_parameter" "rds_username" {
  name  = "/apps/rds/username"
  type  = "String"
  value = "postgres"

  tags = {
    Name = "RDS-Username"
  }
}

resource "aws_ssm_parameter" "rds_dbname" {
  name  = "/apps/rds/dbname"
  type  = "String"
  value = aws_db_instance.main.db_name

  tags = {
    Name = "RDS-DBName"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = var.db_subnet_group_name
  subnet_ids = var.db_subnet_ids

  tags = {
    Name = var.db_subnet_group_name
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier              = var.identifier
  engine                  = var.engine
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  storage_type            = "gp3"
  storage_encrypted       = true
  
  db_name  = "appdb"
  username = "postgres"
  password = random_password.rds_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]

  multi_az               = var.multi_az
  publicly_accessible    = false
  
  # Backup Configuration
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  copy_tags_to_snapshot  = true
  
  maintenance_window           = var.maintenance_window
  auto_minor_version_upgrade   = true
  
  # Deletion Protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : var.final_snapshot_identifier
  
  # Enable monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval             = 0
  
  # Cost optimization
  deletion_protection = false

  tags = {
    Name = var.identifier
  }

  depends_on = [aws_db_subnet_group.main]
}

# IAM Role for RDS monitoring (disabled for Free Tier)
# resource "aws_iam_role" "rds_monitoring" {
#   name_prefix = "rds-monitoring-"
# }
# resource "aws_iam_role_policy_attachment" "rds_monitoring" {
#   role       = aws_iam_role.rds_monitoring.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
# }

# CloudWatch Alarms for RDS
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.identifier}-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when RDS CPU is high"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.identifier}-low-storage"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2147483648" # 2 GB in bytes
  alarm_description   = "Alert when RDS storage is low"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.identifier}-high-connections"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Alert when RDS connections are high"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}
