# ============================================
# Storage Module - EBS Volumes
# ============================================

resource "aws_ebs_volume" "main" {
  count             = var.volume_count
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  size              = var.volume_size
  type              = var.volume_type
  iops              = var.volume_type == "gp3" || var.volume_type == "io1" || var.volume_type == "io2" ? var.iops : null
  throughput        = var.volume_type == "gp3" ? var.throughput : null
  encrypted         = var.encrypted
  kms_key_id        = var.kms_key_id != "" ? var.kms_key_id : null

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-${count.index + 1}"
    }
  )
}

resource "aws_volume_attachment" "main" {
  count       = var.volume_count
  device_name = var.device_name
  volume_id   = aws_ebs_volume.main[count.index].id
  instance_id = var.instance_ids[count.index]
}

# ============================================
# Data Lifecycle Manager for Snapshots
# ============================================

resource "aws_dlm_lifecycle_policy" "snapshots" {
  count              = var.enable_snapshots ? 1 : 0
  description        = "EBS snapshot policy for ${var.name_prefix}"
  execution_role_arn = aws_iam_role.dlm[0].arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]
    target_tags    = var.tags

    schedule {
      name = "Daily snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["03:00"]
      }

      retain_rule {
        count = var.snapshot_retention_days
      }

      tags_to_add = merge(
        var.tags,
        {
          SnapshotType = "Automated"
        }
      )

      copy_tags = true
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "dlm" {
  count = var.enable_snapshots ? 1 : 0
  name  = "${var.name_prefix}-dlm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dlm.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "dlm" {
  count = var.enable_snapshots ? 1 : 0
  role  = aws_iam_role.dlm[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:DeleteSnapshot",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:CreateTags"
        ]
        Resource = "*"
      }
    ]
  })
}