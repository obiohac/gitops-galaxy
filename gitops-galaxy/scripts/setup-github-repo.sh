#!/bin/bash

# Configure GitHub repository in ArgoCD

set -e

GITHUB_REPO="https://github.com/obiohac/gitops-galaxy"
GITHUB_USER="${GITHUB_USER:-Maliksaad231224}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"  # Set via environment variable

echo "Configuring GitHub repository in ArgoCD..."

# Option 1: Public repository (no auth needed)
echo "[1] Adding repository (public access)..."
kubectl create secret generic github-credentials \
  --from-literal=url="$GITHUB_REPO" \
  --from-literal=password="" \
  --from-literal=username="not-used" \
  -n argocd \
  --dry-run=client -o yaml | kubectl apply -f -

# Option 2: Configure via ArgoCD CLI (if available)
if command -v argocd &> /dev/null; then
  echo "[2] Configuring via argocd CLI..."
  
  # Get ArgoCD server password if needed
  ARGOCD_ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
  ARGOCD_SERVER=$(kubectl -n argocd get svc argocd-server -o jsonpath='{.spec.clusterIP}'):443
  
  # Login to ArgoCD
  echo "Logging in to ArgoCD..."
  argocd login "$ARGOCD_SERVER" --username admin --password "$ARGOCD_ADMIN_PASSWORD" --insecure || true
  
  # Add repository
  echo "Adding repository to ArgoCD..."
  argocd repo add "$GITHUB_REPO" --type git --insecure-skip-server-verification || echo "Repository already exists or error adding"
  
  # List repositories
  echo "[3] Configured repositories:"
  argocd repo list || echo "Could not list repos"
else
  echo "⚠ argocd CLI not found. Using kubectl to apply repository config..."
fi

# Option 3: Create Repository CR (custom resource) for ArgoCD
echo "[3] Creating ArgoCD Repository custom resource..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: github-gitops-galaxy
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: $GITHUB_REPO
  password: ""
  username: not-used
EOF

echo "✓ Repository configured!"
echo ""
echo "Verifying ArgoCD can access the repository..."
kubectl logs -n argocd deployment/argocd-application-controller --tail=20 | grep -i "github\|repository" || echo "No recent logs, repository should work now"

echo ""
echo "Next steps:"
echo "1. Wait 30 seconds for ArgoCD to pick up the change"
echo "2. Check app status: kubectl get applications -n argocd"
echo "3. If still failing, check detailed logs:"
echo "   kubectl describe application backend-app-dev -n argocd"
echo "4. Check controller logs:"
echo "   kubectl logs -n argocd deployment/argocd-application-controller -f"
