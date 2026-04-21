# ============================================
# Storage Module Outputs
# ============================================

output "ebs_volume_ids" {
  description = "IDs of EBS volumes"
  value       = aws_ebs_volume.main[*].id
}

output "ebs_volume_arns" {
  description = "ARNs of EBS volumes"
  value       = aws_ebs_volume.main[*].arn
}

output "volume_attachments" {
  description = "Volume attachment IDs"
  value       = aws_volume_attachment.main[*].id
}

output "snapshot_policy_id" {
  description = "ID of DLM snapshot policy"
  value       = var.enable_snapshots ? aws_dlm_lifecycle_policy.snapshots[0].id : null
}