# ============================================
# Terraform Configuration
# ============================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# ============================================
# AWS Provider Configuration
# ============================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "Terraform"
        CreatedAt   = timestamp()
      },
      var.tags
    )
  }
}

# ============================================
# Data Sources
# ============================================

# Get current AWS account information
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

# Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
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

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Get latest Red Hat CoreOS AMI for OpenShift
data "aws_ami" "rhcos" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat

  filter {
    name   = "name"
    values = ["RHCOS-${var.openshift_version}*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ============================================
# Local Variables
# ============================================

locals {
  # Account and region information
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Availability zones
  azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)

  # Common naming prefix
  name_prefix = "${var.project_name}-${var.environment}"

  # AMI IDs
  vm_ami_id        = var.vm_ami_id != "" ? var.vm_ami_id : data.aws_ami.amazon_linux_2023.id
  openshift_ami_id = data.aws_ami.rhcos.id

  # VPC CIDR calculations
  vm_vpc_cidr_prefix        = split("/", var.vm_vpc_cidr)[0]
  openshift_vpc_cidr_prefix = split("/", var.openshift_vpc_cidr)[0]

  # Subnet CIDR blocks for VM VPC
  vm_private_subnet_cidrs = [
    cidrsubnet(var.vm_vpc_cidr, 4, 0),
    cidrsubnet(var.vm_vpc_cidr, 4, 1),
    cidrsubnet(var.vm_vpc_cidr, 4, 2),
  ]

  vm_public_subnet_cidrs = [
    cidrsubnet(var.vm_vpc_cidr, 4, 8),
    cidrsubnet(var.vm_vpc_cidr, 4, 9),
    cidrsubnet(var.vm_vpc_cidr, 4, 10),
  ]

  # Subnet CIDR blocks for OpenShift VPC
  openshift_private_subnet_cidrs = [
    cidrsubnet(var.openshift_vpc_cidr, 4, 0),
    cidrsubnet(var.openshift_vpc_cidr, 4, 1),
    cidrsubnet(var.openshift_vpc_cidr, 4, 2),
  ]

  openshift_public_subnet_cidrs = [
    cidrsubnet(var.openshift_vpc_cidr, 4, 8),
    cidrsubnet(var.openshift_vpc_cidr, 4, 9),
    cidrsubnet(var.openshift_vpc_cidr, 4, 10),
  ]

  # ALB access logs bucket name
  alb_logs_bucket = var.alb_access_logs_bucket != "" ? var.alb_access_logs_bucket : "${local.name_prefix}-alb-logs-${local.account_id}"

  # Common tags
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )

  # VM tags
  vm_resource_tags = merge(
    local.common_tags,
    {
      Component = "VM"
      VPC       = "VM-VPC"
    },
    var.vm_tags
  )

  # OpenShift tags
  openshift_resource_tags = merge(
    local.common_tags,
    {
      Component = "OpenShift"
      VPC       = "OpenShift-VPC"
      Cluster   = var.openshift_cluster_name
    },
    var.openshift_tags
  )

  # OpenShift cluster domain
  openshift_cluster_domain = "${var.openshift_cluster_name}.${var.openshift_base_domain}"

  # SSH key name
  ssh_key_name = "${local.name_prefix}-key"

  # Security group names
  vm_sg_name        = "${local.name_prefix}-vm-sg"
  openshift_sg_name = "${local.name_prefix}-openshift-sg"
  alb_sg_name       = "${local.name_prefix}-alb-sg"
  bastion_sg_name   = "${local.name_prefix}-bastion-sg"

  # IAM role names
  vm_role_name        = "${local.name_prefix}-vm-role"
  openshift_role_name = "${local.name_prefix}-openshift-role"

  # Instance profile names
  vm_instance_profile_name        = "${local.name_prefix}-vm-profile"
  openshift_instance_profile_name = "${local.name_prefix}-openshift-profile"

  # Load balancer names
  alb_name            = "${local.name_prefix}-alb"
  vm_target_group     = "${local.name_prefix}-vm-tg"
  openshift_target_group = "${local.name_prefix}-openshift-tg"

  # CloudWatch log group names
  vm_log_group        = "/aws/ec2/${local.name_prefix}/vm"
  openshift_log_group = "/aws/ec2/${local.name_prefix}/openshift"
  vpc_flow_log_group  = "/aws/vpc/${local.name_prefix}/flow-logs"

  # Backup configuration
  backup_vault_name = "${local.name_prefix}-backup-vault"
  backup_plan_name  = "${local.name_prefix}-backup-plan"

  # ODF configuration
  odf_device_count = ceil(var.odf_storage_size / var.odf_device_size)
  odf_devices_per_worker = ceil(local.odf_device_count / var.openshift_worker_count)
}

# ============================================
# Outputs for Local Variables (for debugging)
# ============================================

output "debug_local_variables" {
  description = "Local variables for debugging"
  value = {
    account_id               = local.account_id
    region                   = local.region
    availability_zones       = local.azs
    name_prefix              = local.name_prefix
    vm_ami_id                = local.vm_ami_id
    openshift_ami_id         = local.openshift_ami_id
    vm_private_subnet_cidrs  = local.vm_private_subnet_cidrs
    vm_public_subnet_cidrs   = local.vm_public_subnet_cidrs
    openshift_private_subnet_cidrs = local.openshift_private_subnet_cidrs
    openshift_public_subnet_cidrs  = local.openshift_public_subnet_cidrs
    openshift_cluster_domain = local.openshift_cluster_domain
    odf_device_count         = local.odf_device_count
    odf_devices_per_worker   = local.odf_devices_per_worker
  }
}