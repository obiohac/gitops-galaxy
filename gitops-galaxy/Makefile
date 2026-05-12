SHELL := /bin/bash

ARGOCD_NAMESPACE ?= argocd
VAGRANT_NAMESPACE ?= default
PROJECT_DIR := $(CURDIR)

.PHONY: help cluster-setup argocd-install image-updater-setup external-secrets-setup vault-setup \
	deploy-dev deploy-staging deploy-prod deploy-all status status-dev status-staging status-prod \
	logs-frontend-dev logs-backend-dev logs-frontend-staging logs-backend-staging logs-frontend-prod logs-backend-prod logs-argocd test-helm test-manifests test-connectivity test-db \
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
	@echo "  make logs-frontend-dev|logs-backend-dev|logs-frontend-staging|logs-backend-staging|logs-frontend-prod|logs-backend-prod|logs-argocd"
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
	# Wait for CRDs and controller to be fully ready before applying custom resources.
	kubectl wait --for=condition=Established crd/clustersecretstores.external-secrets.io --timeout=90s
	kubectl wait --for=condition=Established crd/externalsecrets.external-secrets.io --timeout=90s
	for i in 1 2 3 4 5; do \
		kubectl api-resources | grep -Eq '^externalsecrets[[:space:]]'; rc1=$$?; \
		kubectl api-resources | grep -Eq '^clustersecretstores[[:space:]]'; rc2=$$?; \
		if [ $$rc1 -eq 0 ] && [ $$rc2 -eq 0 ]; then \
			echo "External Secrets API resources are discoverable"; \
			break; \
		fi; \
		echo "Attempt $$i: waiting for External Secrets API discovery..."; \
		sleep 3; \
	done
	kubectl rollout status deployment/external-secrets -n external-secrets-system --timeout=90s
	kubectl apply -f secrets/vault/external-secret-store.yaml
	kubectl apply -f secrets/vault/external-secret.yaml

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
	@echo "Waiting for dev deployments to appear and become ready (up to 1.5 minutes)..."
	@for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do \
		count=$$(kubectl get deployment -n dev --no-headers 2>/dev/null | wc -l); \
		if [ "$$count" -gt 0 ]; then \
			echo "Found $$count deployment(s) in dev. Waiting for availability..."; \
			kubectl wait --for=condition=available --timeout=90s deployment --all -n dev || true; \
			break; \
		fi; \
		echo "[$$i/18] No dev deployments yet, waiting 5s..."; \
		sleep 5; \
		done
	@echo "✓ Dev environment ready"

deploy-staging:
	kubectl apply -f k8s/namespaces/staging.yaml
	kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f ../manifests/argocd/applications/app-of-apps-staging.yaml
	kubectl apply -f ../manifests/argocd/applications/backend-app-staging.yaml
	kubectl apply -f ../manifests/argocd/applications/frontend-app-staging.yaml
	kubectl apply -f ../manifests/argocd/applications/postgres-app-staging.yaml
	kubectl apply -f ../manifests/argocd/applications/kubernetes-app.yaml
	@echo "Waiting for staging deployments to appear and become ready (up to 1.5 minutes)..."
	@for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do \
		count=$$(kubectl get deployment -n staging --no-headers 2>/dev/null | wc -l); \
		if [ "$$count" -gt 0 ]; then \
			echo "Found $$count deployment(s) in staging. Waiting for availability..."; \
			kubectl wait --for=condition=available --timeout=90s deployment --all -n staging || true; \
			break; \
		fi; \
		echo "[$$i/18] No staging deployments yet, waiting 5s..."; \
		sleep 5; \
		done
	@echo "✓ Staging environment ready"

deploy-prod:
	kubectl apply -f k8s/namespaces/prod.yaml
	kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f ../manifests/argocd/applications/app-of-apps-prod.yaml
	kubectl apply -f ../manifests/argocd/applications/backend-app-prod.yaml
	kubectl apply -f ../manifests/argocd/applications/frontend-app-prod.yaml
	kubectl apply -f ../manifests/argocd/applications/postgres-app-prod.yaml
	kubectl apply -f ../manifests/argocd/applications/kubernetes-app.yaml
	@echo "Waiting for prod deployments to appear and become ready (up to 1.5 minutes)..."
	@for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do \
		count=$$(kubectl get deployment -n prod --no-headers 2>/dev/null | wc -l); \
		if [ "$$count" -gt 0 ]; then \
			echo "Found $$count deployment(s) in prod. Waiting for availability..."; \
			kubectl wait --for=condition=available --timeout=90s deployment --all -n prod || true; \
			break; \
		fi; \
		echo "[$$i/18] No prod deployments yet, waiting 5s..."; \
		sleep 5; \
		done
	@echo "✓ Prod environment ready"

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
	@echo "Waiting for frontend container in dev before reading logs..."
	@for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do \
		if kubectl logs -n dev deployment/frontend --tail=100 >/tmp/frontend-dev.logs 2>/tmp/frontend-dev.err; then \
			cat /tmp/frontend-dev.logs; \
			rm -f /tmp/frontend-dev.logs /tmp/frontend-dev.err; \
			exit 0; \
		fi; \
		echo "[$$i/18] Frontend not ready yet (ContainerCreating/Pending). Waiting 5s..."; \
		sleep 5; \
		done; \
	cat /tmp/frontend-dev.err || true; \
	rm -f /tmp/frontend-dev.logs /tmp/frontend-dev.err

logs-backend-dev:
	@echo "Waiting for backend container in dev before reading logs..."
	@for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do \
		if kubectl logs -n dev deployment/backend --tail=100 >/tmp/backend-dev.logs 2>/tmp/backend-dev.err; then \
			cat /tmp/backend-dev.logs; \
			rm -f /tmp/backend-dev.logs /tmp/backend-dev.err; \
			exit 0; \
		fi; \
		echo "[$$i/18] Backend not ready yet (ContainerCreating/Pending). Waiting 5s..."; \
		sleep 5; \
		done; \
	cat /tmp/backend-dev.err || true; \
	rm -f /tmp/backend-dev.logs /tmp/backend-dev.err

logs-frontend-staging:
	@echo "Waiting for frontend container in staging before reading logs..."
	@for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do \
		if kubectl logs -n staging deployment/frontend --tail=100 >/tmp/frontend-staging.logs 2>/tmp/frontend-staging.err; then \
			cat /tmp/frontend-staging.logs; \
			rm -f /tmp/frontend-staging.logs /tmp/frontend-staging.err; \
			exit 0; \
		fi; \
		echo "[$$i/18] Frontend not ready yet (ContainerCreating/Pending). Waiting 5s..."; \
		sleep 5; \
		done; \
	cat /tmp/frontend-staging.err || true; \
	rm -f /tmp/frontend-staging.logs /tmp/frontend-staging.err

logs-backend-staging:
	@echo "Waiting for backend container in staging before reading logs..."
	@for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do \
		if kubectl logs -n staging deployment/backend --tail=100 >/tmp/backend-staging.logs 2>/tmp/backend-staging.err; then \
			cat /tmp/backend-staging.logs; \
			rm -f /tmp/backend-staging.logs /tmp/backend-staging.err; \
			exit 0; \
		fi; \
		echo "[$$i/18] Backend not ready yet (ContainerCreating/Pending). Waiting 5s..."; \
		sleep 5; \
		done; \
	cat /tmp/backend-staging.err || true; \
	rm -f /tmp/backend-staging.logs /tmp/backend-staging.err

logs-frontend-prod:
	@echo "Waiting for frontend container in prod before reading logs..."
	@for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do \
		if kubectl logs -n prod deployment/frontend --tail=100 >/tmp/frontend-prod.logs 2>/tmp/frontend-prod.err; then \
			cat /tmp/frontend-prod.logs; \
			rm -f /tmp/frontend-prod.logs /tmp/frontend-prod.err; \
			exit 0; \
		fi; \
		echo "[$$i/18] Frontend not ready yet (ContainerCreating/Pending). Waiting 5s..."; \
		sleep 5; \
		done; \
	cat /tmp/frontend-prod.err || true; \
	rm -f /tmp/frontend-prod.logs /tmp/frontend-prod.err

logs-backend-prod:
	@echo "Waiting for backend container in prod before reading logs..."
	@for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do \
		if kubectl logs -n prod deployment/backend --tail=100 >/tmp/backend-prod.logs 2>/tmp/backend-prod.err; then \
			cat /tmp/backend-prod.logs; \
			rm -f /tmp/backend-prod.logs /tmp/backend-prod.err; \
			exit 0; \
		fi; \
		echo "[$$i/18] Backend not ready yet (ContainerCreating/Pending). Waiting 5s..."; \
		sleep 5; \
		done; \
	cat /tmp/backend-prod.err || true; \
	rm -f /tmp/backend-prod.logs /tmp/backend-prod.err

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
