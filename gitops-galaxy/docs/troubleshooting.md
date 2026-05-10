# Troubleshooting Guide

## Common Issues

### 1. ArgoCD Image Updater ConfigMap Error

```bash
# Fix: Convert all data values to strings
kubectl patch configmap argocd-image-updater-config -n argocd -p '{"data":{"metrics.port":"8081"}}'
kubectl rollout restart deployment/argocd-image-updater -n argocd
```

### 2. RBAC Permission Denied

```bash
# Fix: Update RBAC policies
kubectl patch configmap argocd-rbac-cm -n argocd --type=merge -p '{
  "data": {"policy.default": "p, role:image-updater, applications, update, */*, allow"}
}'
```

### 3. Backend Cannot Connect to Database

```bash
# Test connectivity
kubectl run -it --rm debug --image=postgres:16 --restart=Never -- \
  psql -h postgres.db-layer.svc.cluster.local -U sherlock -d sherlock_db -c "SELECT 1"

# Check secret
kubectl get secret postgres-secret-dev -n dev
```

### 4. Application OutOfSync

```bash
# Manual sync
argocd app sync my-app-dev

# Force sync
argocd app sync my-app-dev --force

# Refresh
argocd app get my-app-dev --refresh
```

### 5. Image Pull Errors

```bash
# Create image pull secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<user> \
  --docker-password=<token> \
  -n dev --dry-run=client -o yaml | kubectl apply -f -

# Patch ServiceAccount
kubectl patch serviceaccount default -n dev -p '{"imagePullSecrets":[{"name":"ghcr-secret"}]}'
```

### 6. External Secrets Not Syncing

```bash
# Verify Vault connectivity
kubectl run -it --rm vault-debug --image=vault:latest --restart=Never -- \
  vault status -address=http://vault.vault.svc.cluster.local:8200

# Create secret in Vault
kubectl exec -it vault-0 -n vault -- vault kv put secret/dev/app api-key=test-value
```

### 7. HPA Not Scaling

```bash
# Install Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify metrics
kubectl top pods -n staging
kubectl get hpa -n staging
```

## Debugging Commands

```bash
# Pod logs
kubectl logs deployment/my-app-dev-frontend -n dev -f

# Pod shell
kubectl exec -it deployment/my-app-dev-frontend -n dev -- /bin/sh

# Check pod resources
kubectl top pods -n dev

# View pod events
kubectl describe pod <pod-name> -n dev

# ArgoCD logs
kubectl logs -f -l app.kubernetes.io/name=argocd-application-controller -n argocd
```

## Verification Checklist

- Cluster healthy: `kubectl cluster-info`
- Nodes ready: `kubectl get nodes`
- ArgoCD running: `kubectl get pods -n argocd`
- Metrics Server: `kubectl get deployment metrics-server -n kube-system`
- All namespaces: `kubectl get namespaces`
- No pending pods: `kubectl get pods -A | grep Pending`
- Services have IPs: `kubectl get svc -n dev`

---

For more details, check logs with `kubectl logs -f <pod> -n <namespace>`

How to use this troubleshooting.

## Examples

```
// Code examples here
```