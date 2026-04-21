# ============================================
# VPC Outputs
# ============================================

output "vm_vpc_id" {
  description = "ID of the VM VPC"
  value       = module.vm_networking.vpc_id
}

output "vm_vpc_cidr" {
  description = "CIDR block of the VM VPC"
  value       = module.vm_networking.vpc_cidr
}

output "vm_private_subnet_ids" {
  description = "IDs of VM private subnets"
  value       = module.vm_networking.private_subnet_ids
}

output "vm_public_subnet_ids" {
  description = "IDs of VM public subnets"
  value       = module.vm_networking.public_subnet_ids
}

output "openshift_vpc_id" {
  description = "ID of the OpenShift VPC"
  value       = module.openshift_networking.vpc_id
}

output "openshift_vpc_cidr" {
  description = "CIDR block of the OpenShift VPC"
  value       = module.openshift_networking.vpc_cidr
}

output "openshift_private_subnet_ids" {
  description = "IDs of OpenShift private subnets"
  value       = module.openshift_networking.private_subnet_ids
}

output "openshift_public_subnet_ids" {
  description = "IDs of OpenShift public subnets"
  value       = module.openshift_networking.public_subnet_ids
}

# ============================================
# VM Instance Outputs
# ============================================

output "vm_instance_ids" {
  description = "IDs of VM instances"
  value       = module.compute.vm_instance_ids
}

output "vm_private_ips" {
  description = "Private IP addresses of VM instances"
  value       = module.compute.vm_private_ips
}

output "vm_instance_names" {
  description = "Names of VM instances"
  value       = module.compute.vm_instance_names
}

# ============================================
# EBS Volume Outputs
# ============================================

output "vm_ebs_volume_ids" {
  description = "IDs of EBS volumes attached to VMs"
  value       = module.storage.ebs_volume_ids
}

output "vm_ebs_volume_attachments" {
  description = "EBS volume attachment information"
  value       = module.storage.volume_attachments
}

# ============================================
# OpenShift Cluster Outputs
# ============================================

output "openshift_control_plane_ids" {
  description = "IDs of OpenShift control plane instances"
  value       = module.openshift.control_plane_instance_ids
}

output "openshift_worker_ids" {
  description = "IDs of OpenShift worker instances"
  value       = module.openshift.worker_instance_ids
}

output "openshift_control_plane_ips" {
  description = "Private IP addresses of OpenShift control plane nodes"
  value       = module.openshift.control_plane_private_ips
}

output "openshift_worker_ips" {
  description = "Private IP addresses of OpenShift worker nodes"
  value       = module.openshift.worker_private_ips
}

output "openshift_cluster_name" {
  description = "Name of the OpenShift cluster"
  value       = var.openshift_cluster_name
}

output "openshift_cluster_domain" {
  description = "Domain name of the OpenShift cluster"
  value       = local.openshift_cluster_domain
}

output "openshift_api_url" {
  description = "OpenShift API server URL"
  value       = "https://api.${local.openshift_cluster_domain}:6443"
}

output "openshift_console_url" {
  description = "OpenShift web console URL"
  value       = "https://console-openshift-console.apps.${local.openshift_cluster_domain}"
}

# ============================================
# Load Balancer Outputs
# ============================================

output "alb_id" {
  description = "ID of the Application Load Balancer"
  value       = module.load_balancer.alb_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.load_balancer.alb_arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.load_balancer.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.load_balancer.alb_zone_id
}

output "alb_url" {
  description = "URL to access the Application Load Balancer"
  value       = "https://${module.load_balancer.alb_dns_name}"
}

output "vm_target_group_arn" {
  description = "ARN of the VM target group"
  value       = module.load_balancer.vm_target_group_arn
}

output "openshift_target_group_arn" {
  description = "ARN of the OpenShift target group"
  value       = module.load_balancer.openshift_target_group_arn
}

# ============================================
# Security Group Outputs
# ============================================

output "vm_security_group_id" {
  description = "ID of the VM security group"
  value       = module.vm_networking.security_group_id
}

output "openshift_security_group_id" {
  description = "ID of the OpenShift security group"
  value       = module.openshift_networking.security_group_id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.load_balancer.alb_security_group_id
}

# ============================================
# IAM Role Outputs
# ============================================

output "vm_iam_role_arn" {
  description = "ARN of the VM IAM role"
  value       = module.compute.iam_role_arn
}

output "vm_instance_profile_arn" {
  description = "ARN of the VM instance profile"
  value       = module.compute.instance_profile_arn
}

output "openshift_iam_role_arn" {
  description = "ARN of the OpenShift IAM role"
  value       = module.openshift.iam_role_arn
}

output "openshift_instance_profile_arn" {
  description = "ARN of the OpenShift instance profile"
  value       = module.openshift.instance_profile_arn
}

# ============================================
# Storage Outputs
# ============================================

output "odf_storage_configuration" {
  description = "ODF storage configuration details"
  value = {
    total_capacity_gb    = var.odf_storage_size
    device_size_gb       = var.odf_device_size
    devices_per_worker   = local.odf_devices_per_worker
    total_device_count   = local.odf_device_count
    worker_count         = var.openshift_worker_count
  }
}

# ============================================
# SSH and Access Outputs
# ============================================

output "ssh_key_name" {
  description = "Name of the SSH key pair"
  value       = local.ssh_key_name
}

output "bastion_public_ip" {
  description = "Public IP of bastion host (if enabled)"
  value       = var.enable_bastion ? module.vm_networking.bastion_public_ip : null
}

# ============================================
# Connection Information
# ============================================

output "connection_info" {
  description = "Connection information for accessing resources"
  value = {
    alb_url = "https://${module.load_balancer.alb_dns_name}"
    vm_access = {
      method = var.enable_session_manager ? "AWS Systems Manager Session Manager" : "SSH via Bastion"
      command = var.enable_session_manager ? "aws ssm start-session --target <instance-id>" : "ssh -i ~/.ssh/${local.ssh_key_name} ec2-user@<vm-private-ip>"
    }
    openshift_console = "https://console-openshift-console.apps.${local.openshift_cluster_domain}"
    openshift_api = "https://api.${local.openshift_cluster_domain}:6443"
  }
}

# ============================================
# Cost Estimation Outputs
# ============================================

output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (USD)"
  value = {
    vm_instances = {
      count = var.vm_count
      type = var.vm_instance_type
      estimated_cost = "$${var.vm_count * 400}"
    }
    openshift_control_plane = {
      count = var.openshift_control_plane_count
      type = var.openshift_control_plane_instance_type
      estimated_cost = "$${var.openshift_control_plane_count * 150}"
    }
    openshift_workers = {
      count = var.openshift_worker_count
      type = var.openshift_worker_instance_type
      estimated_cost = "$${var.openshift_worker_count * 600}"
    }
    ebs_storage = {
      vm_volumes = "${var.vm_count * var.vm_ebs_volume_size}GB"
      odf_storage = "${var.odf_storage_size}GB"
      estimated_cost = "$${(var.vm_count * var.vm_ebs_volume_size + var.odf_storage_size) * 0.10}"
    }
    load_balancer = {
      estimated_cost = "$20"
    }
    nat_gateway = {
      count = var.nat_gateway_per_az ? 6 : 2
      estimated_cost = "$${(var.nat_gateway_per_az ? 6 : 2) * 45}"
    }
    total_estimated = "$${var.vm_count * 400 + var.openshift_control_plane_count * 150 + var.openshift_worker_count * 600 + (var.vm_count * var.vm_ebs_volume_size + var.odf_storage_size) * 0.10 + 20 + (var.nat_gateway_per_az ? 6 : 2) * 45}"
    note = "Estimates are approximate and may vary based on region, usage, and AWS pricing changes"
  }
}

# ============================================
# Deployment Status Outputs
# ============================================

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    region = var.aws_region
    project = var.project_name
    environment = var.environment
    vpcs = {
      vm_vpc = module.vm_networking.vpc_id
      openshift_vpc = module.openshift_networking.vpc_id
    }
    compute = {
      vm_instances = var.vm_count
      openshift_control_plane = var.openshift_control_plane_count
      openshift_workers = var.openshift_worker_count
      total_instances = var.vm_count + var.openshift_control_plane_count + var.openshift_worker_count
    }
    storage = {
      vm_ebs_volumes = "${var.vm_count * var.vm_ebs_volume_size}GB"
      odf_storage = "${var.odf_storage_size}GB"
      total_storage = "${var.vm_count * var.vm_ebs_volume_size + var.odf_storage_size}GB"
    }
    networking = {
      load_balancer = module.load_balancer.alb_dns_name
      nat_gateways = var.nat_gateway_per_az ? 6 : 2
    }
  }
}

# ============================================
# Next Steps Output
# ============================================

output "next_steps" {
  description = "Next steps after infrastructure deployment"
  value = <<-EOT
    Infrastructure deployment complete! Follow these steps:
    
    1. Verify VM instances:
       aws ec2 describe-instances --instance-ids ${join(" ", module.compute.vm_instance_ids)}
    
    2. Connect to VMs via Session Manager:
       aws ssm start-session --target <instance-id>
    
    3. Format and mount EBS volumes on each VM:
       sudo mkfs -t ext4 /dev/xvdf
       sudo mkdir /data
       sudo mount /dev/xvdf /data
       echo '/dev/xvdf /data ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
    
    4. Install OpenShift cluster:
       cd scripts
       ./install-openshift.sh
    
    5. Configure ODF storage:
       ./configure-odf.sh
    
    6. Access OpenShift console:
       https://console-openshift-console.apps.${local.openshift_cluster_domain}
    
    7. Access via Load Balancer:
       https://${module.load_balancer.alb_dns_name}
    
    For detailed instructions, see DEPLOYMENT.md
  EOT
}

# ============================================
# Sensitive Outputs (marked as sensitive)
# ============================================

output "openshift_admin_password" {
  description = "OpenShift kubeadmin password (will be generated during installation)"
  value       = "Check ~/openshift/auth/kubeadmin-password after installation"
  sensitive   = false
}

output "kubeconfig_path" {
  description = "Path to OpenShift kubeconfig file"
  value       = "~/openshift/auth/kubeconfig"
}