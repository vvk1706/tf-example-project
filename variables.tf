# ============================================
# AWS Configuration Variables
# ============================================

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "infrastructure"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, production)"
  type        = string
  default     = "production"
}

# ============================================
# VM Configuration Variables
# ============================================

variable "vm_count" {
  description = "Number of VM instances to create"
  type        = number
  default     = 3
  validation {
    condition     = var.vm_count > 0 && var.vm_count <= 10
    error_message = "VM count must be between 1 and 10"
  }
}

variable "vm_instance_type" {
  description = "EC2 instance type for VMs (8 vCPU x 64GB RAM = m5.2xlarge)"
  type        = string
  default     = "m5.2xlarge"
}

variable "vm_ami_id" {
  description = "AMI ID for VM instances (leave empty for latest Amazon Linux 2023)"
  type        = string
  default     = ""
}

variable "vm_ebs_volume_size" {
  description = "Size of EBS volume for each VM in GB"
  type        = number
  default     = 100
  validation {
    condition     = var.vm_ebs_volume_size >= 100 && var.vm_ebs_volume_size <= 1000
    error_message = "EBS volume size must be between 100 and 1000 GB"
  }
}

variable "vm_ebs_volume_type" {
  description = "EBS volume type (gp3, gp2, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "vm_ebs_iops" {
  description = "IOPS for EBS volumes (only for gp3, io1, io2)"
  type        = number
  default     = 3000
}

variable "vm_ebs_throughput" {
  description = "Throughput for EBS volumes in MB/s (only for gp3)"
  type        = number
  default     = 125
}

# ============================================
# OpenShift Configuration Variables
# ============================================

variable "openshift_version" {
  description = "OpenShift version to install"
  type        = string
  default     = "4.14"
}

variable "openshift_cluster_name" {
  description = "OpenShift cluster name"
  type        = string
  default     = "openshift-cluster"
}

variable "openshift_base_domain" {
  description = "Base domain for OpenShift cluster"
  type        = string
  default     = "example.com"
}

variable "openshift_worker_count" {
  description = "Number of OpenShift worker nodes"
  type        = number
  default     = 7
  validation {
    condition     = var.openshift_worker_count >= 3 && var.openshift_worker_count <= 20
    error_message = "Worker count must be between 3 and 20"
  }
}

variable "openshift_worker_instance_type" {
  description = "EC2 instance type for OpenShift workers (16 vCPU x 96GB RAM = m5.4xlarge)"
  type        = string
  default     = "m5.4xlarge"
}

variable "openshift_control_plane_count" {
  description = "Number of OpenShift control plane nodes"
  type        = number
  default     = 3
  validation {
    condition     = var.openshift_control_plane_count == 3
    error_message = "Control plane count must be 3 for HA"
  }
}

variable "openshift_control_plane_instance_type" {
  description = "EC2 instance type for OpenShift control plane (4 vCPU x 16GB RAM = m5.xlarge)"
  type        = string
  default     = "m5.xlarge"
}

variable "openshift_pull_secret_path" {
  description = "Path to OpenShift pull secret JSON file"
  type        = string
  default     = "~/.openshift/pull-secret.json"
}

# ============================================
# Storage Configuration Variables
# ============================================

variable "odf_storage_size" {
  description = "Total ODF storage capacity in GB"
  type        = number
  default     = 1024
  validation {
    condition     = var.odf_storage_size >= 1024
    error_message = "ODF storage size must be at least 1024 GB (1TB)"
  }
}

variable "odf_device_size" {
  description = "Size of each ODF device in GB (will be created on each worker)"
  type        = number
  default     = 512
}

variable "enable_ebs_encryption" {
  description = "Enable encryption for EBS volumes"
  type        = bool
  default     = true
}

variable "ebs_kms_key_id" {
  description = "KMS key ID for EBS encryption (leave empty for AWS managed key)"
  type        = string
  default     = ""
}

# ============================================
# Network Configuration Variables
# ============================================

variable "vm_vpc_cidr" {
  description = "CIDR block for VM VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vm_vpc_cidr, 0))
    error_message = "Must be a valid CIDR block"
  }
}

variable "openshift_vpc_cidr" {
  description = "CIDR block for OpenShift VPC"
  type        = string
  default     = "10.1.0.0/16"
  validation {
    condition     = can(cidrhost(var.openshift_vpc_cidr, 0))
    error_message = "Must be a valid CIDR block"
  }
}

variable "availability_zones" {
  description = "List of availability zones to use (leave empty for automatic selection)"
  type        = list(string)
  default     = []
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC flow logs for network monitoring"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet internet access"
  type        = bool
  default     = true
}

variable "nat_gateway_per_az" {
  description = "Create one NAT Gateway per AZ (more expensive but more resilient)"
  type        = bool
  default     = true
}

# ============================================
# Load Balancer Configuration Variables
# ============================================

variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = true
}

variable "alb_enable_http2" {
  description = "Enable HTTP/2 for ALB"
  type        = bool
  default     = true
}

variable "alb_idle_timeout" {
  description = "ALB idle timeout in seconds"
  type        = number
  default     = 60
}

variable "alb_enable_access_logs" {
  description = "Enable ALB access logs to S3"
  type        = bool
  default     = true
}

variable "alb_access_logs_bucket" {
  description = "S3 bucket name for ALB access logs (will be created if doesn't exist)"
  type        = string
  default     = ""
}

variable "ssl_certificate_arn" {
  description = "ARN of SSL certificate for HTTPS listener (leave empty to create self-signed)"
  type        = string
  default     = ""
}

# ============================================
# Security Configuration Variables
# ============================================

variable "ssh_public_key_path" {
  description = "Path to SSH public key for EC2 instances"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to bastion (if enabled)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_https_cidr_blocks" {
  description = "CIDR blocks allowed to access ALB via HTTPS"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_bastion" {
  description = "Enable bastion host for SSH access to private instances"
  type        = bool
  default     = false
}

variable "enable_session_manager" {
  description = "Enable AWS Systems Manager Session Manager for instance access"
  type        = bool
  default     = true
}

# ============================================
# Backup and Monitoring Variables
# ============================================

variable "enable_ebs_snapshots" {
  description = "Enable automated EBS snapshots"
  type        = bool
  default     = true
}

variable "ebs_snapshot_retention_days" {
  description = "Number of days to retain EBS snapshots"
  type        = number
  default     = 7
}

variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

# ============================================
# Tags Variables
# ============================================

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}

variable "vm_tags" {
  description = "Additional tags for VM instances"
  type        = map(string)
  default     = {}
}

variable "openshift_tags" {
  description = "Additional tags for OpenShift resources"
  type        = map(string)
  default     = {}
}

# ============================================
# Advanced Configuration Variables
# ============================================

variable "enable_ipv6" {
  description = "Enable IPv6 for VPCs"
  type        = bool
  default     = false
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPCs"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPCs"
  type        = bool
  default     = true
}

variable "vm_root_volume_size" {
  description = "Size of root volume for VM instances in GB"
  type        = number
  default     = 50
}

variable "openshift_root_volume_size" {
  description = "Size of root volume for OpenShift nodes in GB"
  type        = number
  default     = 120
}

variable "enable_termination_protection" {
  description = "Enable termination protection for EC2 instances"
  type        = bool
  default     = true
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring for EC2 instances"
  type        = bool
  default     = true
}
