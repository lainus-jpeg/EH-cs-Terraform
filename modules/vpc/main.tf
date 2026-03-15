resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.vpc_name
  }
}

# Internet Gateway (if enabled)
resource "aws_internet_gateway" "main" {
  count = var.enable_internet_gateway ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = var.public_subnet_name != "" ? "${var.public_subnet_name}-${count.index + 1}" : "${var.vpc_name}-public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

# Private App Subnets
resource "aws_subnet" "private_app" {
  count             = length(var.private_app_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = var.private_app_subnet_name != "" ? "${var.private_app_subnet_name}-${count.index + 1}" : "${var.vpc_name}-private-app-subnet-${count.index + 1}"
    Type = "Private-App"
  }
}

# Private DB Subnets
resource "aws_subnet" "private_db" {
  count             = length(var.private_db_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = var.private_db_subnet_name != "" ? "${var.private_db_subnet_name}-${count.index + 1}" : "${var.vpc_name}-private-db-subnet-${count.index + 1}"
    Type = "Private-DB"
  }
}

# Private Subnets (Monitoring)
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = var.private_subnet_name != "" ? "${var.private_subnet_name}-${count.index + 1}" : "${var.vpc_name}-private-subnet-${count.index + 1}"
    Type = "Private-Monitoring"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  count  = var.enable_internet_gateway ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

# Public Route to Internet Gateway
resource "aws_route" "public_igw" {
  count                  = var.enable_internet_gateway ? 1 : 0
  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[0].id
}

# Public Subnet Route Table Association
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = var.enable_internet_gateway ? aws_route_table.public[0].id : ""

  depends_on = [aws_route_table.public]
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.vpc_name}-nat-eip"
  }
}

# NAT Gateway (only in first/AZ1 public subnet for cost savings)
resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[var.nat_gateway_subnet].id

  tags = {
    Name = "${var.vpc_name}-nat-gateway"
  }

  depends_on = [aws_internet_gateway.main]
}

# Private Route Table for App Subnets
resource "aws_route_table" "private_app" {
  count  = var.enable_nat_gateway ? length(var.private_app_subnet_cidrs) : 0
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-private-app-rt-${count.index + 1}"
  }
}

# Private Route to NAT Gateway
resource "aws_route" "private_app_nat" {
  count              = var.enable_nat_gateway ? length(var.private_app_subnet_cidrs) : 0
  route_table_id     = aws_route_table.private_app[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id     = aws_nat_gateway.main[0].id
}

# Private App Subnet Route Table Association
resource "aws_route_table_association" "private_app" {
  count          = length(var.private_app_subnet_cidrs)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id

  depends_on = [aws_route_table.private_app]
}

# Private Route Table for DB Subnets (no internet access)
resource "aws_route_table" "private_db" {
  count  = length(var.private_db_subnet_cidrs) > 0 ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-private-db-rt"
  }
}

# Private DB Subnet Route Table Association
resource "aws_route_table_association" "private_db" {
  count          = length(var.private_db_subnet_cidrs)
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db[0].id

  depends_on = [aws_route_table.private_db]
}

# Private Route Table for Monitoring Subnets (no internet access)
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs) > 0 ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vpc_name}-private-rt"
  }
}

# Private Subnet Route Table Association
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id

  depends_on = [aws_route_table.private]
}

# DB Subnet Group (for RDS)
resource "aws_db_subnet_group" "main" {
  count              = length(var.private_db_subnet_cidrs) > 0 ? 1 : 0
  name               = "${var.vpc_name}-db-subnet-group"
  subnet_ids         = aws_subnet.private_db[*].id
  
  tags = {
    Name = "${var.vpc_name}-db-subnet-group"
  }
}
