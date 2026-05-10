#!/bin/bash

# GitOps Galaxy - Cluster Setup Script
# Initializes Kubernetes cluster with ArgoCD, storage, and RBAC
# This script runs after bootstrap.sh

set -e

# Check if running with sudo, if not, re-run with sudo
if [ "$EUID" -ne 0 ]; then 
    exec sudo -E "$0" "$@"
fi

# Get original user (vagrant)
ORIGINAL_USER=${SUDO_USER:-$USER}
ORIGINAL_HOME=$(eval echo ~$ORIGINAL_USER)

# Install necessary packages
apt-get update
apt-get install -y curl wget gnupg ca-certificates

# Install k3s/kubectl if the VM does not have a cluster toolchain yet.
if ! command -v kubectl >/dev/null 2>&1; then
  if ! command -v k3s >/dev/null 2>&1; then
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -
  fi

  if ! command -v kubectl >/dev/null 2>&1 && command -v k3s >/dev/null 2>&1; then
    ln -sf "$(command -v k3s)" /usr/local/bin/kubectl
  fi
fi

# Install Helm if it is missing
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Configure kubeconfig for the original user
mkdir -p "$ORIGINAL_HOME/.kube"
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  cp /etc/rancher/k3s/k3s.yaml "$ORIGINAL_HOME/.kube/config"
  chown "$ORIGINAL_USER:$ORIGINAL_USER" "$ORIGINAL_HOME/.kube/config"
  chmod 600 "$ORIGINAL_HOME/.kube/config"
  sed -i 's/127.0.0.1/192.168.56.10/g' "$ORIGINAL_HOME/.kube/config" || true
fi

export KUBECONFIG="$ORIGINAL_HOME/.kube/config"

# ============================================================================
# WAIT FOR KUBERNETES TO BE READY
# ============================================================================

# Wait for k3s service
until systemctl is-active --quiet k3s; do
sleep 5
done

# Wait for kubeconfig
until [ -f /etc/rancher/k3s/k3s.yaml ]; do
sleep 5
done

# Configure kubeconfig again (as original user)
mkdir -p "$ORIGINAL_HOME/.kube"
cp /etc/rancher/k3s/k3s.yaml "$ORIGINAL_HOME/.kube/config"
chown "$ORIGINAL_USER:$ORIGINAL_USER" "$ORIGINAL_HOME/.kube/config"
chmod 600 "$ORIGINAL_HOME/.kube/config"

# Set KUBECONFIG for root and original user
export KUBECONFIG="$ORIGINAL_HOME/.kube/config"
sudo -u "$ORIGINAL_USER" export KUBECONFIG="$ORIGINAL_HOME/.kube/config" 2>/dev/null || true

# Wait for Kubernetes API
until kubectl get nodes >/dev/null 2>&1; do
sleep 5
done

# Wait for node readiness
until kubectl get nodes --no-headers 2>/dev/null | grep -q " Ready "; do
sleep 5
done

kubectl get nodes

# Start K3s service
systemctl enable k3s
systemctl restart k3s

# ============================================================================
# CREATE NAMESPACES
# ============================================================================

# Create namespaces
for ns in dev staging production database argocd monitoring logging; do
    if ! kubectl get namespace "$ns" > /dev/null 2>&1; then
        kubectl create namespace "$ns"
    fi
done

# Label namespaces
kubectl label namespace dev environment=development --overwrite > /dev/null 2>&1
kubectl label namespace staging environment=staging --overwrite > /dev/null 2>&1
kubectl label namespace production environment=production --overwrite > /dev/null 2>&1
kubectl label namespace argocd managed-by=gitops --overwrite > /dev/null 2>&1

# ============================================================================
# CREATE PERSISTENT VOLUMES (for k3s)
# ============================================================================

# Create persistent volume directories
mkdir -p /mnt/data/{postgres,backend,frontend}
chmod 777 /mnt/data/{postgres,backend,frontend}

# Create PV manifest
cat > /tmp/persistent-volumes.yaml <<'EOF'
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-data
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/data/postgres
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k3s

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: backend-data
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/data/backend
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k3s

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: frontend-data
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/data/frontend
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k3s
EOF

# Apply persistent volumes
kubectl apply -f /tmp/persistent-volumes.yaml

# ============================================================================
# INSTALL INGRESS CONTROLLER
# ============================================================================

# Add Kubernetes ingress-nginx repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx > /dev/null 2>&1
helm repo update > /dev/null 2>&1

# Install ingress-nginx
if ! helm list -n ingress-nginx | grep -q "ingress-nginx"; then
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.kind=DaemonSet \
        --set controller.service.type=NodePort \
        --set controller.service.ports.http=80 \
        --set controller.service.ports.https=443 \
        --wait \
        > /dev/null 2>&1
fi

# ============================================================================
# INSTALL ARGOCD
# ============================================================================

# Add ArgoCD Helm repository if not present
if ! helm repo list | grep -q "argo"; then
    helm repo add argo https://argoproj.github.io/argo-helm > /dev/null 2>&1
    helm repo update > /dev/null 2>&1
fi

if ! helm list -n argocd | grep -q "argocd"; then
    # Create ArgoCD values file if it doesn't exist
    if [ ! -f /vagrant/config/argocd-values.yaml ]; then
        mkdir -p /vagrant/config
        cat > /vagrant/config/argocd-values.yaml <<'EOF'
global:
  domain: localhost

server:
  insecure: true
  service:
    type: NodePort
    nodePort: 30080

configs:
  cm:
    url: http://localhost:30080
  secret:
    createSecret: true

redis:
  enabled: true

repoServer:
  autoscaling:
    enabled: false

applicationController:
  replicas: 1

dex:
  enabled: true
EOF
    fi
    
    # Install ArgoCD
    helm install argocd argo/argo-cd \
        --namespace argocd \
        --values /vagrant/config/argocd-values.yaml \
        --wait \
        --timeout 10m \
        > /dev/null 2>&1
    
    # Wait for ArgoCD to be ready
    kubectl rollout status deployment/argocd-server -n argocd --timeout=5m > /dev/null 2>&1
fi

# ============================================================================
# CONFIGURE ARGOCD
# ============================================================================

# Get ArgoCD admin password
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "admin")

# Set KUBECONFIG for original user in their shell
su - "$ORIGINAL_USER" -c "echo 'export KUBECONFIG=$ORIGINAL_HOME/.kube/config' >> ~/.bashrc" 2>/dev/null || true

# Wait for ArgoCD API to be accessible
for i in {1..30}; do
    if kubectl get svc -n argocd argocd-server > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

# ============================================================================
# CREATE RBAC RESOURCES
# ============================================================================

# Create RBAC for applications
cat > /tmp/app-rbac.yaml <<'EOF'
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app
  namespace: dev
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app
  namespace: dev
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets", "pods", "pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app
  namespace: dev
subjects:
- kind: ServiceAccount
  name: app
  namespace: dev
roleRef:
  kind: Role
  name: app
  apiGroup: rbac.authorization.k8s.io
EOF

# Apply RBAC resources
kubectl apply -f /tmp/app-rbac.yaml > /dev/null 2>&1

# ============================================================================
# INSTALL METRICS SERVER (for HPA)
# ============================================================================

if kubectl get deployment metrics-server -n kube-system > /dev/null 2>&1; then
    # Configure existing metrics server
    kubectl patch deployment metrics-server -n kube-system \
        -p '{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","args":["--kubelet-preferred-address-types=internal,external,hostname","--kubelet-insecure-tls","--metric-resolution=15s"]}]}}}}' \
        > /dev/null 2>&1 || true
fi

# ============================================================================
# COPY KUBECONFIG TO SHARED LOCATION
# ============================================================================

cp "$ORIGINAL_HOME/.kube/config" /vagrant/kubeconfig
chmod 644 /vagrant/kubeconfig

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "Cluster setup complete!"
echo ""
echo "ArgoCD Access:"
echo "  Username: admin"
echo "  Password: $ARGOCD_PASSWORD"
echo ""
echo "Access ArgoCD UI:"
echo "  kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "  https://localhost:8080"
echo ""
echo "Kubeconfig available at: /vagrant/kubeconfig"
echo ""
echo "To use kubectl as vagrant user:"
echo "  export KUBECONFIG=/home/vagrant/.kube/config"