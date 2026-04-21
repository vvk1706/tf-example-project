# ============================================
# Compute Module - EC2 Instances
# ============================================

# ============================================
# IAM Role for EC2 Instances
# ============================================

resource "aws_iam_role" "main" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach SSM policy for Session Manager
resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.enable_session_manager ? 1 : 0

  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch policy
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance Profile
resource "aws_iam_instance_profile" "main" {
  name = var.instance_profile_name
  role = aws_iam_role.main.name

  tags = var.tags
}

# ============================================
# EC2 Instances
# ============================================

resource "aws_instance" "main" {
  count = var.instance_count

  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = aws_iam_instance_profile.main.name

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  monitoring                  = var.enable_detailed_monitoring
  disable_api_termination     = var.enable_termination_protection
  instance_initiated_shutdown_behavior = "stop"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    cloudwatch_log_group = var.cloudwatch_log_group
  }))

  tags = merge(
    var.tags,
    {
      Name  = "${var.name_prefix}-${count.index + 1}"
      Index = count.index + 1
    }
  )
}

# ============================================
# CloudWatch Log Group
# ============================================

resource "aws_cloudwatch_log_group" "main" {
  name              = var.cloudwatch_log_group
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = var.cloudwatch_log_group
    }
  )
}