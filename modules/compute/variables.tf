# ============================================
# Compute Module Variables
# ============================================

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for instances"
  type        = string
}

variable "key_name" {
  description = "SSH key name"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
}

variable "root_volume_type" {
  description = "Type of root volume"
  type        = string
  default     = "gp3"
}

variable "iam_role_name" {
  description = "Name of IAM role"
  type        = string
}

variable "instance_profile_name" {
  description = "Name of instance profile"
  type        = string
}

variable "enable_session_manager" {
  description = "Enable AWS Systems Manager Session Manager"
  type        = bool
  default     = true
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "enable_termination_protection" {
  description = "Enable termination protection"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  type        = string
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
  default     = 30
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}