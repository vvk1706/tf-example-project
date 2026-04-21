# Architecture Documentation

## Overview

This infrastructure consists of two isolated private clouds connected through an Application Load Balancer, providing secure and scalable compute and storage resources.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Region                               │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Application Load Balancer                │ │
│  │                  (Public Subnets - Multi-AZ)                │ │
│  └──────────────────┬─────────────────┬───────────────────────┘ │
│                     │                 │                          │
│  ┌──────────────────▼─────────────────▼──────────────────────┐  │
│  │                    NAT Gateways (Multi-AZ)                 │  │
│  └──────────────────┬─────────────────┬───────────────────────┘  │
│                     │                 │                          │
│  ┌──────────────────▼──────────────┐ ┌▼──────────────────────┐  │
│  │   VPC 1: VM Private Cloud       │ │ VPC 2: OpenShift Cloud│  │
│  │   CIDR: 10.0.0.0/16             │ │ CIDR: 10.1.0.0/16     │  │
│  │                                  │ │                        │  │
│  │  ┌────────────────────────────┐ │ │ ┌───────────────────┐ │  │
│  │  │  Private Subnet 1          │ │ │ │ Private Subnet 1  │ │  │
│  │  │  ┌──────────────────────┐  │ │ │ │ ┌───────────────┐ │ │  │
│  │  │  │ VM-1                 │  │ │ │ │ │ Control-1     │ │ │  │
│  │  │  │ 8vCPU x 64GB        │  │ │ │ │ │ 4vCPU x 16GB  │ │ │  │
│  │  │  │ + 100GB EBS         │  │ │ │ │ └───────────────┘ │ │  │
│  │  │  └──────────────────────┘  │ │ │ │ ┌───────────────┐ │ │  │
│  │  └────────────────────────────┘ │ │ │ │ Worker 1-2    │ │ │  │
│  │                                  │ │ │ │ 16vCPU x 96GB │ │ │  │
│  │  ┌────────────────────────────┐ │ │ │ └───────────────┘ │ │  │
│  │  │  Private Subnet 2          │ │ │ └───────────────────┘ │  │
│  │  │  ┌──────────────────────┐  │ │ │                        │  │
│  │  │  │ VM-2                 │  │ │ │ ┌───────────────────┐ │  │
│  │  │  │ 8vCPU x 64GB        │  │ │ │ │ Private Subnet 2  │ │  │
│  │  │  │ + 100GB EBS         │  │ │ │ │ ┌───────────────┐ │ │  │
│  │  │  └──────────────────────┘  │ │ │ │ │ Control-2     │ │ │  │
│  │  └────────────────────────────┘ │ │ │ │ 4vCPU x 16GB  │ │ │  │
│  │                                  │ │ │ └───────────────┘ │ │  │
│  │  ┌────────────────────────────┐ │ │ │ ┌───────────────┐ │ │  │
│  │  │  Private Subnet 3          │ │ │ │ │ Worker 3-5    │ │ │  │
│  │  │  ┌──────────────────────┐  │ │ │ │ │ 16vCPU x 96GB │ │ │  │
│  │  │  │ VM-3                 │  │ │ │ │ └───────────────┘ │ │  │
│  │  │  │ 8vCPU x 64GB        │  │ │ │ └───────────────────┘ │  │
│  │  │  │ + 100GB EBS         │  │ │ │                        │  │
│  │  │  └──────────────────────┘  │ │ │ ┌───────────────────┐ │  │
│  │  └────────────────────────────┘ │ │ │ Private Subnet 3  │ │  │
│  │                                  │ │ │ ┌───────────────┐ │ │  │
│  └──────────────────────────────────┘ │ │ │ Control-3     │ │ │  │
│                                        │ │ │ 4vCPU x 16GB  │ │ │  │
│                                        │ │ └───────────────┘ │ │  │
│                                        │ │ ┌───────────────┐ │ │  │
│                                        │ │ │ Worker 6-7    │ │ │  │
│                                        │ │ │ 16vCPU x 96GB │ │ │  │
│                                        │ │ └───────────────┘ │ │  │
│                                        │ │                   │ │  │
│                                        │ │ ┌───────────────┐ │ │  │
│                                        │ │ │ ODF Storage   │ │ │  │
│                                        │ │ │ 1TB Capacity  │ │ │  │
│                                        │ │ └───────────────┘ │ │  │
│                                        │ └───────────────────┘ │  │
│                                        └────────────────────────┘  │
└───────────────────────────────────────────────────────────────────┘
```

## Components

### 1. VPC 1: VM Private Cloud (10.0.0.0/16)

**Purpose**: Host general-purpose virtual machines

**Components**:
- 3 Private Subnets across 3 Availability Zones
- 3 EC2 instances (m5.2xlarge: 8 vCPU, 64GB RAM)
- 3 EBS volumes (100GB each, gp3 type)
- NAT Gateway for outbound internet access
- Security groups for VM access control

**Instance Specifications**:
- Instance Type: `m5.2xlarge`
- vCPU: 8
- Memory: 64 GB
- Storage: 100 GB EBS (gp3)
- OS: Amazon Linux 2023 or Ubuntu 22.04 LTS

### 2. VPC 2: OpenShift Private Cloud (10.1.0.0/16)

**Purpose**: Host OpenShift Container Platform cluster

**Components**:
- 3 Private Subnets across 3 Availability Zones
- 3 Control Plane nodes (m5.xlarge: 4 vCPU, 16GB RAM)
- 7 Worker nodes (m5.4xlarge: 16 vCPU, 96GB RAM)
- ODF (OpenShift Data Foundation) storage: 1TB
- NAT Gateway for outbound internet access
- Security groups for OpenShift cluster communication

**Worker Node Specifications**:
- Instance Type: `m5.4xlarge`
- vCPU: 16
- Memory: 96 GB
- Storage: 120 GB root volume + ODF storage
- OS: Red Hat CoreOS

**Control Plane Specifications**:
- Instance Type: `m5.xlarge`
- vCPU: 4
- Memory: 16 GB
- Storage: 120 GB root volume

### 3. Application Load Balancer

**Purpose**: Provide secure access to both private clouds

**Features**:
- Multi-AZ deployment for high availability
- SSL/TLS termination
- Path-based routing to different VPCs
- Health checks for backend instances
- Connection draining
- Access logs to S3

**Routing Rules**:
- `/vm/*` → VM Private Cloud
- `/openshift/*` → OpenShift Private Cloud
- Default → OpenShift Console

### 4. Storage Architecture

#### EBS Volumes (VM Private Cloud)
- Type: gp3 (General Purpose SSD)
- Size: 100 GB per VM (300 GB total)
- IOPS: 3000 baseline
- Throughput: 125 MB/s
- Encryption: Enabled (AWS managed keys)
- Snapshots: Daily automated backups

#### ODF Storage (OpenShift)
- Total Capacity: 1 TB
- Storage Class: ocs-storagecluster-ceph-rbd
- Replication: 3x (across availability zones)
- Features:
  - Block storage (RBD)
  - File storage (CephFS)
  - Object storage (RGW)
- Backup: Velero integration for cluster backups

### 5. Networking

#### VPC Peering
- Established between VM VPC and OpenShift VPC
- Allows private communication between clouds
- Route tables updated for cross-VPC traffic

#### Security Groups

**VM Security Group**:
- Inbound: SSH (22), HTTP (80), HTTPS (443) from ALB
- Outbound: All traffic

**OpenShift Security Group**:
- Inbound: 
  - API Server (6443) from ALB
  - Router (80, 443) from ALB
  - Internal cluster communication (all ports from cluster CIDR)
- Outbound: All traffic

**ALB Security Group**:
- Inbound: HTTP (80), HTTPS (443) from 0.0.0.0/0
- Outbound: To VM and OpenShift security groups

### 6. High Availability

- Multi-AZ deployment for all components
- Auto-scaling groups for OpenShift workers (optional)
- Load balancer health checks
- Automated failover
- Cross-AZ data replication

### 7. Monitoring and Logging

- CloudWatch metrics for all EC2 instances
- VPC Flow Logs for network traffic analysis
- ALB access logs
- OpenShift built-in monitoring (Prometheus/Grafana)
- CloudWatch Logs for application logs

## Network Flow

1. **External Access**:
   - User → Internet → ALB (Public Subnet)
   - ALB → NAT Gateway → Private Subnet (VM or OpenShift)

2. **Inter-VPC Communication**:
   - VM VPC ↔ VPC Peering ↔ OpenShift VPC

3. **Outbound Internet**:
   - Private Subnet → NAT Gateway → Internet Gateway → Internet

## Security Considerations

1. **Network Isolation**:
   - All compute resources in private subnets
   - No direct internet access to instances
   - VPC peering for controlled inter-VPC communication

2. **Access Control**:
   - IAM roles for EC2 instances
   - Security groups with least privilege
   - Network ACLs for additional layer

3. **Encryption**:
   - EBS volumes encrypted at rest
   - TLS/SSL for data in transit
   - Secrets stored in AWS Secrets Manager

4. **Compliance**:
   - VPC Flow Logs enabled
   - CloudTrail for API auditing
   - Config for compliance monitoring

## Scalability

- Horizontal scaling via Auto Scaling Groups
- Vertical scaling by changing instance types
- Storage expansion through EBS volume resizing
- ODF storage can be expanded by adding nodes

## Disaster Recovery

- Multi-AZ deployment for high availability
- Automated EBS snapshots
- OpenShift ETCD backups
- Cross-region replication (optional)
- Infrastructure as Code for rapid rebuild

## Cost Optimization

- Use Reserved Instances for predictable workloads
- Right-size instances based on actual usage
- Use gp3 volumes instead of io1/io2
- Enable S3 lifecycle policies for logs
- Schedule non-production environments

## Future Enhancements

- Add AWS Transit Gateway for multi-VPC connectivity
- Implement AWS PrivateLink for service endpoints
- Add AWS WAF for application protection
- Implement GitOps with ArgoCD
- Add observability with AWS X-Ray