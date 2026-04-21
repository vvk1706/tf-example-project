# AWS Infrastructure with Terraform

This project deploys a comprehensive AWS infrastructure including:
- 3 EC2 VMs (8 vCPU x 64GB RAM) in a private cloud
- OpenShift cluster with 7 worker nodes (16 vCPU x 96GB RAM) in a separate private cloud
- Load balancer for accessing both private clouds
- EBS storage (300GB total: 3x 100GB volumes)
- ODF storage for OpenShift (1TB capacity)

## Project Structure

```
.
├── README.md                          # This file
├── ARCHITECTURE.md                    # Architecture documentation
├── DEPLOYMENT.md                      # Deployment guide
├── PROJECT_SUMMARY.md                 # Project summary and status
├── MODULE_TEMPLATES.md                # Reference templates
├── main.tf                           # Main Terraform configuration
├── provider.tf                       # AWS provider configuration
├── backend.tf                        # Terraform backend configuration
├── variables.tf                      # Input variables
├── outputs.tf                        # Output values
├── terraform.tfvars.example          # Example variables file
├── .gitignore                        # Git ignore rules
├── modules/
│   ├── networking/                   # VPC and networking module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── compute/                      # EC2 instances module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── user_data.sh
│   ├── storage/                      # EBS storage module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── openshift/                    # OpenShift cluster module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── load-balancer/                # Application Load Balancer module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── scripts/
    ├── install-openshift.sh          # OpenShift installation script
    └── configure-odf.sh              # ODF storage configuration script
```

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- AWS account with sufficient permissions
- OpenShift pull secret (for OpenShift installation)

## Quick Start

1. Clone this repository
2. Copy `terraform.tfvars.example` to `terraform.tfvars`
3. Update `terraform.tfvars` with your values
4. Initialize Terraform: `terraform init`
5. Review the plan: `terraform plan`
6. Apply the configuration: `terraform apply`

## Detailed Documentation

- [Architecture Documentation](ARCHITECTURE.md) - Detailed architecture and design
- [Deployment Guide](DEPLOYMENT.md) - Step-by-step deployment instructions
- [Project Summary](PROJECT_SUMMARY.md) - Project status and overview

## Infrastructure Components

### VPC 1: VM Private Cloud (10.0.0.0/16)
- 3 Private Subnets across 3 Availability Zones
- 3 EC2 instances (m5.2xlarge: 8 vCPU, 64GB RAM)
- 3 EBS volumes (100GB each, gp3 type)
- NAT Gateway for outbound internet access

### VPC 2: OpenShift Private Cloud (10.1.0.0/16)
- 3 Private Subnets across 3 Availability Zones
- 3 Control Plane nodes (m5.xlarge: 4 vCPU, 16GB RAM)
- 7 Worker nodes (m5.4xlarge: 16 vCPU, 96GB RAM)
- ODF (OpenShift Data Foundation) storage: 1TB
- NAT Gateway for outbound internet access

### Application Load Balancer
- Multi-AZ deployment for high availability
- SSL/TLS termination
- Path-based routing to different VPCs
- Health checks for backend instances

## Cost Estimation

This infrastructure will incur AWS costs. Estimated monthly cost:
- EC2 instances (VMs): ~$1,200/month
- OpenShift control plane: ~$450/month
- OpenShift worker nodes: ~$4,200/month
- EBS storage: ~$130/month
- NAT Gateways: ~$270/month
- Load balancer: ~$20/month

**Total estimated: ~$6,270/month** (may vary by region and usage)

## Security Considerations

- All resources are deployed in private subnets
- Security groups restrict access
- IAM roles follow least privilege principle
- Encryption at rest enabled for EBS volumes
- VPC flow logs enabled for network monitoring

## Post-Deployment

After infrastructure is deployed:

1. **Install OpenShift**:
   ```bash
   cd scripts
   ./install-openshift.sh
   ```

2. **Configure ODF Storage**:
   ```bash
   ./configure-odf.sh
   ```

3. **Access Resources**:
   - Load Balancer: `terraform output alb_dns_name`
   - OpenShift Console: `terraform output openshift_console_url`
   - VM Access: Use AWS Systems Manager Session Manager

## Useful Commands

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan

# Apply changes
terraform apply

# Show outputs
terraform output

# Destroy infrastructure
terraform destroy
```

## Support

For issues or questions, please refer to the documentation:
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [DEPLOYMENT.md](DEPLOYMENT.md)
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)

## License

MIT License