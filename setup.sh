cd /home/vagrant/project/gitops-galaxy
sudo apt install make

echo "========================================="
echo "GitOps Galaxy - Complete Setup"
echo "========================================="
echo ""

echo "Step 1: Setting up Kubernetes cluster..."
make cluster-setup
echo "✓ Cluster setup complete"
echo ""

echo "Step 2: Installing ArgoCD..."
make argocd-install
echo "✓ ArgoCD installed"
echo ""

echo "Step 3: Setting up ArgoCD Image Updater..."
make image-updater-setup
echo "✓ ArgoCD Image Updater installed"
echo ""

echo "Step 4: Setting up External Secrets..."
make external-secrets-setup
echo "✓ External Secrets installed"
echo ""

echo "Step 5: Setting up Vault..."
make vault-setup
echo "✓ Vault configured"
echo ""

echo "Step 6: Configuring GitHub repository in ArgoCD..."
make setup-github-repo
echo "✓ GitHub repository configured"
echo ""

echo "Step 7: Testing Helm charts..."
make test-helm
echo "✓ Helm templates validated"
echo ""

echo "Step 8: Testing Kubernetes manifests..."
make test-manifests
echo "✓ Manifests validated"
echo ""

echo "Step 9: Testing database connection..."
make test-db
echo "✓ Database test passed"
echo ""

echo "Step 10: Deploying all environments (dev, staging, prod)..."
make deploy-all
echo "✓ All environments deployed"
echo ""

echo "Step 11: Checking overall deployment status..."
make status
echo ""

echo "Step 12: Checking dev environment status..."
make status-dev
echo ""

echo "Step 13: Checking staging environment status..."
make status-staging
echo ""

echo "Step 14: Checking prod environment status..."
make status-prod
echo ""

echo "Step 15: Checking GitHub repository configuration..."
make argocd-check-repo
echo ""

echo "Step 16: Running comprehensive ArgoCD troubleshooting..."
make argocd-troubleshoot
echo ""

echo "Step 17: Validating ArgoCD setup..."
make validate-argocd
echo ""

echo "Step 18: Testing cluster connectivity..."
make test-connectivity
echo ""

echo "Step 19: Retrieving frontend logs (dev)..."
make logs-frontend-dev
echo ""

echo "Step 20: Retrieving backend logs (dev)..."
make logs-backend-dev
echo ""

echo "Step 21: Retrieving frontend logs (staging)..."
make logs-frontend-staging || true
echo ""

echo "Step 22: Retrieving backend logs (staging)..."
make logs-backend-staging || true
echo ""

echo "Step 23: Retrieving frontend logs (prod)..."
make logs-frontend-prod || true
echo ""

echo "Step 24: Retrieving backend logs (prod)..."
make logs-backend-prod || true
echo ""

echo "Step 25: Retrieving ArgoCD logs..."
make logs-argocd

echo "========================================="
echo "✓ Cluster setup complete!"
echo "========================================="
echo ""
echo "ArgoCD Access:"
echo "  Admin Password:"
make argocd-password
echo ""
echo "Access ArgoCD UI:"
echo "  1. Run: kubectl port-forward -n argocd svc/argocd-server 8080:443 &"
echo "  2. Open: https://localhost:8080"
echo "  3. Username: admin"
echo "  4. Password: (from above)"
echo ""
echo "Kubeconfig available at: /vagrant/kubeconfig"
echo ""
echo "To use kubectl as vagrant user:"
echo "  export KUBECONFIG=/home/vagrant/.kube/config"
echo ""


