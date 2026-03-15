# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.apps_vpc_id

  ingress {
    from_port   = var.alb_port
    to_port     = var.alb_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "alb-sg"
  }
}

# App Instances Security Group
resource "aws_security_group" "app" {
  name_prefix = "app-"
  description = "Security group for application instances"
  vpc_id      = var.apps_vpc_id

  # Allow traffic from ALB on port 80
  ingress {
    from_port       = var.alb_port
    to_port         = var.alb_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow HTTP from ALB"
  }

  # Allow API traffic from ALB on port 3000
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow API traffic from ALB"
  }

  # Allow SSH from within VPC (for management)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.apps_vpc_cidr]
    description = "Allow SSH from VPC"
  }

  # Allow Node Exporter metrics from Monitoring VPC (monitoring)
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.monitoring_vpc_cidr]
    description = "Allow Prometheus Node Exporter from Monitoring VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "app-sg"
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name_prefix = "rds-"
  description = "Security group for RDS database"
  vpc_id      = var.apps_vpc_id

  # Allow PostgreSQL from app instances
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    description     = "Allow PostgreSQL from app instances"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "rds-sg"
  }
}

# Monitoring VPC Security Group
resource "aws_security_group" "monitoring" {
  name_prefix = "monitoring-"
  description = "Security group for Monitoring VPC"
  vpc_id      = var.monitoring_vpc_id

  # Allow traffic from Apps VPC
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.apps_vpc_cidr]
    description = "Allow all TCP from Apps VPC"
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [var.apps_vpc_cidr]
    description = "Allow all UDP from Apps VPC"
  }

  # Allow Prometheus port 9090 from Monitoring VPC (for Grafana to query Prometheus)
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.monitoring_vpc_cidr]
    description = "Allow Prometheus from Monitoring VPC"
  }

  # Allow Grafana port 3000 from internet
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Grafana from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "monitoring-sg"
  }
}
