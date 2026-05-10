SHELL := /bin/bash

ARGOCD_NAMESPACE ?= argocd
VAGRANT_NAMESPACE ?= default
PROJECT_DIR := $(CURDIR)

.PHONY: help cluster-setup argocd-install image-updater-setup external-secrets-setup vault-setup \
	deploy-dev deploy-staging deploy-prod deploy-all status status-dev status-staging status-prod \
	logs-frontend-dev logs-backend-dev logs-argocd test-helm test-manifests test-connectivity test-db \
	validate-argocd watch-apps argocd-password sync-manual \\
	rollback-dev rollback-staging rollback-prod clean

help:
	@echo "GitOps Galaxy targets:"
	@echo "  make cluster-setup"
	@echo "  make argocd-install"
	@echo "  make image-updater-setup"
	@echo "  make external-secrets-setup"
	@echo "  make vault-setup"
	@echo "  make deploy-dev|deploy-staging|deploy-prod|deploy-all"
	@echo "  make status|status-dev|status-staging|status-prod"
	@echo "  make rollback-dev|rollback-staging|rollback-prod"
	@echo "  make test-helm|test-manifests|test-db|test-connectivity"
	@echo ""
	@echo "ArgoCD Validation (for testing GitOps):"
	@echo "  make validate-argocd      # Full health check"
	@echo "  make argocd-password      # Get admin password"
	@echo "  make watch-apps           # Watch app sync in real-time"
	@echo "  make sync-manual          # Manually trigger sync"
	@echo "  make logs-argocd          # View controller logs"

cluster-setup:
	bash ../scripts/setup-cluster.sh

argocd-install:
	kubectl create namespace $(ARGOCD_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	mkdir -p "$(PROJECT_DIR)/.helm/config" "$(PROJECT_DIR)/.helm/cache" "$(PROJECT_DIR)/.helm/data"
	HELM_CONFIG_HOME="$(PROJECT_DIR)/.helm/config" HELM_CACHE_HOME="$(PROJECT_DIR)/.helm/cache" HELM_DATA_HOME="$(PROJECT_DIR)/.helm/data" helm repo add argo https://argoproj.github.io/argo-helm
	HELM_CONFIG_HOME="$(PROJECT_DIR)/.helm/config" HELM_CACHE_HOME="$(PROJECT_DIR)/.helm/cache" HELM_DATA_HOME="$(PROJECT_DIR)/.helm/data" helm repo update
	HELM_CONFIG_HOME="$(PROJECT_DIR)/.helm/config" HELM_CACHE_HOME="$(PROJECT_DIR)/.helm/cache" HELM_DATA_HOME="$(PROJECT_DIR)/.helm/data" helm upgrade --install argocd argo/argo-cd \
		-n $(ARGOCD_NAMESPACE) \
		--create-namespace \
		--wait \
		--timeout 10m
	kubectl apply -f argocd/argocd-project.yaml
	kubectl apply -f argocd/argocd-rbac.yaml
	rm -rf argocd

image-updater-setup:
	mkdir -p "$(PROJECT_DIR)/.helm/config" "$(PROJECT_DIR)/.helm/cache" "$(PROJECT_DIR)/.helm/data"
	HELM_CONFIG_HOME="$(PROJECT_DIR)/.helm/config" HELM_CACHE_HOME="$(PROJECT_DIR)/.helm/cache" HELM_DATA_HOME="$(PROJECT_DIR)/.helm/data" helm repo add argo https://argoproj.github.io/argo-helm
	HELM_CONFIG_HOME="$(PROJECT_DIR)/.helm/config" HELM_CACHE_HOME="$(PROJECT_DIR)/.helm/cache" HELM_DATA_HOME="$(PROJECT_DIR)/.helm/data" helm repo update
	HELM_CONFIG_HOME="$(PROJECT_DIR)/.helm/config" HELM_CACHE_HOME="$(PROJECT_DIR)/.helm/cache" HELM_DATA_HOME="$(PROJECT_DIR)/.helm/data" helm upgrade --install argocd-image-updater argo/argocd-image-updater -n $(ARGOCD_NAMESPACE) --create-namespace
	kubectl apply -f ../manifests/argocd/image-updater-config.yaml

external-secrets-setup:
	mkdir -p "$(PROJECT_DIR)/.helm/config" "$(PROJECT_DIR)/.helm/cache" "$(PROJECT_DIR)/.helm/data"
	HELM_CONFIG_HOME="$(PROJECT_DIR)/.helm/config" HELM_CACHE_HOME="$(PROJECT_DIR)/.helm/cache" HELM_DATA_HOME="$(PROJECT_DIR)/.helm/data" helm repo add external-secrets https://charts.external-secrets.io || true
	HELM_CONFIG_HOME="$(PROJECT_DIR)/.helm/config" HELM_CACHE_HOME="$(PROJECT_DIR)/.helm/cache" HELM_DATA_HOME="$(PROJECT_DIR)/.helm/data" helm repo update
	HELM_CONFIG_HOME="$(PROJECT_DIR)/.helm/config" HELM_CACHE_HOME="$(PROJECT_DIR)/.helm/cache" HELM_DATA_HOME="$(PROJECT_DIR)/.helm/data" helm upgrade --install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace --set installCRDs=true --wait --timeout 10m
	# Wait for CRDs to be established with additional verification
	kubectl wait --for=condition=Established crd/clustersecretstores.external-secrets.io --timeout=120s
	kubectl wait --for=condition=Established crd/externalsecrets.external-secrets.io --timeout=120s
	# Additional wait for API server to recognize CRDs
	sleep 10
	# Verify CRDs are available
	kubectl api-resources | grep -q external-secrets || (echo "Waiting for external-secrets CRDs..." && sleep 10)
	# Retry applying ClusterSecretStore with retry logic
	for i in 1 2 3 4 5; do \
		if kubectl apply --server-side -f secrets/vault/external-secret-store.yaml 2>&1 | grep -q "serverside-applied"; then \
			echo "ClusterSecretStore applied successfully"; \
			break; \
		elif kubectl apply --server-side -f secrets/vault/external-secret-store.yaml 2>&1 | grep -q "no matches for kind"; then \
			echo "Attempt $$i: CRDs not ready yet, waiting 10 seconds..."; \
			sleep 10; \
		else \
			echo "Other error occurred, retrying..."; \
			sleep 5; \
		fi; \
	done
	# Apply external secret if ClusterSecretStore succeeded
	sleep 3
	kubectl apply --server-side -f secrets/vault/external-secret.yaml || true

vault-setup:
	kubectl apply -f secrets/vault/vault-config.yaml


deploy-dev:
	kubectl apply -f k8s/namespaces/dev.yaml
	kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f ../manifests/argocd/applications/app-of-apps.yaml
	kubectl apply -f ../manifests/argocd/applications/backend-app-dev.yaml
	kubectl apply -f ../manifests/argocd/applications/frontend-app-dev.yaml
	kubectl apply -f ../manifests/argocd/applications/postgres-app-dev.yaml
	kubectl apply -f ../manifests/argocd/applications/kubernetes-app.yaml

deploy-staging:
	kubectl apply -f k8s/namespaces/staging.yaml
	kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f ../manifests/argocd/applications/app-of-apps-staging.yaml
	kubectl apply -f ../manifests/argocd/applications/backend-app-staging.yaml
	kubectl apply -f ../manifests/argocd/applications/frontend-app-staging.yaml
	kubectl apply -f ../manifests/argocd/applications/postgres-app-staging.yaml
	kubectl apply -f ../manifests/argocd/applications/kubernetes-app.yaml

deploy-prod:
	kubectl apply -f k8s/namespaces/prod.yaml
	kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f ../manifests/argocd/applications/app-of-apps-prod.yaml
	kubectl apply -f ../manifests/argocd/applications/backend-app-prod.yaml
	kubectl apply -f ../manifests/argocd/applications/frontend-app-prod.yaml
	kubectl apply -f ../manifests/argocd/applications/postgres-app-prod.yaml
	kubectl apply -f ../manifests/argocd/applications/kubernetes-app.yaml

deploy-all: deploy-dev deploy-staging deploy-prod

status:
	kubectl get pods -A
	kubectl get svc -A
	kubectl get applications -n $(ARGOCD_NAMESPACE) || true

status-dev:
	kubectl get pods -n dev
	kubectl get svc -n dev
	kubectl get hpa -n dev || true

status-staging:
	kubectl get pods -n staging
	kubectl get svc -n staging
	kubectl get hpa -n staging || true

status-prod:
	kubectl get pods -n prod
	kubectl get svc -n prod
	kubectl get hpa -n prod || true

logs-frontend-dev:
	kubectl logs -n dev deployment/frontend --tail=100 || true

logs-backend-dev:
	kubectl logs -n dev deployment/backend --tail=100 || true

logs-argocd:
	kubectl logs -n $(ARGOCD_NAMESPACE) deployment/argocd-server --tail=100 || true


test-helm:
	helm lint helm/my-app-chart || true
	helm template sherlock-logs helm/my-app-chart -f helm/my-app-chart/values.yaml >/tmp/sherlock-logs.rendered.yaml
	test -s /tmp/sherlock-logs.rendered.yaml

test-manifests:
	kubectl apply --dry-run=client -f k8s/namespaces/dev.yaml
	kubectl apply --dry-run=client -f k8s/namespaces/staging.yaml
	kubectl apply --dry-run=client -f k8s/namespaces/prod.yaml

test-db:
	kubectl apply -f k8s/db-test-job.yaml
	sleep 5
	kubectl logs -f job/db-test-job -n default --timestamps=true || true

test-connectivity:
	kubectl get nodes
	kubectl get namespaces
	kubectl get pods -A

rollback-dev:
	bash ci-cd/scripts/rollback-deployment.sh dev

rollback-staging:
	bash ci-cd/scripts/rollback-deployment.sh staging

rollback-prod:
	bash ci-cd/scripts/rollback-deployment.sh prod

# ========== ArgoCD Validation & Testing ==========

validate-argocd:
	bash scripts/validate-argocd.sh

argocd-password:
	@echo "Getting ArgoCD admin password..."
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
	@echo ""
	@echo "ArgoCD UI: https://localhost:8080 (after port-forward)"
	@echo "Run: kubectl port-forward -n argocd svc/argocd-server 8080:443"

watch-apps:
	@echo "Watching ArgoCD applications (Ctrl+C to stop)..."
	kubectl get applications -n argocd -w

sync-manual:
	@echo "Manually syncing all applications..."
	@kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}' | xargs -I {} bash -c 'echo "Syncing {}..." && kubectl patch application {} -n argocd -p "{\"spec\":{\"syncPolicy\":{\"syncOptions\":[\"Refresh=hard\"]}}}" --type merge'
	@echo "Sync triggered. Check status with: make watch-apps"

argocd-ui-local:
	kubectl port-forward -n argocd svc/argocd-server 8080:443

# Troubleshooting: Fix common ArgoCD errors
argocd-check-repo:
	@echo "Checking if GitHub repo is configured in ArgoCD..."
	@kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository
	@echo ""
	@echo "If no repos listed, run: make setup-github-repo"

setup-github-repo:
	@echo "Setting up GitHub repository access in ArgoCD..."
	bash scripts/setup-github-repo.sh

argocd-app-details:
	@echo "Detailed app sync status (first app):"
	@kubectl get applications -n argocd | grep -E "backend|frontend" | head -1 | awk '{print $$1}' | xargs -I {} kubectl describe application {} -n argocd
	@echo ""
	@echo "Recent errors/warnings:"
	@kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="SyncError")].message}{"\n"}{end}'

argocd-fix-manifest-error:
	@echo "Fixing 'app path does not exist' error..."
	@echo "Step 1: Registering GitHub repository..."
	bash scripts/setup-github-repo.sh
	@echo ""
	@echo "Step 2: Refreshing applications..."
	kubectl get applications -n argocd -o name | xargs -I {} kubectl patch {} --type merge -p '{"spec":{"syncPolicy":{"syncOptions":["Refresh=hard"]}}}'
	@echo ""
	@echo "Step 3: Waiting for sync (60 seconds)..."
	@sleep 60
	@echo ""
	@echo "Step 4: Checking status..."
	@kubectl get applications -n argocd -o wide

argocd-troubleshoot:
	@echo "=== ArgoCD Troubleshooting Report ==="
	@echo ""
	@echo "1. ArgoCD Pods:"
	kubectl get pods -n argocd
	@echo ""
	@echo "2. Repository Configuration:"
	kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository -o wide
	@echo ""
	@echo "3. Applications Status:"
	kubectl get applications -n argocd -o wide
	@echo ""
	@echo "4. Recent Controller Logs:"
	kubectl logs -n argocd deployment/argocd-application-controller --tail=30 | grep -E "ERROR|error|Failed|failed" || echo "No errors in recent logs"
	@echo ""
	@echo "5. First Application Details:"
	@kubectl get applications -n argocd -o jsonpath='{.items[0].metadata.name}' | xargs -I {} kubectl describe application {} -n argocd | grep -A 20 "Status:"
	@echo ""
	@echo "Run this for detailed error: make argocd-app-details"

clean:
	kubectl delete -f ../manifests/argocd/applications/ --ignore-not-found
	kubectl delete namespace dev staging prod database --ignore-not-found
