kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
export HELM_CONFIG_HOME="${HELM_CONFIG_HOME:-/tmp/helm-config}"
export HELM_CACHE_HOME="${HELM_CACHE_HOME:-/tmp/helm-cache}"
export HELM_DATA_HOME="${HELM_DATA_HOME:-/tmp/helm-data}"
mkdir -p "$HELM_CONFIG_HOME" "$HELM_CACHE_HOME" "$HELM_DATA_HOME"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd \
	--namespace argocd \
	--create-namespace \
	--wait \
	--timeout 10m
# 1. Start Port Forwarding in the background
kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &

# 2. Wait a couple of seconds for the connection to initialize
sleep 2

# 3. Retrieve and print the password
echo "------------------------------------------------"
echo "ArgoCD UI: https://localhost:8080"
echo "Username: admin"
echo -n "Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
echo "------------------------------------------------"

curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

chmod +x argocd
if [ -e /usr/local/bin/argocd ] && [ ! -f /usr/local/bin/argocd ]; then
	echo "Skipping Argo CD CLI install: /usr/local/bin/argocd already exists and is not a file."
else
	sudo install -m 0755 argocd /usr/local/bin/argocd
fi