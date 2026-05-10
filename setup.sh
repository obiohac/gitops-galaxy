cd /home/vagrant/project/gitops-galaxy
sudo apt install make
./scripts/setup-cluster.sh && echo "syntax ok"


make cluster-setup
scripts/argocd.sh;
make -n argocd-install

make image-updater-setup
make external-secrets-setup
make vault-setup

# Register GitHub repository with ArgoCD so it can pull manifests
echo "Registering GitHub repository with ArgoCD..."
kubectl create secret generic github-repo \
  --from-literal=type=git \
  --from-literal=url=https://github.com/obiohac/gitops-galaxy \
  -n argocd \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl patch secret github-repo -n argocd -p '{"metadata":{"labels":{"argocd.argoproj.io/secret-type":"repository"}}}' --type merge
kubectl get secret github-repo -n argocd -o jsonpath='{.metadata.labels.argocd\.argoproj\.io/secret-type}{"\n"}'
echo "✓ GitHub repository registered with ArgoCD"
sleep 5
kubectl rollout restart deployment -n argocd --all
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=120s
sleep 20
make postgres-setup
sleep 20
echo "waiting for postgresql to complete setup"
make test-db
make deploy-dev
make deploy-staging
make deploy-prod
make status
make status-dev
make status-staging
make status-prod
make logs-frontend-dev
make logs-backend-dev



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

