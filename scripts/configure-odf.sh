#!/bin/bash
# ============================================
# ODF (OpenShift Data Foundation) Configuration Script
# ============================================

set -e

echo "=========================================="
echo "OpenShift Data Foundation Configuration"
echo "=========================================="

# Check prerequisites
echo "Checking prerequisites..."

if [ ! -f ~/openshift/auth/kubeconfig ]; then
    echo "ERROR: Kubeconfig not found at ~/openshift/auth/kubeconfig"
    echo "Please run install-openshift.sh first"
    exit 1
fi

export KUBECONFIG=~/openshift/auth/kubeconfig

# Verify cluster access
echo "Verifying cluster access..."
if ! oc whoami &>/dev/null; then
    echo "ERROR: Cannot connect to OpenShift cluster"
    echo "Please check your kubeconfig and cluster status"
    exit 1
fi

echo "Connected to cluster: $(oc whoami --show-server)"

# Install Local Storage Operator
echo ""
echo "Installing Local Storage Operator..."
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-local-storage
---
apiVersion: operators.coreos.com/v1alpha2
kind: OperatorGroup
metadata:
  name: local-operator-group
  namespace: openshift-local-storage
spec:
  targetNamespaces:
  - openshift-local-storage
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: local-storage-operator
  namespace: openshift-local-storage
spec:
  channel: stable
  installPlanApproval: Automatic
  name: local-storage-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

echo "Waiting for Local Storage Operator to be ready..."
sleep 30
oc wait --for=condition=Ready pod -l name=local-storage-operator -n openshift-local-storage --timeout=300s

# Install ODF Operator
echo ""
echo "Installing OpenShift Data Foundation Operator..."
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  labels:
    openshift.io/cluster-monitoring: "true"
  name: openshift-storage
---
apiVersion: operators.coreos.com/v1alpha2
kind: OperatorGroup
metadata:
  name: openshift-storage-operatorgroup
  namespace: openshift-storage
spec:
  targetNamespaces:
  - openshift-storage
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: odf-operator
  namespace: openshift-storage
spec:
  channel: stable-4.14
  installPlanApproval: Automatic
  name: odf-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

echo "Waiting for ODF Operator to be ready..."
sleep 60
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=odf-operator -n openshift-storage --timeout=600s

# Label worker nodes for ODF
echo ""
echo "Labeling worker nodes for ODF..."
WORKER_NODES=$(oc get nodes -l node-role.kubernetes.io/worker -o name)
for node in $WORKER_NODES; do
    echo "Labeling $node"
    oc label $node cluster.ocs.openshift.io/openshift-storage='' --overwrite
done

# Create StorageCluster
echo ""
echo "Creating ODF StorageCluster..."
cat <<EOF | oc apply -f -
apiVersion: ocs.openshift.io/v1
kind: StorageCluster
metadata:
  name: ocs-storagecluster
  namespace: openshift-storage
spec:
  arbiter: {}
  encryption:
    kms: {}
  externalStorage: {}
  flexibleScaling: true
  resources:
    mds:
      limits:
        cpu: "3"
        memory: 8Gi
      requests:
        cpu: "1"
        memory: 8Gi
    mgr:
      limits:
        cpu: "1"
        memory: 3Gi
      requests:
        cpu: 500m
        memory: 3Gi
  monDataDirHostPath: /var/lib/rook
  managedResources:
    cephBlockPools:
      reconcileStrategy: manage
    cephConfig: {}
    cephDashboard: {}
    cephFilesystems:
      reconcileStrategy: manage
    cephObjectStoreUsers: {}
    cephObjectStores:
      reconcileStrategy: manage
  multiCloudGateway:
    reconcileStrategy: manage
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
    placement: {}
    portable: true
    replica: 3
    resources:
      limits:
        cpu: "2"
        memory: 5Gi
      requests:
        cpu: "1"
        memory: 5Gi
EOF

echo ""
echo "Waiting for StorageCluster to be ready..."
echo "This may take 10-15 minutes..."

# Wait for storage cluster
for i in {1..60}; do
    STATUS=$(oc get storagecluster ocs-storagecluster -n openshift-storage -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
    echo "[$i/60] StorageCluster status: $STATUS"
    
    if [ "$STATUS" == "Ready" ]; then
        echo "StorageCluster is ready!"
        break
    fi
    
    if [ $i -eq 60 ]; then
        echo "WARNING: StorageCluster did not become ready within expected time"
        echo "Check status with: oc get storagecluster -n openshift-storage"
    fi
    
    sleep 15
done

# Verify storage classes
echo ""
echo "Verifying storage classes..."
oc get sc

# Check ODF pods
echo ""
echo "Checking ODF pods..."
oc get pods -n openshift-storage

# Display Ceph status
echo ""
echo "Checking Ceph cluster status..."
TOOLS_POD=$(oc get pods -n openshift-storage -l app=rook-ceph-tools -o name 2>/dev/null | head -1)
if [ -n "$TOOLS_POD" ]; then
    oc rsh -n openshift-storage $TOOLS_POD ceph status
else
    echo "Ceph tools pod not found. Deploy it with:"
    echo "oc patch OCSInitialization ocsinit -n openshift-storage --type json --patch '[{ \"op\": \"replace\", \"path\": \"/spec/enableCephTools\", \"value\": true }]'"
fi

# Create test PVC
echo ""
echo "Creating test PVC to verify ODF..."
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: odf-test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: ocs-storagecluster-ceph-rbd
EOF

echo "Waiting for test PVC to be bound..."
sleep 10
oc get pvc odf-test-pvc -n default

# Installation complete
echo ""
echo "=========================================="
echo "ODF Configuration Complete!"
echo "=========================================="
echo ""
echo "Available Storage Classes:"
oc get sc | grep ocs
echo ""
echo "ODF Storage Capacity:"
oc get storagecluster ocs-storagecluster -n openshift-storage -o jsonpath='{.status.storage.deviceSetCount}' 2>/dev/null && echo " device sets"
echo ""
echo "Useful Commands:"
echo "  Check storage cluster: oc get storagecluster -n openshift-storage"
echo "  Check ODF pods: oc get pods -n openshift-storage"
echo "  Check storage classes: oc get sc"
echo "  Check PVs: oc get pv"
echo "  Check Ceph status: oc rsh -n openshift-storage \$(oc get pods -n openshift-storage -l app=rook-ceph-tools -o name) ceph status"
echo ""
echo "To clean up test PVC:"
echo "  oc delete pvc odf-test-pvc -n default"
echo ""

# Made with Bob
