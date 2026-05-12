#!/bin/bash

# ArgoCD Validation & Monitoring Script
# Tests ArgoCD installation and watches sync status

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== ArgoCD GitOps Validation ===${NC}\n"

# 1. Check ArgoCD namespace
echo -e "${YELLOW}[1] Checking ArgoCD installation...${NC}"
if kubectl get namespace argocd &>/dev/null; then
    echo -e "${GREEN}✓ ArgoCD namespace exists${NC}"
else
    echo -e "${RED}✗ ArgoCD namespace not found${NC}"
    exit 1
fi

# 2. Check ArgoCD pods
echo -e "\n${YELLOW}[2] Checking ArgoCD pods...${NC}"
ARGOCD_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c "Running" || echo "0")
if [ "$ARGOCD_PODS" -gt 0 ]; then
    echo -e "${GREEN}✓ ArgoCD pods running: $ARGOCD_PODS${NC}"
    kubectl get pods -n argocd
else
    echo -e "${RED}✗ No running ArgoCD pods${NC}"
    exit 1
fi

# 3. Check applications
echo -e "\n${YELLOW}[3] Checking ArgoCD Applications...${NC}"
APPS=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
if [ "$APPS" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $APPS applications${NC}"
    kubectl get applications -n argocd
else
    echo -e "${YELLOW}⚠ No applications found (ensure you ran: make deploy-dev)${NC}"
fi

# 4. Check application sync status
echo -e "\n${YELLOW}[4] Checking application sync status...${NC}"
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REPO:.spec.source.repoURL

# 5. Check if deployments exist in all environments
echo -e "\n${YELLOW}[5] Checking deployed resources in all environments...${NC}"
for ENV in dev staging prod; do
    echo -e "\n${BLUE}--- Environment: $ENV ---${NC}"
    if kubectl get namespace $ENV &>/dev/null; then
        echo -e "${GREEN}✓ $ENV namespace exists${NC}"
        echo -e "\nDeployments:"
        kubectl get deployments -n $ENV || echo "No deployments yet"
        echo -e "\nPods:"
        kubectl get pods -n $ENV || echo "No pods yet"
        echo -e "\nServices:"
        kubectl get svc -n $ENV || echo "No services yet"
        echo -e "\nHPA Status:"
        kubectl get hpa -n $ENV 2>/dev/null || echo "No HPA configured"
    else
        echo -e "${YELLOW}⚠ $ENV namespace doesn't exist yet${NC}"
    fi
done

# 6. Check ArgoCD server accessibility
echo -e "\n${YELLOW}[6] Checking ArgoCD server connectivity...${NC}"
ARGOCD_READY=$(kubectl get deployment -n argocd argocd-server -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "$ARGOCD_READY" -gt 0 ]; then
    echo -e "${GREEN}✓ ArgoCD server ready${NC}"
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "ERROR")
    echo -e "\nArgoCD UI Access:"
    echo -e "  URL: https://localhost:8080"
    echo -e "  Username: admin"
    echo -e "  Password: ${ARGOCD_PASSWORD}"
    echo -e "\nTo access: kubectl port-forward -n argocd svc/argocd-server 8080:443"
else
    echo -e "${YELLOW}⚠ ArgoCD server not ready${NC}"
fi

# 7. Check git repo connectivity
echo -e "\n${YELLOW}[7] Checking Git repository configuration...${NC}"
if kubectl get configmap argocd-cm -n argocd &>/dev/null; then
    echo -e "${GREEN}✓ ArgoCD config found${NC}"
else
    echo -e "${YELLOW}⚠ ArgoCD config not found${NC}"
fi

# 8. Show logs for troubleshooting
echo -e "\n${YELLOW}[8] Recent ArgoCD logs:${NC}"
if kubectl get deployment -n argocd argocd-application-controller &>/dev/null; then
    echo -e "${BLUE}ArgoCD Application Controller:${NC}"
    kubectl logs -n argocd deployment/argocd-application-controller --tail=10 2>/dev/null || echo "No logs available"
else
    echo -e "${YELLOW}⚠ argocd-application-controller deployment not found${NC}"
fi
echo -e "${BLUE}ArgoCD Server:${NC}"
kubectl logs -n argocd deployment/argocd-server --tail=10 2>/dev/null || echo "No logs available"

# 9. Summary
echo -e "\n${BLUE}=== Validation Summary ===${NC}"
echo -e "${GREEN}✓ Validation complete${NC}"
echo -e "\n${YELLOW}Useful commands:${NC}"
echo "1. Access ArgoCD UI:"
echo "   kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo ""
echo "2. Deploy applications:"
echo "   cd gitops-galaxy && make deploy-all"
echo ""
echo "3. Watch ArgoCD apps sync:"
echo "   make watch-apps"
echo ""
echo "4. Check environment status:"
echo "   make status-dev, make status-staging, make status-prod"
echo ""
echo "3. Monitor sync in real-time:"
echo "   kubectl get applications -n argocd -w"
echo ""
echo "4. View detailed app status:"
echo "   kubectl describe application backend-app-dev -n argocd"
echo ""
echo "5. Test GitOps workflow:"
echo "   - Make a change and commit to GitHub"
echo "   - ArgoCD will automatically sync (check UI or run: kubectl get applications -n argocd -w)"
echo ""
