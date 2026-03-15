# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM Role for EC2 instances
resource "aws_iam_role" "monitoring_role" {
  name_prefix = "monitoring-role-"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "monitoring-role"
  }
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "monitoring_profile" {
  name_prefix = "monitoring-profile-"
  role        = aws_iam_role.monitoring_role.name
}

# Attach SSM policy
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch policy
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Attach EC2 discovery policy for Prometheus
resource "aws_iam_role_policy" "ec2_discovery" {
  name   = "prometheus-ec2-discovery"
  role   = aws_iam_role.monitoring_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      }
    ]
  })
}

# Monitoring Security Group
resource "aws_security_group" "monitoring" {
  name_prefix = "monitoring-"
  description = "Security group for Prometheus and Grafana"
  vpc_id      = var.monitoring_vpc_id

  # Allow Prometheus from anywhere (now public)
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Prometheus from internet"
  }

  # Allow Grafana from anywhere (now public)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Grafana from internet"
  }

  # Allow SSH from VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.monitoring_vpc_cidr]
    description = "Allow SSH from Monitoring VPC"
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

# EC2 Instance for Monitoring (now public)
resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  iam_instance_profile   = aws_iam_instance_profile.monitoring_profile.name
  associate_public_ip_address = true

  # Increase root volume for Prometheus data storage
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data_simple.sh", {
    prometheus_retention = var.prometheus_retention
    apps_vpc_app_sg      = var.apps_vpc_app_sg_id
    aws_region           = var.aws_region
    apps_vpc_id          = var.apps_vpc_id
  }))

  monitoring = true

  tags = {
    Name = "Prometheus-server"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ssm_policy,
    aws_iam_role_policy_attachment.cloudwatch_policy
  ]
}

# Security group rule to allow Prometheus node exporter metrics from Apps VPC
resource "aws_security_group_rule" "allow_node_exporter" {
  type                     = "ingress"
  from_port                = 9100
  to_port                  = 9100
  protocol                 = "tcp"
  source_security_group_id = var.apps_vpc_app_sg_id
  security_group_id        = aws_security_group.monitoring.id
  description              = "Allow Node Exporter metrics from Apps ASGs"
}

# Grafana Instance in same VPC
resource "aws_instance" "grafana" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  iam_instance_profile   = aws_iam_instance_profile.monitoring_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data_grafana.sh", {
    prometheus_ip = aws_instance.monitoring.private_ip
  }))

  monitoring = true

  tags = {
    Name = "Grafana-server"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ssm_policy,
    aws_iam_role_policy_attachment.cloudwatch_policy,
    aws_instance.monitoring
  ]
}
