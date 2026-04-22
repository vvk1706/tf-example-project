terraform {
  required_version = ">= 1.5.0"
}

# ============================================
# Load Balancer Module - Application Load Balancer
# ============================================

# ============================================
# Security Group for ALB
# ============================================

resource "aws_security_group" "alb" {
  name        = var.security_group_name
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = var.security_group_name
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each = toset(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS inbound from ${each.value}"

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = each.value

  tags = merge(
    var.tags,
    {
      Name = "allow-https-${replace(each.value, "/", "-")}"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = toset(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP inbound from ${each.value}"

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = each.value

  tags = merge(
    var.tags,
    {
      Name = "allow-http-${replace(each.value, "/", "-")}"
    }
  )
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"

  tags = merge(
    var.tags,
    {
      Name = "allow-all-outbound"
    }
  )
}

# ============================================
# Application Load Balancer
# ============================================

resource "aws_lb" "main" {
  name               = var.alb_name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2               = var.enable_http2
  idle_timeout               = var.idle_timeout

  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      enabled = true
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.alb_name
    }
  )
}

# ============================================
# Target Groups
# ============================================

resource "aws_lb_target_group" "vm" {
  name     = var.vm_target_group_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vm_vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name = var.vm_target_group_name
    }
  )
}

resource "aws_lb_target_group" "openshift" {
  name     = var.openshift_target_group_name
  port     = 443
  protocol = "HTTPS"
  vpc_id   = var.openshift_vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/healthz"
    port                = "traffic-port"
    protocol            = "HTTPS"
    timeout             = 5
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name = var.openshift_target_group_name
    }
  )
}

# ============================================
# Target Group Attachments
# ============================================

resource "aws_lb_target_group_attachment" "vm" {
  count            = length(var.vm_target_ids)
  target_group_arn = aws_lb_target_group.vm.arn
  target_id        = var.vm_target_ids[count.index]
  port             = 80
}

resource "aws_lb_target_group_attachment" "openshift" {
  count            = length(var.openshift_target_ids)
  target_group_arn = aws_lb_target_group.openshift.arn
  target_id        = var.openshift_target_ids[count.index]
  port             = 443
}

# ============================================
# Self-Signed Certificate (if no certificate provided)
# ============================================

resource "tls_private_key" "self_signed" {
  count     = var.ssl_certificate_arn == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed" {
  count           = var.ssl_certificate_arn == "" ? 1 : 0
  private_key_pem = tls_private_key.self_signed[0].private_key_pem

  subject {
    common_name  = "*.example.com"
    organization = "Example Organization"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "self_signed" {
  count            = var.ssl_certificate_arn == "" ? 1 : 0
  private_key      = tls_private_key.self_signed[0].private_key_pem
  certificate_body = tls_self_signed_cert.self_signed[0].cert_pem

  tags = merge(
    var.tags,
    {
      Name = "${var.alb_name}-cert"
    }
  )
}

# ============================================
# Listeners
# ============================================

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.ssl_certificate_arn != "" ? var.ssl_certificate_arn : aws_acm_certificate.self_signed[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.openshift.arn
  }

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = var.tags
}

# ============================================
# Listener Rules
# ============================================

resource "aws_lb_listener_rule" "vm" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vm.arn
  }

  condition {
    path_pattern {
      values = ["/vm/*"]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "vm-routing-rule"
    }
  )
}

resource "aws_lb_listener_rule" "openshift_apps" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.openshift.arn
  }

  condition {
    path_pattern {
      values = ["/openshift/*"]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "openshift-routing-rule"
    }
  )
}