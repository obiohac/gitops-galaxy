#!/bin/bash

# GitOps Galaxy - Cluster Setup Script
# Initializes Kubernetes cluster with ArgoCD, storage, and RBAC
# This script runs after bootstrap.sh

set -e

# Vagrant private IP used to access Kubernetes API from inside VM and host.
API_SERVER_IP="${API_SERVER_IP:-192.168.56.10}"

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Install k3s/kubectl if the VM does not have a cluster toolchain yet.
if ! command -v kubectl >/dev/null 2>&1; then
  if ! command -v k3s >/dev/null 2>&1; then
    print_header "Installing K3s"
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -
  fi

  if ! command -v kubectl >/dev/null 2>&1 && command -v k3s >/dev/null 2>&1; then
    sudo ln -sf "$(command -v k3s)" /usr/local/bin/kubectl
  fi
fi

# Install Helm if it is missing; the rest of this script depends on it.
if ! command -v helm >/dev/null 2>&1; then
  print_header "Installing Helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Configure kubeconfig for the current shell.
mkdir -p "$HOME/.kube"
if [ -f /etc/rancher/k3s/k3s.yaml ]; then
  sudo cp /etc/rancher/k3s/k3s.yaml "$HOME/.kube/config"
  sudo chown "$USER:$USER" "$HOME/.kube/config"
  chmod 600 "$HOME/.kube/config"
fi

export KUBECONFIG="$HOME/.kube/config"

# ============================================================================
# WAIT FOR KUBERNETES TO BE READY
# ============================================================================

print_header "Waiting for Kubernetes Cluster"

print_info "Waiting for k3s to be ready..."
for i in {1..120}; do
    if kubectl cluster-info > /dev/null 2>&1 && \
       kubectl get nodes > /dev/null 2>&1; then
        print_success "Kubernetes cluster is ready"
        break
    fi
    echo -n "."
    sleep 1
    if [ $i -eq 120 ]; then
        echo ""
        echo "Error: Timeout waiting for cluster to be ready"
        echo "Debugging info:"
        kubectl cluster-info || true
        kubectl get nodes || true
        exit 1
    fi
done
# ============================================================================

print_header "Creating Namespaces"

# Create namespaces
for ns in dev staging production database argocd monitoring logging; do
    if kubectl get namespace "$ns" > /dev/null 2>&1; then
        print_success "Namespace '$ns' already exists"
    else
        print_info "Creating namespace '$ns'..."
        kubectl create namespace "$ns"
        print_success "Namespace '$ns' created"
    fi
done

# Label namespaces
kubectl label namespace dev environment=development --overwrite > /dev/null 2>&1
kubectl label namespace staging environment=staging --overwrite > /dev/null 2>&1
kubectl label namespace production environment=production --overwrite > /dev/null 2>&1
kubectl label namespace argocd managed-by=gitops --overwrite > /dev/null 2>&1

print_success "Namespaces configured"

# ============================================================================
# CREATE PERSISTENT VOLUMES (for k3s)
# ============================================================================

print_header "Setting Up Storage"

print_info "Creating persistent volume directories..."
sudo mkdir -p /mnt/data/{postgres,backend,frontend}
sudo chmod 777 /mnt/data/{postgres,backend,frontend}

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

print_info "Applying persistent volumes..."
kubectl apply -f /tmp/persistent-volumes.yaml
print_success "Persistent volumes created"

# ============================================================================
# INSTALL INGRESS CONTROLLER
# ============================================================================

print_header "Installing Ingress Controller"

# Add Kubernetes ingress-nginx repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx > /dev/null 2>&1
helm repo update > /dev/null 2>&1

# Install ingress-nginx
if helm list -n ingress-nginx | grep -q "ingress-nginx"; then
    print_success "Ingress-nginx already installed"
else
    print_info "Installing ingress-nginx..."
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.kind=DaemonSet \
        --set controller.service.type=NodePort \
        --set controller.service.ports.http=80 \
        --set controller.service.ports.https=443 \
        --wait \
        > /dev/null 2>&1
    print_success "Ingress-nginx installed"
fi

# ============================================================================
# INSTALL ARGOCD
# ============================================================================

print_header "Installing ArgoCD"

if helm list -n argocd | grep -q "argocd"; then
    print_success "ArgoCD already installed"
else
    print_info "Installing ArgoCD..."
    
    # Create ArgoCD values file if it doesn't exist
    if [ ! -f /vagrant/config/argocd-values.yaml ]; then
        print_info "Creating default ArgoCD values..."
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
    
    print_success "ArgoCD installed"
    
    # Wait for ArgoCD to be ready
    print_info "Waiting for ArgoCD to be ready..."
    kubectl rollout status deployment/argocd-server -n argocd --timeout=5m > /dev/null 2>&1
fi

# ============================================================================
# CONFIGURE ARGOCD
# ============================================================================

print_header "Configuring ArgoCD"

# Get ArgoCD admin password
print_info "Retrieving ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "admin")

# Export kubeconfig for ArgoCD CLI
export KUBECONFIG=$HOME/.kube/config

# Wait for ArgoCD API to be accessible
print_info "Waiting for ArgoCD API..."
for i in {1..30}; do
    if kubectl get svc -n argocd argocd-server > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

print_success "ArgoCD installed and configured"
echo ""
echo "ArgoCD Access Information:"
echo "  Admin User: admin"
echo "  Admin Password: $ARGOCD_PASSWORD"
echo ""
echo "Access ArgoCD UI:"
echo "  Port-forward: kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "  Then visit: https://localhost:8080"
echo ""

# ============================================================================
# CREATE RBAC RESOURCES
# ============================================================================

print_header "Setting Up RBAC"

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

print_info "Applying RBAC resources..."
kubectl apply -f /tmp/app-rbac.yaml > /dev/null 2>&1
print_success "RBAC configured"

# ============================================================================
# INSTALL METRICS SERVER (for HPA)
# ============================================================================

print_header "Installing Metrics Server"

if kubectl get deployment metrics-server -n kube-system > /dev/null 2>&1; then
    print_success "Metrics server already installed"
else
    print_info "Installing metrics server..."
    
    # k3s comes with metrics server, but we need to ensure it's running
    kubectl patch deployment metrics-server -n kube-system \
        -p '{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","args":["--kubelet-preferred-address-types=internal,external,hostname","--kubelet-insecure-tls","--metric-resolution=15s"]}]}}}}' \
        > /dev/null 2>&1 || true
    
    print_success "Metrics server configured"
fi

# ============================================================================
# COPY KUBECONFIG TO SHARED LOCATION
# ============================================================================

print_header "Finalizing Setup"

print_info "Copying kubeconfig to /vagrant for host access..."
cp $HOME/.kube/config /vagrant/kubeconfig
chmod 644 /vagrant/kubeconfig
print_success "Kubeconfig copied"

# ============================================================================
# SUMMARY
# ============================================================================

print_header "Cluster Setup Complete!"

echo ""
echo "✓ All cluster components installed"
echo ""
echo "Key Information:"
echo "  - Kubernetes API: https://${API_SERVER_IP}:6443"
echo "  - Ingress Controller: NodePort 30080"
echo "  - ArgoCD Server: kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "  - ArgoCD Admin: admin / $ARGOCD_PASSWORD"
echo ""
echo "Verify cluster:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  kubectl get svc -n argocd"
echo ""
echo "Next steps from host machine:"
echo "  export KUBECONFIG=\$PWD/kubeconfig"
echo "  kubectl cluster-info"
echo "  kubectl get nodes"
echo ""
echo "Deploy applications:"
echo "  cd /vagrant"
echo "  kubectl apply -f manifests/argocd/applications/"
echo ""
echo "Monitor with ArgoCD:"
echo "  argocd app list"
echo "  argocd app watch frontend-app"
echo ""

rm -rf gitops-galaxy/argocd