#!/bin/bash
# ============================================
# EC2 Instance User Data Script
# ============================================

set -e

# Update system
yum update -y

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/messages"
          },
          {
            "file_path": "/var/log/secure",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/secure"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "CustomMetrics",
    "metrics_collected": {
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "rename": "MemoryUtilization",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "rename": "DiskUtilization",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

# Install useful tools
yum install -y \
  htop \
  vim \
  git \
  wget \
  curl \
  jq \
  unzip

# Create data directory for EBS volume
mkdir -p /data

echo "User data script completed successfully"

# Made with Bob
