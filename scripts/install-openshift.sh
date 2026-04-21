#!/bin/bash
# ============================================
# OpenShift Installation Script
# ============================================

set -e

echo "=========================================="
echo "OpenShift Cluster Installation"
echo "=========================================="

# Check prerequisites
echo "Checking prerequisites..."

if [ ! -f ~/.openshift/pull-secret.json ]; then
    echo "ERROR: OpenShift pull secret not found at ~/.openshift/pull-secret.json"
    echo "Download it from: https://console.redhat.com/openshift/install/pull-secret"
    exit 1
fi

if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo "ERROR: SSH public key not found at ~/.ssh/id_rsa.pub"
    echo "Generate one with: ssh-keygen -t rsa -b 4096"
    exit 1
fi

# Get Terraform outputs
echo "Retrieving infrastructure information from Terraform..."
CLUSTER_NAME=$(terraform output -raw openshift_cluster_name 2>/dev/null || echo "openshift-cluster")
BASE_DOMAIN=$(terraform output -raw openshift_base_domain 2>/dev/null || echo "example.com")
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

echo "Cluster Name: $CLUSTER_NAME"
echo "Base Domain: $BASE_DOMAIN"
echo "AWS Region: $AWS_REGION"

# Download OpenShift installer
echo ""
echo "Downloading OpenShift installer..."
OPENSHIFT_VERSION="4.14"
INSTALLER_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-${OPENSHIFT_VERSION}/openshift-install-linux.tar.gz"

wget -q $INSTALLER_URL -O /tmp/openshift-install-linux.tar.gz
tar -xzf /tmp/openshift-install-linux.tar.gz -C /tmp/
sudo mv /tmp/openshift-install /usr/local/bin/
sudo chmod +x /usr/local/bin/openshift-install
rm /tmp/openshift-install-linux.tar.gz

echo "OpenShift installer version:"
openshift-install version

# Download OpenShift CLI
echo ""
echo "Downloading OpenShift CLI..."
OC_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-${OPENSHIFT_VERSION}/openshift-client-linux.tar.gz"

wget -q $OC_URL -O /tmp/openshift-client-linux.tar.gz
tar -xzf /tmp/openshift-client-linux.tar.gz -C /tmp/
sudo mv /tmp/oc /usr/local/bin/
sudo mv /tmp/kubectl /usr/local/bin/
sudo chmod +x /usr/local/bin/oc /usr/local/bin/kubectl
rm /tmp/openshift-client-linux.tar.gz

echo "OpenShift CLI version:"
oc version --client

# Create installation directory
echo ""
echo "Creating installation directory..."
INSTALL_DIR=~/openshift
mkdir -p $INSTALL_DIR

# Generate install-config.yaml
echo ""
echo "Generating install-config.yaml..."
cat > $INSTALL_DIR/install-config.yaml <<EOF
apiVersion: v1
baseDomain: ${BASE_DOMAIN}
metadata:
  name: ${CLUSTER_NAME}
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform:
    aws:
      type: m5.4xlarge
      zones:
      - ${AWS_REGION}a
      - ${AWS_REGION}b
      - ${AWS_REGION}c
  replicas: 7
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform:
    aws:
      type: m5.xlarge
      zones:
      - ${AWS_REGION}a
      - ${AWS_REGION}b
      - ${AWS_REGION}c
  replicas: 3
platform:
  aws:
    region: ${AWS_REGION}
    userTags:
      Project: Infrastructure
      ManagedBy: Terraform
pullSecret: '$(cat ~/.openshift/pull-secret.json | tr -d '\n')'
sshKey: '$(cat ~/.ssh/id_rsa.pub)'
EOF

echo "Install configuration created at: $INSTALL_DIR/install-config.yaml"

# Backup install-config.yaml
cp $INSTALL_DIR/install-config.yaml $INSTALL_DIR/install-config.yaml.backup

# Create cluster
echo ""
echo "=========================================="
echo "Starting OpenShift cluster installation..."
echo "This will take approximately 30-45 minutes"
echo "=========================================="
echo ""

openshift-install create cluster --dir=$INSTALL_DIR --log-level=info

# Installation complete
echo ""
echo "=========================================="
echo "OpenShift Installation Complete!"
echo "=========================================="
echo ""
echo "Cluster Information:"
echo "  Console URL: https://console-openshift-console.apps.${CLUSTER_NAME}.${BASE_DOMAIN}"
echo "  API URL: https://api.${CLUSTER_NAME}.${BASE_DOMAIN}:6443"
echo ""
echo "Credentials:"
echo "  Username: kubeadmin"
echo "  Password: $(cat $INSTALL_DIR/auth/kubeadmin-password)"
echo ""
echo "Kubeconfig: $INSTALL_DIR/auth/kubeconfig"
echo ""
echo "To use the cluster:"
echo "  export KUBECONFIG=$INSTALL_DIR/auth/kubeconfig"
echo "  oc get nodes"
echo "  oc get co"
echo ""
echo "Next steps:"
echo "  1. Configure ODF storage: ./configure-odf.sh"
echo "  2. Access the web console"
echo "  3. Deploy your applications"
echo ""

# Made with Bob
