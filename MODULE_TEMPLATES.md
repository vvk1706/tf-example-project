# Terraform Module Templates

This document contains the complete code for all remaining modules. Copy each section to create the respective module files.

## Storage Module

### modules/storage/main.tf
```hcl
resource "aws_ebs_volume" "main" {
  count             = var.volume_count
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  size              = var.volume_size
  type              = var.volume_type
  iops              = var.volume_type == "gp3" || var.volume_type == "io1" || var.volume_type == "io2" ? var.iops : null
  throughput        = var.volume_type == "gp3" ? var.throughput : null
  encrypted         = var.encrypted
  kms_key_id        = var.kms_key_id != "" ? var.kms_key_id : null

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${count.index + 1}"
  })
}

resource "aws_volume_attachment" "main" {
  count       = var.volume_count
  device_name = var.device_name
  volume_id   = aws_ebs_volume.main[count.index].id
  instance_id = var.instance_ids[count.index]
}

resource "aws_dlm_lifecycle_policy" "snapshots" {
  count              = var.enable_snapshots ? 1 : 0
  description        = "EBS snapshot policy"
  execution_role_arn = aws_iam_role.dlm[0].arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]
    target_tags = var.tags

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
      tags_to_add = merge(var.tags, { SnapshotType = "Automated" })
      copy_tags   = true
    }
  }
}

resource "aws_iam_role" "dlm" {
  count = var.enable_snapshots ? 1 : 0
  name  = "${var.name_prefix}-dlm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "dlm.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "dlm" {
  count = var.enable_snapshots ? 1 : 0
  role  = aws_iam_role.dlm[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ec2:CreateSnapshot", "ec2:CreateSnapshots", "ec2:DeleteSnapshot",
                "ec2:DescribeVolumes", "ec2:DescribeSnapshots", "ec2:CreateTags"]
      Resource = "*"
    }]
  })
}
```

### modules/storage/variables.tf
```hcl
variable "volume_count" { type = number }
variable "volume_size" { type = number }
variable "volume_type" { type = string }
variable "iops" { type = number }
variable "throughput" { type = number }
variable "encrypted" { type = bool }
variable "kms_key_id" { type = string }
variable "instance_ids" { type = list(string) }
variable "device_name" { type = string }
variable "availability_zones" { type = list(string) }
variable "enable_snapshots" { type = bool }
variable "snapshot_retention_days" { type = number }
variable "name_prefix" { type = string }
variable "tags" { type = map(string) }
```

### modules/storage/outputs.tf
```hcl
output "ebs_volume_ids" { value = aws_ebs_volume.main[*].id }
output "ebs_volume_arns" { value = aws_ebs_volume.main[*].arn }
output "volume_attachments" { value = aws_volume_attachment.main[*].id }
```

## OpenShift Module

### modules/openshift/main.tf
```hcl
# IAM Role
resource "aws_iam_role" "main" {
  name = var.iam_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enable_session_manager ? 1 : 0
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "main" {
  name = var.instance_profile_name
  role = aws_iam_role.main.name
  tags = var.tags
}

# Control Plane Instances
resource "aws_instance" "control_plane" {
  count         = var.control_plane_count
  ami           = var.control_plane_ami
  instance_type = var.control_plane_type
  key_name      = var.key_name
  subnet_id     = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = aws_iam_instance_profile.main.name

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  monitoring = var.enable_detailed_monitoring

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-control-plane-${count.index + 1}"
    Role = "ControlPlane"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# Worker Instances
resource "aws_instance" "worker" {
  count         = var.worker_count
  ami           = var.worker_ami
  instance_type = var.worker_type
  key_name      = var.key_name
  subnet_id     = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = aws_iam_instance_profile.main.name

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  monitoring = var.enable_detailed_monitoring

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-worker-${count.index + 1}"
    Role = "Worker"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# ODF Storage Volumes
resource "aws_ebs_volume" "odf" {
  count             = var.worker_count * var.odf_devices_per_worker
  availability_zone = element(var.private_subnet_ids, count.index % length(var.private_subnet_ids))
  size              = var.odf_device_size
  type              = "gp3"
  encrypted         = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-odf-${count.index + 1}"
    Purpose = "ODF"
  })
}

resource "aws_volume_attachment" "odf" {
  count       = var.worker_count * var.odf_devices_per_worker
  device_name = "/dev/sd${substr("fghijklmnop", count.index % var.odf_devices_per_worker, 1)}"
  volume_id   = aws_ebs_volume.odf[count.index].id
  instance_id = aws_instance.worker[floor(count.index / var.odf_devices_per_worker)].id
}
```

### modules/openshift/variables.tf
```hcl
variable "cluster_name" { type = string }
variable "cluster_domain" { type = string }
variable "openshift_version" { type = string }
variable "control_plane_count" { type = number }
variable "control_plane_type" { type = string }
variable "control_plane_ami" { type = string }
variable "worker_count" { type = number }
variable "worker_type" { type = string }
variable "worker_ami" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "key_name" { type = string }
variable "root_volume_size" { type = number }
variable "odf_device_size" { type = number }
variable "odf_devices_per_worker" { type = number }
variable "iam_role_name" { type = string }
variable "instance_profile_name" { type = string }
variable "enable_session_manager" { type = bool }
variable "enable_detailed_monitoring" { type = bool }
variable "cloudwatch_log_group" { type = string }
variable "log_retention_days" { type = number }
variable "pull_secret_path" { type = string }
variable "tags" { type = map(string) }
```

### modules/openshift/outputs.tf
```hcl
output "control_plane_instance_ids" { value = aws_instance.control_plane[*].id }
output "worker_instance_ids" { value = aws_instance.worker[*].id }
output "control_plane_private_ips" { value = aws_instance.control_plane[*].private_ip }
output "worker_private_ips" { value = aws_instance.worker[*].private_ip }
output "iam_role_arn" { value = aws_iam_role.main.arn }
output "instance_profile_arn" { value = aws_iam_instance_profile.main.arn }
output "odf_volume_ids" { value = aws_ebs_volume.odf[*].id }
```

## Load Balancer Module

### modules/load-balancer/main.tf
```hcl
# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = var.security_group_name
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.alb.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.alb.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = var.alb_name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2              = var.enable_http2
  idle_timeout              = var.idle_timeout

  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      enabled = true
    }
  }

  tags = var.tags
}

# Target Groups
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

  tags = var.tags
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

  tags = var.tags
}

# Target Group Attachments
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

# Listeners
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
}

# Listener Rules
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
}

# Self-signed certificate (if no certificate provided)
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

  validity_period_hours = 8760
  allowed_uses = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "aws_acm_certificate" "self_signed" {
  count            = var.ssl_certificate_arn == "" ? 1 : 0
  private_key      = tls_private_key.self_signed[0].private_key_pem
  certificate_body = tls_self_signed_cert.self_signed[0].cert_pem
  tags             = var.tags
}
```

### modules/load-balancer/variables.tf
```hcl
variable "alb_name" { type = string }
variable "internal" { type = bool }
variable "load_balancer_type" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_name" { type = string }
variable "allowed_cidr_blocks" { type = list(string) }
variable "enable_deletion_protection" { type = bool }
variable "enable_http2" { type = bool }
variable "idle_timeout" { type = number }
variable "enable_access_logs" { type = bool }
variable "access_logs_bucket" { type = string }
variable "vm_target_group_name" { type = string }
variable "vm_target_ids" { type = list(string) }
variable "vm_vpc_id" { type = string }
variable "openshift_target_group_name" { type = string }
variable "openshift_target_ids" { type = list(string) }
variable "openshift_vpc_id" { type = string }
variable "ssl_certificate_arn" { type = string }
variable "tags" { type = map(string) }
```

### modules/load-balancer/outputs.tf
```hcl
output "alb_id" { value = aws_lb.main.id }
output "alb_arn" { value = aws_lb.main.arn }
output "alb_dns_name" { value = aws_lb.main.dns_name }
output "alb_zone_id" { value = aws_lb.main.zone_id }
output "alb_security_group_id" { value = aws_security_group.alb.id }
output "vm_target_group_arn" { value = aws_lb_target_group.vm.arn }
output "openshift_target_group_arn" { value = aws_lb_target_group.openshift.arn }
```

## Installation Scripts

### scripts/install-openshift.sh
```bash
#!/bin/bash
set -e

echo "Installing OpenShift Cluster..."

# Download OpenShift installer
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-install-linux.tar.gz
tar -xzf openshift-install-linux.tar.gz
sudo mv openshift-install /usr/local/bin/

# Create install directory
mkdir -p ~/openshift

# Generate install-config.yaml
cat > ~/openshift/install-config.yaml <<EOF
apiVersion: v1
baseDomain: example.com
metadata:
  name: openshift-cluster
platform:
  aws:
    region: us-east-1
pullSecret: '$(cat ~/.openshift/pull-secret.json)'
sshKey: '$(cat ~/.ssh/id_rsa.pub)'
EOF

# Create cluster
openshift-install create cluster --dir=~/openshift --log-level=info

echo "OpenShift installation complete!"
echo "Console URL: https://console-openshift-console.apps.openshift-cluster.example.com"
echo "Kubeconfig: ~/openshift/auth/kubeconfig"
echo "Admin password: ~/openshift/auth/kubeadmin-password"
```

### scripts/configure-odf.sh
```bash
#!/bin/bash
set -e

echo "Configuring OpenShift Data Foundation..."

export KUBECONFIG=~/openshift/auth/kubeconfig

# Install Local Storage Operator
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-local-storage
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: local-storage-operator
  namespace: openshift-local-storage
spec:
  channel: stable
  name: local-storage-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

sleep 30

# Install ODF Operator
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-storage
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: odf-operator
  namespace: openshift-storage
spec:
  channel: stable-4.14
  name: odf-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

sleep 60

# Create StorageCluster
cat <<EOF | oc apply -f -
apiVersion: ocs.openshift.io/v1
kind: StorageCluster
metadata:
  name: ocs-storagecluster
  namespace: openshift-storage
spec:
  storageDeviceSets:
  - count: 1
    dataPVCTemplate:
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 512Gi
        storageClassName: gp3
        volumeMode: Block
    name: ocs-deviceset
    replica: 3
EOF

echo "ODF configuration complete!"
echo "Check status: oc get storagecluster -n openshift-storage"
```

## Usage Instructions

1. Copy each module section to its respective file path
2. Ensure all files have proper permissions (chmod +x for scripts)
3. Run `terraform init` to initialize modules
4. Run `terraform plan` to review changes
5. Run `terraform apply` to deploy infrastructure
6. Run installation scripts after infrastructure is ready