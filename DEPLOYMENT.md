# Deployment Guide

This guide provides step-by-step instructions for deploying the AWS infrastructure using Terraform.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Configuration](#configuration)
4. [Deployment Steps](#deployment-steps)
5. [Post-Deployment](#post-deployment)
6. [OpenShift Installation](#openshift-installation)
7. [ODF Storage Configuration](#odf-storage-configuration)
8. [Verification](#verification)
9. [Troubleshooting](#troubleshooting)
10. [Cleanup](#cleanup)

## Prerequisites

### Required Tools

1. **Terraform** (>= 1.5.0)
   ```bash
   # macOS
   brew install terraform
   
   # Linux
   wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
   unzip terraform_1.5.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

2. **AWS CLI** (>= 2.0)
   ```bash
   # macOS
   brew install awscli
   
   # Linux
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   ```

3. **OpenShift CLI (oc)**
   ```bash
   # Download from https://mirror.openshift.com/pub/openshift-v4/clients/ocp/
   wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz
   tar -xzf openshift-client-linux.tar.gz
   sudo mv oc kubectl /usr/local/bin/
   ```

### AWS Account Requirements

- AWS account with administrative access
- AWS credentials configured
- Sufficient service quotas:
  - EC2 instances: At least 10 m5.2xlarge and 7 m5.4xlarge
  - VPCs: At least 2
  - Elastic IPs: At least 6
  - EBS volumes: At least 13 (300GB + OpenShift volumes)

### OpenShift Requirements

- Red Hat account with OpenShift subscription
- Pull secret from https://console.redhat.com/openshift/install/pull-secret
- SSH key pair for cluster access

## Initial Setup

### 1. Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-1)
# Enter your default output format (json)
```

Verify configuration:
```bash
aws sts get-caller-identity
```

### 2. Clone Repository

```bash
git clone <repository-url>
cd aws-infrastructure-terraform
```

### 3. Generate SSH Key Pair

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/aws-infrastructure-key -N ""
```

## Configuration

### 1. Create Terraform Variables File

```bash
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit terraform.tfvars

```hcl
# AWS Configuration
aws_region = "us-east-1"
project_name = "my-infrastructure"
environment = "production"

# VM Configuration
vm_count = 3
vm_instance_type = "m5.2xlarge"
vm_ebs_volume_size = 100

# OpenShift Configuration
openshift_version = "4.14"
openshift_worker_count = 7
openshift_worker_instance_type = "m5.4xlarge"
openshift_control_plane_instance_type = "m5.xlarge"

# Storage Configuration
odf_storage_size = 1024  # 1TB in GB

# Network Configuration
vm_vpc_cidr = "10.0.0.0/16"
openshift_vpc_cidr = "10.1.0.0/16"

# SSH Key
ssh_public_key_path = "~/.ssh/aws-infrastructure-key.pub"

# OpenShift Pull Secret
openshift_pull_secret_path = "~/.openshift/pull-secret.json"

# Tags
tags = {
  Project     = "Infrastructure"
  Environment = "Production"
  ManagedBy   = "Terraform"
}
```

### 3. Download OpenShift Pull Secret

1. Visit https://console.redhat.com/openshift/install/pull-secret
2. Download the pull secret
3. Save it to `~/.openshift/pull-secret.json`

### 4. Configure Backend (Optional but Recommended)

Edit `backend.tf` to use S3 backend for state management:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

Create the S3 bucket and DynamoDB table:

```bash
# Create S3 bucket
aws s3 mb s3://my-terraform-state-bucket --region us-east-1
aws s3api put-bucket-versioning \
  --bucket my-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

## Deployment Steps

### Step 1: Initialize Terraform

```bash
terraform init
```

Expected output:
```
Initializing modules...
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

### Step 2: Validate Configuration

```bash
terraform validate
```

### Step 3: Plan Deployment

```bash
terraform plan -out=tfplan
```

Review the plan carefully. You should see:
- 2 VPCs
- 6 subnets (3 per VPC)
- 3 VM instances
- 10 OpenShift instances (3 control plane + 7 workers)
- 3 EBS volumes
- 1 Application Load Balancer
- Security groups, IAM roles, etc.

### Step 4: Apply Configuration

```bash
terraform apply tfplan
```

This will take approximately 15-20 minutes. Terraform will create:
1. Networking infrastructure (VPCs, subnets, route tables)
2. Security groups and IAM roles
3. EC2 instances for VMs
4. EBS volumes and attachments
5. Load balancer
6. OpenShift infrastructure (instances only)

### Step 5: Save Outputs

```bash
terraform output -json > outputs.json
```

## Post-Deployment

### 1. Verify VM Instances

```bash
# Get VM instance IDs
terraform output vm_instance_ids

# Connect to a VM via Session Manager (no SSH key needed)
aws ssm start-session --target <instance-id>

# Or use SSH through bastion (if configured)
ssh -i ~/.ssh/aws-infrastructure-key ec2-user@<vm-private-ip>
```

### 2. Verify EBS Volumes

```bash
# List attached volumes
aws ec2 describe-volumes --filters "Name=tag:Project,Values=Infrastructure"

# On each VM, verify the volume is attached
lsblk
```

### 3. Format and Mount EBS Volumes

On each VM:

```bash
# Format the volume (only first time)
sudo mkfs -t ext4 /dev/xvdf

# Create mount point
sudo mkdir /data

# Mount the volume
sudo mount /dev/xvdf /data

# Add to fstab for persistence
echo '/dev/xvdf /data ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

## OpenShift Installation

### 1. Prepare Installation

```bash
# Navigate to scripts directory
cd scripts

# Make scripts executable
chmod +x install-openshift.sh configure-odf.sh
```

### 2. Run OpenShift Installer

```bash
./install-openshift.sh
```

The script will:
1. Download OpenShift installer
2. Generate install-config.yaml
3. Create ignition configs
4. Bootstrap the cluster
5. Wait for installation to complete (30-45 minutes)

### 3. Monitor Installation

```bash
# Watch bootstrap progress
openshift-install wait-for bootstrap-complete --log-level=info

# Watch installation progress
openshift-install wait-for install-complete --log-level=info
```

### 4. Access OpenShift Console

```bash
# Get console URL
terraform output openshift_console_url

# Get kubeadmin password
terraform output openshift_admin_password

# Export kubeconfig
export KUBECONFIG=~/openshift/auth/kubeconfig

# Verify cluster access
oc get nodes
oc get co  # Check cluster operators
```

## ODF Storage Configuration

### 1. Install ODF Operator

```bash
# Run ODF configuration script
./configure-odf.sh
```

The script will:
1. Install Local Storage Operator
2. Create local volumes on worker nodes
3. Install ODF Operator
4. Create StorageCluster with 1TB capacity
5. Verify storage classes

### 2. Verify ODF Installation

```bash
# Check ODF pods
oc get pods -n openshift-storage

# Check storage classes
oc get sc

# Check storage cluster
oc get storagecluster -n openshift-storage

# Check Ceph status
oc rsh -n openshift-storage $(oc get pods -n openshift-storage -l app=rook-ceph-tools -o name) ceph status
```

### 3. Test ODF Storage

```bash
# Create test PVC
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: ocs-storagecluster-ceph-rbd
EOF

# Verify PVC is bound
oc get pvc test-pvc

# Clean up
oc delete pvc test-pvc
```

## Verification

### 1. Infrastructure Verification

```bash
# Check all resources
terraform show

# Verify VPCs
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=Infrastructure"

# Verify instances
aws ec2 describe-instances --filters "Name=tag:Project,Values=Infrastructure"

# Verify load balancer
aws elbv2 describe-load-balancers --names infrastructure-alb
```

### 2. Connectivity Verification

```bash
# Test ALB endpoint
curl -k https://$(terraform output -raw alb_dns_name)

# Test VM access through ALB
curl -k https://$(terraform output -raw alb_dns_name)/vm/health

# Test OpenShift console through ALB
curl -k https://$(terraform output -raw alb_dns_name)/openshift/
```

### 3. OpenShift Cluster Verification

```bash
# Check all nodes are ready
oc get nodes

# Check cluster operators
oc get co

# Check cluster version
oc get clusterversion

# Run cluster diagnostics
oc adm must-gather
```

### 4. Storage Verification

```bash
# VM EBS volumes
for instance in $(terraform output -json vm_instance_ids | jq -r '.[]'); do
  echo "Instance: $instance"
  aws ec2 describe-volumes --filters "Name=attachment.instance-id,Values=$instance"
done

# OpenShift ODF storage
oc get pv
oc get sc
oc get storagecluster -n openshift-storage
```

## Troubleshooting

### Common Issues

#### 1. Terraform Apply Fails

**Issue**: Resource creation timeout or quota exceeded

**Solution**:
```bash
# Check AWS service quotas
aws service-quotas list-service-quotas --service-code ec2

# Request quota increase if needed
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --desired-value 20
```

#### 2. OpenShift Installation Fails

**Issue**: Bootstrap timeout or API not accessible

**Solution**:
```bash
# Check bootstrap logs
ssh -i ~/.ssh/aws-infrastructure-key core@<bootstrap-ip> \
  journalctl -b -f -u bootkube.service

# Verify security groups allow required ports
aws ec2 describe-security-groups --group-ids <sg-id>

# Check DNS resolution
nslookup api.<cluster-name>.<domain>
```

#### 3. ODF Installation Issues

**Issue**: Storage cluster not ready

**Solution**:
```bash
# Check ODF operator logs
oc logs -n openshift-storage -l name=ocs-operator

# Verify local storage
oc get localvolume -n openshift-local-storage

# Check Ceph health
oc rsh -n openshift-storage $(oc get pods -n openshift-storage -l app=rook-ceph-tools -o name) ceph health detail
```

#### 4. Load Balancer Health Checks Failing

**Issue**: Targets showing unhealthy

**Solution**:
```bash
# Check target group health
aws elbv2 describe-target-health --target-group-arn <tg-arn>

# Verify security group rules
aws ec2 describe-security-groups --group-ids <sg-id>

# Check instance connectivity
aws ssm start-session --target <instance-id>
curl localhost:80
```

### Debug Commands

```bash
# Terraform debug mode
TF_LOG=DEBUG terraform apply

# AWS CLI debug
aws ec2 describe-instances --debug

# OpenShift debug
oc get events --all-namespaces --sort-by='.lastTimestamp'
oc describe node <node-name>
oc logs <pod-name> -n <namespace>
```

## Cleanup

### 1. Backup Important Data

```bash
# Backup OpenShift resources
oc get all --all-namespaces -o yaml > openshift-backup.yaml

# Backup EBS snapshots
aws ec2 create-snapshot --volume-id <volume-id> --description "Pre-cleanup backup"
```

### 2. Destroy Infrastructure

```bash
# Destroy OpenShift cluster first
openshift-install destroy cluster --dir=~/openshift

# Destroy Terraform resources
terraform destroy

# Confirm destruction
# Type 'yes' when prompted
```

### 3. Clean Up State Files

```bash
# Remove local state (if not using remote backend)
rm -rf .terraform terraform.tfstate*

# Clean up S3 backend (if used)
aws s3 rm s3://my-terraform-state-bucket/infrastructure/ --recursive
```

### 4. Verify Cleanup

```bash
# Check for remaining resources
aws ec2 describe-instances --filters "Name=tag:Project,Values=Infrastructure"
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=Infrastructure"
aws elbv2 describe-load-balancers
```

## Best Practices

1. **Always use remote state**: Store Terraform state in S3 with DynamoDB locking
2. **Tag all resources**: Use consistent tagging for cost tracking and management
3. **Use workspaces**: Separate dev/staging/prod environments
4. **Regular backups**: Schedule automated EBS snapshots and OpenShift backups
5. **Monitor costs**: Set up AWS Cost Explorer and billing alerts
6. **Security scanning**: Run `terraform plan` through security scanners
7. **Documentation**: Keep this guide updated with any customizations

## Support Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [OpenShift Documentation](https://docs.openshift.com/)
- [AWS Documentation](https://docs.aws.amazon.com/)
- [ODF Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_data_foundation/)

## Next Steps

After successful deployment:
1. Configure monitoring and alerting
2. Set up backup and disaster recovery
3. Implement CI/CD pipelines
4. Configure application deployments
5. Set up cost optimization strategies