# ============================================
# Main Terraform Configuration
# ============================================

# This is the main entry point for the Terraform configuration.
# It orchestrates all modules and resources.

# ============================================
# SSH Key Pair
# ============================================

resource "aws_key_pair" "main" {
  key_name   = local.ssh_key_name
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = merge(
    local.common_tags,
    {
      Name = local.ssh_key_name
    }
  )
}

# ============================================
# VM Networking Module
# ============================================

module "vm_networking" {
  source = "./modules/networking"

  # VPC Configuration
  vpc_name = "${local.name_prefix}-vm-vpc"
  vpc_cidr = var.vm_vpc_cidr

  # Subnet Configuration
  availability_zones   = local.azs
  private_subnet_cidrs = local.vm_private_subnet_cidrs
  public_subnet_cidrs  = local.vm_public_subnet_cidrs

  # NAT Gateway Configuration
  enable_nat_gateway = var.enable_nat_gateway
  nat_gateway_per_az = var.nat_gateway_per_az

  # DNS Configuration
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  # VPC Flow Logs
  enable_vpc_flow_logs = var.enable_vpc_flow_logs
  flow_log_group_name  = "${local.vpc_flow_log_group}/vm"

  # Security Group Configuration
  security_group_name = local.vm_sg_name
  allowed_cidr_blocks = var.allowed_https_cidr_blocks

  # Bastion Configuration
  enable_bastion          = var.enable_bastion
  bastion_instance_type   = "t3.micro"
  bastion_key_name        = aws_key_pair.main.key_name
  allowed_ssh_cidr_blocks = var.allowed_ssh_cidr_blocks

  # Tags
  tags = local.vm_resource_tags
}

# ============================================
# OpenShift Networking Module
# ============================================

module "openshift_networking" {
  source = "./modules/networking"

  # VPC Configuration
  vpc_name = "${local.name_prefix}-openshift-vpc"
  vpc_cidr = var.openshift_vpc_cidr

  # Subnet Configuration
  availability_zones   = local.azs
  private_subnet_cidrs = local.openshift_private_subnet_cidrs
  public_subnet_cidrs  = local.openshift_public_subnet_cidrs

  # NAT Gateway Configuration
  enable_nat_gateway = var.enable_nat_gateway
  nat_gateway_per_az = var.nat_gateway_per_az

  # DNS Configuration
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  # VPC Flow Logs
  enable_vpc_flow_logs = var.enable_vpc_flow_logs
  flow_log_group_name  = "${local.vpc_flow_log_group}/openshift"

  # Security Group Configuration
  security_group_name = local.openshift_sg_name
  allowed_cidr_blocks = var.allowed_https_cidr_blocks

  # Bastion Configuration (disabled for OpenShift VPC)
  enable_bastion = false

  # Tags
  tags = local.openshift_resource_tags
}

# ============================================
# VPC Peering Connection
# ============================================

resource "null_resource" "cidr_validation" {
  triggers = {
    vm_vpc_cidr        = var.vm_vpc_cidr
    openshift_vpc_cidr = var.openshift_vpc_cidr
  }

  lifecycle {
    precondition {
      condition     = var.vm_vpc_cidr != var.openshift_vpc_cidr
      error_message = "VM VPC CIDR and OpenShift VPC CIDR must be different."
    }
  }
}

resource "aws_vpc_peering_connection" "vm_to_openshift" {
  vpc_id        = module.vm_networking.vpc_id
  peer_vpc_id   = module.openshift_networking.vpc_id
  auto_accept   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-vpc-peering"
      Side = "Requester"
    }
  )

  depends_on = [null_resource.cidr_validation]
}

# Add routes for VPC peering in VM VPC
resource "aws_route" "vm_to_openshift" {
  count = length(module.vm_networking.private_route_table_ids)

  route_table_id            = module.vm_networking.private_route_table_ids[count.index]
  destination_cidr_block    = var.openshift_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.vm_to_openshift.id

  depends_on = [aws_vpc_peering_connection.vm_to_openshift]
}

# Add routes for VPC peering in OpenShift VPC
resource "aws_route" "openshift_to_vm" {
  count = length(module.openshift_networking.private_route_table_ids)

  route_table_id            = module.openshift_networking.private_route_table_ids[count.index]
  destination_cidr_block    = var.vm_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.vm_to_openshift.id

  depends_on = [aws_vpc_peering_connection.vm_to_openshift]
}

# ============================================
# VM Compute Module
# ============================================

module "compute" {
  source = "./modules/compute"

  # Instance Configuration
  instance_count = var.vm_count
  instance_type  = var.vm_instance_type
  ami_id         = local.vm_ami_id
  key_name       = aws_key_pair.main.key_name

  # Network Configuration
  subnet_ids         = module.vm_networking.private_subnet_ids
  vpc_id             = module.vm_networking.vpc_id
  security_group_ids = [module.vm_networking.security_group_id]

  # Storage Configuration
  root_volume_size = var.vm_root_volume_size
  root_volume_type = "gp3"

  # IAM Configuration
  iam_role_name          = local.vm_role_name
  instance_profile_name  = local.vm_instance_profile_name
  enable_session_manager = var.enable_session_manager

  # Monitoring Configuration
  enable_detailed_monitoring = var.enable_detailed_monitoring
  cloudwatch_log_group       = local.vm_log_group
  log_retention_days         = var.cloudwatch_log_retention_days

  # Instance Protection
  enable_termination_protection = var.enable_termination_protection

  # Tags
  name_prefix = "${local.name_prefix}-vm"
  tags        = local.vm_resource_tags
}

# ============================================
# VM Storage Module
# ============================================

module "storage" {
  source = "./modules/storage"

  # EBS Volume Configuration
  volume_count = var.vm_count
  volume_size  = var.vm_ebs_volume_size
  volume_type  = var.vm_ebs_volume_type
  iops         = var.vm_ebs_iops
  throughput   = var.vm_ebs_throughput

  # Encryption Configuration
  encrypted  = var.enable_ebs_encryption
  kms_key_id = var.ebs_kms_key_id

  # Attachment Configuration
  instance_ids = module.compute.vm_instance_ids
  device_name  = "/dev/sdf"

  # Availability Zones
  availability_zones = local.azs

  # Snapshot Configuration
  enable_snapshots        = var.enable_ebs_snapshots
  snapshot_retention_days = var.ebs_snapshot_retention_days

  # Tags
  name_prefix = "${local.name_prefix}-vm-data"
  tags        = local.vm_resource_tags
}

# ============================================
# OpenShift Cluster Module
# ============================================

module "openshift" {
  source = "./modules/openshift"

  # Cluster Configuration
  cluster_name      = var.openshift_cluster_name
  cluster_domain    = var.openshift_base_domain
  openshift_version = var.openshift_version

  # Control Plane Configuration
  control_plane_count = var.openshift_control_plane_count
  control_plane_type  = var.openshift_control_plane_instance_type
  control_plane_ami   = local.openshift_ami_id

  # Worker Configuration
  worker_count = var.openshift_worker_count
  worker_type  = var.openshift_worker_instance_type
  worker_ami   = local.openshift_ami_id

  # Network Configuration
  vpc_id             = module.openshift_networking.vpc_id
  private_subnet_ids = module.openshift_networking.private_subnet_ids
  public_subnet_ids  = module.openshift_networking.public_subnet_ids
  availability_zones = local.azs
  security_group_ids = [module.openshift_networking.security_group_id]

  # SSH Configuration
  key_name = aws_key_pair.main.key_name

  # Storage Configuration
  root_volume_size       = var.openshift_root_volume_size
  odf_device_size        = var.odf_device_size
  odf_devices_per_worker = local.odf_devices_per_worker

  # IAM Configuration
  iam_role_name          = local.openshift_role_name
  instance_profile_name  = local.openshift_instance_profile_name
  enable_session_manager = var.enable_session_manager

  # Monitoring Configuration
  enable_detailed_monitoring = var.enable_detailed_monitoring
  cloudwatch_log_group       = local.openshift_log_group
  log_retention_days         = var.cloudwatch_log_retention_days

  # Pull Secret
  pull_secret_path = var.openshift_pull_secret_path

  # Tags
  tags = local.openshift_resource_tags
}

# ============================================
# Load Balancer Module
# ============================================

module "load_balancer" {
  source = "./modules/load-balancer"

  # ALB Configuration
  alb_name           = local.alb_name
  internal           = false
  load_balancer_type = "application"

  # Network Configuration
  vpc_id     = module.vm_networking.vpc_id
  subnet_ids = module.vm_networking.public_subnet_ids

  # Security Configuration
  security_group_name = local.alb_sg_name
  allowed_cidr_blocks = var.allowed_https_cidr_blocks

  # ALB Settings
  enable_deletion_protection = var.alb_enable_deletion_protection
  enable_http2               = var.alb_enable_http2
  idle_timeout               = var.alb_idle_timeout

  # Access Logs
  enable_access_logs = var.alb_enable_access_logs
  access_logs_bucket = local.alb_logs_bucket

  # Target Groups
  vm_target_group_name = local.vm_target_group
  vm_target_ids        = module.compute.vm_instance_ids
  vm_vpc_id            = module.vm_networking.vpc_id

  openshift_target_group_name = local.openshift_target_group
  openshift_target_ids        = module.openshift.worker_instance_ids
  openshift_vpc_id            = module.openshift_networking.vpc_id

  # SSL Certificate
  ssl_certificate_arn = var.ssl_certificate_arn

  # Tags
  tags = local.common_tags
}

# ============================================
# CloudWatch Log Groups
# ============================================

resource "aws_cloudwatch_log_group" "vm" {
  name              = local.vm_log_group
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(
    local.vm_resource_tags,
    {
      Name = local.vm_log_group
    }
  )
}

resource "aws_cloudwatch_log_group" "openshift" {
  name              = local.openshift_log_group
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(
    local.openshift_resource_tags,
    {
      Name = local.openshift_log_group
    }
  )
}

# ============================================
# S3 Bucket for ALB Logs (if enabled)
# ============================================

data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket" "alb_logs" {
  count = var.alb_enable_access_logs ? 1 : 0

  bucket = local.alb_logs_bucket

  tags = merge(
    local.common_tags,
    {
      Name = local.alb_logs_bucket
    }
  )
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  count = var.alb_enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  count = var.alb_enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  count = var.alb_enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "alb_logs" {
  count  = var.alb_enable_access_logs ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs[0].arn}/*"
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs[0].arn
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  count = var.alb_enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ============================================
# AWS Backup Configuration (if enabled)
# ============================================

resource "aws_backup_vault" "main" {
  count = var.enable_ebs_snapshots ? 1 : 0

  name = local.backup_vault_name

  tags = merge(
    local.common_tags,
    {
      Name = local.backup_vault_name
    }
  )
}

resource "aws_backup_plan" "main" {
  count = var.enable_ebs_snapshots ? 1 : 0

  name = local.backup_plan_name

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.main[0].name
    schedule          = "cron(0 2 * * ? *)" # Daily at 2 AM UTC

    lifecycle {
      delete_after = var.ebs_snapshot_retention_days
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.backup_plan_name
    }
  )
}

resource "aws_backup_selection" "vm_volumes" {
  count = var.enable_ebs_snapshots ? 1 : 0

  name         = "${local.name_prefix}-vm-volumes"
  plan_id      = aws_backup_plan.main[0].id
  iam_role_arn = aws_iam_role.backup[0].arn

  resources = module.storage.ebs_volume_arns
}

resource "aws_iam_role" "backup" {
  count = var.enable_ebs_snapshots ? 1 : 0

  name = "${local.name_prefix}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  count = var.enable_ebs_snapshots ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}