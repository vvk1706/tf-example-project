# ============================================
# Load Balancer Module Variables
# ============================================

variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
}

variable "internal" {
  description = "Whether the load balancer is internal"
  type        = bool
}

variable "load_balancer_type" {
  description = "Type of load balancer"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for ALB security group"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ALB"
  type        = list(string)
}

variable "security_group_name" {
  description = "Name of the ALB security group"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access ALB"
  type        = list(string)
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
}

variable "enable_http2" {
  description = "Enable HTTP/2 for ALB"
  type        = bool
}

variable "idle_timeout" {
  description = "ALB idle timeout in seconds"
  type        = number
}

variable "enable_access_logs" {
  description = "Enable ALB access logs"
  type        = bool
}

variable "access_logs_bucket" {
  description = "S3 bucket name for ALB access logs"
  type        = string
}

variable "vm_target_group_name" {
  description = "Name of VM target group"
  type        = string
}

variable "vm_target_ids" {
  description = "List of VM instance IDs"
  type        = list(string)
}

variable "vm_vpc_id" {
  description = "VPC ID for VM target group"
  type        = string
}

variable "openshift_target_group_name" {
  description = "Name of OpenShift target group"
  type        = string
}

variable "openshift_target_ids" {
  description = "List of OpenShift worker instance IDs"
  type        = list(string)
}

variable "openshift_vpc_id" {
  description = "VPC ID for OpenShift target group"
  type        = string
}

variable "ssl_certificate_arn" {
  description = "ARN of SSL certificate"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}