terraform {
  required_version = ">= 1.5.0"
}

# ============================================
# Networking Module - Main Configuration
# ============================================

# This module creates VPC, subnets, NAT gateways, and security groups

# ============================================
# VPC
# ============================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  instance_tenancy     = "default"

  tags = merge(
    var.tags,
    {
      Name = var.vpc_name
    }
  )
}

# ============================================
# Internet Gateway
# ============================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-igw"
    }
  )
}

# ============================================
# Public Subnets
# ============================================

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-public-${var.availability_zones[count.index]}"
      Type = "Public"
      Tier = "Public"
    }
  )
}

# ============================================
# Private Subnets
# ============================================

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-private-${var.availability_zones[count.index]}"
      Type = "Private"
      Tier = "Private"
    }
  )
}

# ============================================
# Elastic IPs for NAT Gateways
# ============================================

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.nat_gateway_per_az ? length(var.availability_zones) : 1) : 0

  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-nat-eip-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ============================================
# NAT Gateways
# ============================================

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.nat_gateway_per_az ? length(var.availability_zones) : 1) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.tags,
    {
      Name = var.nat_gateway_per_az ? "${var.vpc_name}-nat-${var.availability_zones[count.index]}" : "${var.vpc_name}-nat-shared"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ============================================
# Public Route Table
# ============================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-public-rt"
      Type = "Public"
    }
  )
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ============================================
# Private Route Tables
# ============================================

resource "aws_route_table" "private" {
  count = var.nat_gateway_per_az ? length(var.availability_zones) : 1

  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = var.nat_gateway_per_az ? "${var.vpc_name}-private-rt-${var.availability_zones[count.index]}" : "${var.vpc_name}-private-rt"
      Type = "Private"
    }
  )
}

resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? (var.nat_gateway_per_az ? length(var.availability_zones) : 1) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.nat_gateway_per_az ? aws_route_table.private[count.index].id : aws_route_table.private[0].id
}

# ============================================
# VPC Flow Logs
# ============================================

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name              = var.flow_log_group_name
  retention_in_days = 7

  tags = merge(
    var.tags,
    {
      Name = var.flow_log_group_name
    }
  )
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name = "${var.vpc_name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name = "${var.vpc_name}-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-flow-logs"
    }
  )
}

# ============================================
# Security Group
# ============================================

resource "aws_security_group" "main" {
  name        = var.security_group_name
  description = "Security group for ${var.vpc_name}"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = var.security_group_name
    }
  )
}

# Allow HTTPS from specified CIDR blocks
resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each = toset(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.main.id
  description       = "Allow HTTPS inbound from ${each.value}"

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = each.value

  tags = merge(
    var.tags,
    {
      Name = "allow-https-${replace(each.value, "/", "-")}"
    }
  )
}

# Allow HTTP from specified CIDR blocks
resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = toset(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.main.id
  description       = "Allow HTTP inbound from ${each.value}"

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = each.value

  tags = merge(
    var.tags,
    {
      Name = "allow-http-${replace(each.value, "/", "-")}"
    }
  )
}

# Allow all traffic within VPC
resource "aws_vpc_security_group_ingress_rule" "vpc_internal" {
  security_group_id = aws_security_group.main.id
  description       = "Allow all traffic within VPC"

  ip_protocol = "-1"
  cidr_ipv4   = var.vpc_cidr

  tags = merge(
    var.tags,
    {
      Name = "allow-vpc-internal"
    }
  )
}

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.main.id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = merge(
    var.tags,
    {
      Name = "allow-all-outbound"
    }
  )
}

# ============================================
# Bastion Host (Optional)
# ============================================

resource "aws_security_group" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name        = "${var.vpc_name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-bastion-sg"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  count = var.enable_bastion ? length(var.allowed_ssh_cidr_blocks) : 0

  security_group_id = aws_security_group.bastion[0].id
  description       = "Allow SSH from specified CIDR blocks"

  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
  cidr_ipv4   = var.allowed_ssh_cidr_blocks[count.index]

  tags = merge(
    var.tags,
    {
      Name = "allow-ssh-${count.index}"
    }
  )
}

resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  count = var.enable_bastion ? 1 : 0

  security_group_id = aws_security_group.bastion[0].id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = merge(
    var.tags,
    {
      Name = "allow-all-outbound"
    }
  )
}

data "aws_ami" "amazon_linux_2023" {
  count = var.enable_bastion ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "bastion" {
  count = var.enable_bastion ? 1 : 0

  ami           = data.aws_ami.amazon_linux_2023[0].id
  instance_type = var.bastion_instance_type
  key_name      = var.bastion_key_name
  subnet_id     = aws_subnet.public[0].id

  vpc_security_group_ids = [aws_security_group.bastion[0].id]

  associate_public_ip_address = true

  tags = merge(
    var.tags,
    {
      Name = "${var.vpc_name}-bastion"
      Role = "Bastion"
    }
  )
}