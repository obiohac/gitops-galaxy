# Complete Commands Reference

All commands needed to manage GitOps Galaxy deployment.

## 📋 Quick Reference

### Setup
```bash
make cluster-setup          # Set up k3s cluster
make argocd-install         # Install ArgoCD
make image-updater-setup    # Install Image Updater
make external-secrets-setup # Install External Secrets
make vault-setup            # Deploy Vault
```

### Deploy
```bash
make deploy-dev             # Deploy to development
make deploy-staging         # Deploy to staging
make deploy-prod            # Deploy to production
```

### Verify
```bash
make status                 # Show deployment status
make test-helm              # Test Helm charts
make test-manifests         # Validate manifests
```

### Rollback
```bash
make rollback-dev           # Rollback development
make rollback-staging       # Rollback staging
make rollback-prod          # Rollback production
```

---

## 🎯 Cluster Setup Commands

### Initialize Kubernetes Cluster

```bash
# Using Vagrant
vagrant up
vagrant status
vagrant destroy  # cleanup

# Verify cluster
kubectl cluster-info
kubectl get nodes
kubectl get namespaces
```

### Create Namespaces

```bash
# Create all namespaces
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace prod
kubectl create namespace argocd
kubectl create namespace db-layer
kubectl create namespace vault
kubectl create namespace external-secrets-system

# Or use manifests
kubectl apply -f k8s/namespaces/
```

---

## 🚀 ArgoCD Installation

### Install ArgoCD

```bash
# Add Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Create namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
helm install argocd argo/argo-cd \
  -n argocd \
  --set server.insecure=true \
  --wait

# Alternative: using manifests
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Access ArgoCD UI

```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Change password
argocd login localhost:8080 --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
argocd account update-password --current-password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d) --new-password=<new-password>
```

### Create ArgoCD Project

```bash
# Apply project definition
kubectl apply -f argocd/argocd-project.yaml

# Apply RBAC configuration
kubectl apply -f argocd/argocd-rbac.yaml

# Verify
kubectl get appprojects -n argocd
kubectl get configmap argocd-rbac-cm -n argocd -o yaml
```

---

## 📦 ArgoCD Image Updater Setup

### Install Image Updater

```bash
# Add Argo Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install Image Updater
helm install argocd-image-updater argo/argocd-image-updater \
  -n argocd \
  --set argocdNamespace=argocd \
  --wait

# Verify installation
kubectl get pods -n argocd | grep image-updater
kubectl get deployment argocd-image-updater -n argocd
```

### Configure Image Updater

```bash
# Apply configuration
kubectl apply -f argocd/argocd-image-updater-config.yaml

# Update registry credentials
kubectl create secret generic docker-credentials \
  --from-literal=username=<docker-user> \
  --from-literal=password=<docker-password> \
  -n argocd \
  --dry-run=client -o yaml | kubectl apply -f -

# For GHCR
kubectl create secret generic ghcr-credentials \
  --from-literal=username=<github-user> \
  --from-literal=password=<github-token> \
  -n argocd \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart Image Updater
kubectl rollout restart deployment/argocd-image-updater -n argocd

# View logs
kubectl logs -f deployment/argocd-image-updater -n argocd
```

### Troubleshoot Image Updater

```bash
# Check Image Updater status
kubectl get deployment argocd-image-updater -n argocd
kubectl describe pod -l app.kubernetes.io/name=argocd-image-updater -n argocd

# Fix ConfigMap format error
kubectl patch configmap argocd-image-updater-config -n argocd -p '{"data":{"metrics.port":"8081"}}'

# Fix RBAC permissions
kubectl patch configmap argocd-rbac-cm -n argocd --type=merge -p '{
  "data": {
    "policy.default": "p, role:image-updater, applications, update, */*, allow\np, role:image-updater, applications, get, */*, allow"
  }
}'
```

---

## 🔐 External Secrets Setup

### Install External Secrets Operator

```bash
# Add Helm repository
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Create namespace
kubectl create namespace external-secrets-system --dry-run=client -o yaml | kubectl apply -f -

# Install External Secrets
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system \
  --wait

# Verify installation
kubectl get deployment -n external-secrets-system
```

### Configure SecretStore for Vault

```bash
# Apply SecretStore configuration
kubectl apply -f secrets/vault/external-secret-store.yaml

# Create service account
kubectl create serviceaccount external-secrets-sa \
  -n external-secrets-system \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify SecretStore
kubectl get secretstore -A
kubectl get clustersecretstore -A
```

### Create External Secret

```bash
# Apply ExternalSecret manifests
kubectl apply -f secrets/vault/external-secret.yaml

# Verify synced secrets
kubectl get externalsecret -n dev
kubectl get secret -n dev

# Check sync status
kubectl describe externalsecret my-app-secret -n dev
```

---

## 🔒 Vault Setup

### Deploy Vault

```bash
# Apply Vault configuration
kubectl apply -f secrets/vault/vault-config.yaml

# Wait for Vault pod
kubectl wait --for=condition=ready pod -l app=vault -n vault --timeout=300s

# Verify Vault is running
kubectl get pods -n vault
```

### Initialize Vault (One-time)

```bash
# Initialize Vault
kubectl exec -it vault-0 -n vault -- vault operator init

# This generates unseal keys and root token - SAVE SECURELY!

# Unseal Vault
kubectl exec -it vault-0 -n vault -- vault operator unseal <unseal-key-1>
kubectl exec -it vault-0 -n vault -- vault operator unseal <unseal-key-2>
kubectl exec -it vault-0 -n vault -- vault operator unseal <unseal-key-3>

# Check status
kubectl exec vault-0 -n vault -- vault status
```

### Create Secrets in Vault

```bash
# Login to Vault
kubectl exec -it vault-0 -n vault -- vault login <root-token>

# Enable Kubernetes auth
kubectl exec vault-0 -n vault -- vault auth enable kubernetes

# Create Kubernetes auth policy
kubectl exec vault-0 -n vault -- vault write auth/kubernetes/config \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token \
  kubernetes_host=https://kubernetes.default.svc:443 \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Create policy
kubectl exec vault-0 -n vault -- vault policy write external-secrets - <<EOF
path "secret/data/*" {
  capabilities = ["read", "list"]
}
EOF

# Create Kubernetes auth role
kubectl exec vault-0 -n vault -- vault write auth/kubernetes/role/external-secrets \
  bound_service_account_names=external-secrets-sa \
  bound_service_account_namespaces=external-secrets-system \
  policies=external-secrets \
  ttl=24h

# Store secrets
kubectl exec vault-0 -n vault -- vault kv put secret/dev/app \
  api-key=dev-api-key \
  db-password=dev-db-password

kubectl exec vault-0 -n vault -- vault kv put secret/staging/app \
  api-key=staging-api-key \
  db-password=staging-db-password

kubectl exec vault-0 -n vault -- vault kv put secret/production/app \
  api-key=prod-api-key \
  db-password=prod-db-password

# Verify secrets
kubectl exec vault-0 -n vault -- vault kv list secret/
kubectl exec vault-0 -n vault -- vault kv get secret/dev/app
```

### Access Vault UI

```bash
# Port forward to Vault UI
kubectl port-forward svc/vault-ui -n vault 8200:8200

# Open browser: http://localhost:8200
# Login with root token
```

---

## 📊 Helm Commands

### Validate Helm Charts

```bash
# Lint chart
helm lint helm/my-app-chart

# Template and validate
helm template my-app helm/my-app-chart \
  -f helm/my-app-chart/values-dev.yaml | kubectl apply -f - --dry-run=client

# Dry-run install
helm install my-app-dev helm/my-app-chart \
  -n dev \
  -f helm/my-app-chart/values-dev.yaml \
  --dry-run --debug
```

### Deploy with Helm

```bash
# Development
helm install my-app-dev helm/my-app-chart \
  -n dev \
  -f helm/my-app-chart/values.yaml \
  -f helm/my-app-chart/values-dev.yaml

# Staging
helm install my-app-staging helm/my-app-chart \
  -n staging \
  -f helm/my-app-chart/values.yaml \
  -f helm/my-app-chart/values-staging.yaml

# Production
helm install my-app-prod helm/my-app-chart \
  -n prod \
  -f helm/my-app-chart/values.yaml \
  -f helm/my-app-chart/values-prod.yaml
```

### Upgrade Helm Release

```bash
# Upgrade development
helm upgrade my-app-dev helm/my-app-chart \
  -n dev \
  -f helm/my-app-chart/values.yaml \
  -f helm/my-app-chart/values-dev.yaml

# Upgrade with rollback on error
helm upgrade my-app-dev helm/my-app-chart \
  -n dev \
  -f helm/my-app-chart/values-dev.yaml \
  --atomic --timeout 5m
```

### Rollback Helm Release

```bash
# List release history
helm history my-app-dev -n dev

# Rollback to previous release
helm rollback my-app-dev -n dev

# Rollback to specific revision
helm rollback my-app-dev 1 -n dev
```

---

## 🎯 ArgoCD Application Commands

### Create Applications

```bash
# Development application
kubectl apply -f argocd/applications/app-dev.yaml

# Staging application
kubectl apply -f argocd/applications/app-staging.yaml

# Production application
kubectl apply -f argocd/applications/app-prod.yaml

# Verify
kubectl get applications -n argocd
```

### Sync Applications

```bash
# Sync development
argocd app sync my-app-dev

# Sync staging
argocd app sync my-app-staging

# Sync production (manual)
argocd app sync my-app-prod

# Sync with prune
argocd app sync my-app-dev --prune

# Force sync
argocd app sync my-app-dev --force
```

### Get Application Status

```bash
# List all applications
argocd app list

# Get application details
argocd app get my-app-dev

# Get sync status
kubectl get application my-app-dev -n argocd -o yaml | grep status

# Watch sync progress
kubectl get application my-app-dev -n argocd -w
```

### Rollback Application

```bash
# Rollback to previous version
argocd app rollback my-app-dev

# Rollback to specific revision
argocd app rollback my-app-dev 1

# Verify rollback
argocd app get my-app-dev
kubectl get pods -n dev
```

---

## 🐳 Docker & Registry Commands

### Build Images

```bash
# Build frontend image
docker build -t ghcr.io/<org>/sherlock-logs-frontend:dev frontend/

# Build backend image
docker build -t ghcr.io/<org>/sherlock-logs-backend:dev backend/

# Build with BuildKit
docker buildx build -t ghcr.io/<org>/sherlock-logs-frontend:dev frontend/
```

### Push Images

```bash
# Login to GHCR
echo <github-token> | docker login ghcr.io -u <github-username> --password-stdin

# Push frontend
docker push ghcr.io/<org>/sherlock-logs-frontend:dev

# Push backend
docker push ghcr.io/<org>/sherlock-logs-backend:dev
```

### Tag Images

```bash
# Tag as latest
docker tag ghcr.io/<org>/sherlock-logs-frontend:dev ghcr.io/<org>/sherlock-logs-frontend:latest

# Tag with version
docker tag ghcr.io/<org>/sherlock-logs-frontend:dev ghcr.io/<org>/sherlock-logs-frontend:v1.0.0
```

---

## 📦 Kubectl Deployment Commands

### Deploy to Development

```bash
# Create namespace
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

# Apply manifests
kubectl apply -f k8s/namespaces/dev.yaml
kubectl apply -f argocd/applications/app-dev.yaml

# Verify
kubectl get pods -n dev
kubectl get application my-app-dev -n argocd
```

### Deploy to Staging

```bash
# Create namespace and quotas
kubectl apply -f k8s/namespaces/staging.yaml

# Create application
kubectl apply -f argocd/applications/app-staging.yaml

# Verify
kubectl rollout status deployment/my-app-staging-frontend -n staging
kubectl rollout status deployment/my-app-staging-backend -n staging
```

### Deploy to Production

```bash
# Create namespace and quotas
kubectl apply -f k8s/namespaces/prod.yaml

# Create application (manual sync)
kubectl apply -f argocd/applications/app-prod.yaml

# Manual sync when ready
argocd app sync my-app-prod --prune

# Verify
kubectl rollout status deployment/my-app-prod-frontend -n prod
kubectl rollout status deployment/my-app-prod-backend -n prod
```

---

## 📊 Monitoring & Logs

### Check Deployment Status

```bash
# All pods in namespace
kubectl get pods -n dev

# Deployment status
kubectl rollout status deployment/my-app-dev-frontend -n dev

# Watch deployments
kubectl rollout status deployment/my-app-dev-frontend -n dev --watch

# Get pod details
kubectl describe pod <pod-name> -n dev
```

### View Logs

```bash
# Frontend logs
kubectl logs deployment/my-app-dev-frontend -n dev

# Backend logs
kubectl logs deployment/my-app-dev-backend -n dev

# Follow logs
kubectl logs -f deployment/my-app-dev-frontend -n dev

# View previous logs (crashed pod)
kubectl logs deployment/my-app-dev-frontend -n dev --previous

# View all containers
kubectl logs deployment/my-app-dev-frontend -n dev --all-containers=true
```

### Check Resource Usage

```bash
# CPU and memory usage
kubectl top pods -n dev
kubectl top nodes

# Sort by CPU
kubectl top pods -n dev --sort-by=cpu

# Sort by memory
kubectl top pods -n dev --sort-by=memory
```

### HPA Status

```bash
# List HPAs
kubectl get hpa -n staging

# HPA details
kubectl describe hpa my-app-staging-frontend -n staging

# Watch HPA scaling
kubectl get hpa -n staging --watch
```

---

## 🧪 Testing Commands

### Test Helm Charts

```bash
# Lint
helm lint helm/my-app-chart

# Dry-run template
helm template my-app helm/my-app-chart \
  -f helm/my-app-chart/values-dev.yaml

# Validate
helm template my-app helm/my-app-chart \
  -f helm/my-app-chart/values-dev.yaml | kubectl apply -f - --dry-run=client -o json | jq .
```

### Test Database Connectivity

```bash
# Create test job
kubectl apply -f k8s/jobs/db-test-job.yaml

# Watch job progress
kubectl get jobs -n dev --watch

# View job logs
kubectl logs job/db-connectivity-test -n dev
```

### Test Ingress

```bash
# Port forward to Ingress
kubectl port-forward svc/my-app-staging-frontend -n staging 8080:80

# Test endpoint
curl -i http://localhost:8080/

# Check Ingress
kubectl get ingress -n staging
kubectl describe ingress -n staging
```

---

## 🔧 Troubleshooting Commands

### Debug Pod

```bash
# Get pod shell
kubectl exec -it deployment/my-app-dev-frontend -n dev -- /bin/sh

# Run debug pod
kubectl debug deployment/my-app-dev-frontend -n dev -it --image=alpine:latest

# Get pod environment
kubectl exec deployment/my-app-dev-backend -n dev -- env | grep DATABASE
```

### Check Secrets

```bash
# List secrets
kubectl get secrets -n dev

# View secret (encrypted)
kubectl get secret my-app-secret -n dev -o yaml

# Decode secret value
kubectl get secret my-app-secret -n dev -o jsonpath='{.data.api-key}' | base64 -d
```

### Network Debugging

```bash
# Test DNS resolution
kubectl run -it --rm debug --image=alpine:latest --restart=Never -- nslookup postgres.db-layer.svc.cluster.local

# Test connectivity
kubectl run -it --rm debug --image=alpine:latest --restart=Never -- wget -O- http://my-app-dev-backend:5000/health

# Check service endpoints
kubectl get endpoints my-app-dev-backend -n dev
```

### Events and Logs

```bash
# Kubernetes events (most recent first)
kubectl get events -n dev --sort-by='.lastTimestamp' | tail -20

# ArgoCD application controller logs
kubectl logs -f -l app.kubernetes.io/name=argocd-application-controller -n argocd

# All ArgoCD pod logs
kubectl logs -f -l app.kubernetes.io/instance=argocd -n argocd --all-containers=true
```

---

## ✨ Complete Setup Workflow

```bash
# 1. Initialize cluster
vagrant up
kubectl cluster-info

# 2. Install ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
kubectl create namespace argocd
helm install argocd argo/argo-cd -n argocd

# 3. Configure ArgoCD
kubectl apply -f argocd/argocd-project.yaml
kubectl apply -f argocd/argocd-rbac.yaml

# 4. Install Image Updater
helm install argocd-image-updater argo/argocd-image-updater -n argocd
kubectl apply -f argocd/argocd-image-updater-config.yaml

# 5. Install External Secrets
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace

# 6. Deploy Vault
kubectl apply -f secrets/vault/vault-config.yaml
kubectl exec -it vault-0 -n vault -- vault operator init

# 7. Deploy applications
kubectl apply -f k8s/namespaces/
kubectl apply -f argocd/applications/

# 8. Verify
kubectl get pods -A
make status
```

---

Last Updated: May 2026
