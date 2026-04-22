# ============================================
# Storage Module Variables
# ============================================

variable "volume_count" {
  description = "Number of EBS volumes to create"
  type        = number
}

variable "volume_size" {
  description = "Size of each EBS volume in GB"
  type        = number
}

variable "volume_type" {
  description = "EBS volume type (gp3, gp2, io1, io2)"
  type        = string
}

variable "iops" {
  description = "IOPS for EBS volumes"
  type        = number
}

variable "throughput" {
  description = "Throughput for EBS volumes in MB/s (gp3 only)"
  type        = number
}

variable "encrypted" {
  description = "Enable encryption for EBS volumes"
  type        = bool
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

variable "instance_ids" {
  description = "List of instance IDs to attach volumes to"
  type        = list(string)
}

variable "device_name" {
  description = "Device name for volume attachment"
  type        = string
}

variable "instance_availability_zones" {
  description = "Availability zone for each target instance, aligned by index with instance_ids"
  type        = list(string)
}

variable "enable_snapshots" {
  description = "Enable automated snapshots"
  type        = bool
}

variable "snapshot_retention_days" {
  description = "Number of days to retain snapshots"
  type        = number
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}