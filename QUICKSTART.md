# Quick Start Guide

Get your infrastructure up and running in minutes!

## Prerequisites Checklist

- [ ] Terraform >= 1.5.0 installed
- [ ] AWS CLI configured (`aws configure`)
- [ ] AWS account with admin permissions
- [ ] SSH key pair generated (`ssh-keygen -t rsa -b 4096`)
- [ ] OpenShift pull secret downloaded from [Red Hat Console](https://console.redhat.com/openshift/install/pull-secret)

## 5-Minute Setup

### Step 1: Configure Variables (2 minutes)

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

**Minimum required changes**:
```hcl
aws_region   = "us-east-1"              # Your AWS region
project_name = "my-infrastructure"       # Your project name
openshift_base_domain = "example.com"   # Your domain
ssh_public_key_path = "~/.ssh/id_rsa.pub"
openshift_pull_secret_path = "~/.openshift/pull-secret.json"
```

### Step 2: Deploy Infrastructure (3 minutes)

```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy (takes ~15-20 minutes)
terraform apply -auto-approve
```

### Step 3: Save Outputs

```bash
# Save all outputs to file
terraform output -json > infrastructure-outputs.json

# View key information
terraform output alb_dns_name
terraform output openshift_console_url
```

## Post-Deployment (30-45 minutes)

### Install OpenShift

```bash
cd scripts
./install-openshift.sh
```

This script will:
- Download OpenShift installer and CLI
- Generate installation configuration
- Deploy the cluster (30-45 minutes)
- Provide access credentials

### Configure ODF Storage

```bash
./configure-odf.sh
```

This script will:
- Install Local Storage Operator
- Install ODF Operator
- Create 1TB storage cluster
- Verify installation

## Access Your Infrastructure

### Via Load Balancer

```bash
# Get ALB URL
ALB_URL=$(terraform output -raw alb_dns_name)
echo "Access at: https://$ALB_URL"
```

### Via OpenShift Console

```bash
# Get console URL and credentials
terraform output openshift_console_url
cat ~/openshift/auth/kubeadmin-password
```

### Via SSH to VMs

```bash
# Using AWS Session Manager (no SSH key needed)
VM_ID=$(terraform output -json vm_instance_ids | jq -r '.[0]')
aws ssm start-session --target $VM_ID
```

## Verify Deployment

### Check Infrastructure

```bash
# List all resources
terraform state list

# Check specific outputs
terraform output deployment_summary
```

### Check OpenShift

```bash
# Set kubeconfig
export KUBECONFIG=~/openshift/auth/kubeconfig

# Check nodes
oc get nodes

# Check cluster operators
oc get co

# Check ODF storage
oc get storagecluster -n openshift-storage
```

### Check VMs

```bash
# Connect to first VM
aws ssm start-session --target $(terraform output -json vm_instance_ids | jq -r '.[0]')

# Inside VM, check mounted storage
df -h | grep /data
```

## Common Commands

### Terraform

```bash
# Show current state
terraform show

# List all resources
terraform state list

# Get specific output
terraform output <output_name>

# Update infrastructure
terraform apply

# Destroy everything
terraform destroy
```

### OpenShift

```bash
# Login as admin
oc login -u kubeadmin -p $(cat ~/openshift/auth/kubeadmin-password)

# Get cluster info
oc cluster-info

# Create test deployment
oc new-app --name=test nginx

# Check storage classes
oc get sc
```

### AWS

```bash
# List EC2 instances
aws ec2 describe-instances --filters "Name=tag:Project,Values=Infrastructure"

# List EBS volumes
aws ec2 describe-volumes --filters "Name=tag:Project,Values=Infrastructure"

# Check load balancer
aws elbv2 describe-load-balancers
```

## Troubleshooting

### Terraform Issues

**Problem**: Resource quota exceeded
```bash
# Check quotas
aws service-quotas list-service-quotas --service-code ec2

# Request increase
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-1216C47A \
  --desired-value 20
```

**Problem**: State lock error
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

### OpenShift Issues

**Problem**: Installation timeout
```bash
# Check bootstrap logs
openshift-install wait-for bootstrap-complete --log-level=debug

# Check cluster operators
oc get co
```

**Problem**: ODF not ready
```bash
# Check ODF pods
oc get pods -n openshift-storage

# Check storage cluster status
oc describe storagecluster ocs-storagecluster -n openshift-storage
```

### AWS Issues

**Problem**: Cannot connect to instances
```bash
# Verify Session Manager
aws ssm describe-instance-information

# Check security groups
aws ec2 describe-security-groups --group-ids <sg-id>
```

## Cost Management

### View Estimated Costs

```bash
terraform output estimated_monthly_cost
```

### Reduce Costs

1. **Use smaller instances** (edit `terraform.tfvars`):
   ```hcl
   vm_instance_type = "t3.large"  # Instead of m5.2xlarge
   openshift_worker_instance_type = "m5.2xlarge"  # Instead of m5.4xlarge
   ```

2. **Reduce NAT Gateways**:
   ```hcl
   nat_gateway_per_az = false  # Use 1 instead of 3 per VPC
   ```

3. **Schedule non-production**:
   ```bash
   # Stop instances during off-hours
   aws ec2 stop-instances --instance-ids <instance-id>
   ```

## Next Steps

1. **Configure DNS**: Point your domain to the ALB
2. **Set up monitoring**: Configure CloudWatch dashboards
3. **Enable backups**: Verify snapshot policies
4. **Deploy applications**: Start using your infrastructure
5. **Set up CI/CD**: Integrate with your pipelines

## Getting Help

- **Documentation**: See [README.md](README.md), [ARCHITECTURE.md](ARCHITECTURE.md), [DEPLOYMENT.md](DEPLOYMENT.md)
- **AWS Support**: https://console.aws.amazon.com/support
- **OpenShift Docs**: https://docs.openshift.com/
- **Terraform Docs**: https://www.terraform.io/docs

## Clean Up

When you're done:

```bash
# Destroy OpenShift cluster first
openshift-install destroy cluster --dir=~/openshift

# Then destroy Terraform infrastructure
terraform destroy

# Confirm with 'yes' when prompted
```

---

**Estimated Time**: 
- Setup: 5 minutes
- Infrastructure deployment: 15-20 minutes
- OpenShift installation: 30-45 minutes
- **Total: ~1 hour**

**Estimated Cost**: ~$6,270/month (us-east-1)