# ============================================
# Compute Module Outputs
# ============================================

output "vm_instance_ids" {
  description = "IDs of EC2 instances"
  value       = aws_instance.main[*].id
}

output "vm_instance_arns" {
  description = "ARNs of EC2 instances"
  value       = aws_instance.main[*].arn
}

output "vm_private_ips" {
  description = "Private IP addresses of instances"
  value       = aws_instance.main[*].private_ip
}

output "vm_instance_names" {
  description = "Names of instances"
  value       = aws_instance.main[*].tags.Name
}

output "iam_role_arn" {
  description = "ARN of IAM role"
  value       = aws_iam_role.main.arn
}

output "iam_role_name" {
  description = "Name of IAM role"
  value       = aws_iam_role.main.name
}

output "instance_profile_arn" {
  description = "ARN of instance profile"
  value       = aws_iam_instance_profile.main.arn
}

output "instance_profile_name" {
  description = "Name of instance profile"
  value       = aws_iam_instance_profile.main.name
}