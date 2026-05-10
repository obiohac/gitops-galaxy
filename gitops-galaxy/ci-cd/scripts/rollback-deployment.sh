#!/bin/bash
# rollback-deployment.sh
# Performs safe rollback of ArgoCD applications with verification

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
ENVIRONMENT=${1:-""}
REVISION=${2:-""}  # Optional revision number

# Validate input
if [[ -z "$ENVIRONMENT" ]]; then
    echo -e "${RED}Usage: $0 <environment> [revision]${NC}"
    echo "Environments: dev, staging, prod"
    echo "Example: $0 staging 1"
    exit 1
fi

# Map environment to application name
case "$ENVIRONMENT" in
    dev)
        APP_NAME="my-app-dev"
        NAMESPACE="dev"
        ;;
    staging)
        APP_NAME="my-app-staging"
        NAMESPACE="staging"
        ;;
    prod)
        APP_NAME="my-app-prod"
        NAMESPACE="prod"
        ;;
    *)
        echo -e "${RED}Unknown environment: $ENVIRONMENT${NC}"
        exit 1
        ;;
esac

echo -e "${YELLOW}Rolling back $ENVIRONMENT ($APP_NAME)...${NC}"

# Get current revision
CURRENT_REVISION=$(kubectl get application "$APP_NAME" -n argocd -o jsonpath='{.status.operationState.finishedAt}' | wc -c)

# Perform rollback
if [[ -n "$REVISION" ]]; then
    echo -e "${YELLOW}Rolling back to revision: $REVISION${NC}"
    argocd app rollback "$APP_NAME" "$REVISION" --grpc-web
else
    echo -e "${YELLOW}Rolling back to previous revision...${NC}"
    argocd app rollback "$APP_NAME" --grpc-web
fi

# Wait for rollback to complete
echo -e "${YELLOW}Waiting for rollback to complete...${NC}"
sleep 5

# Verify rollback
echo -e "${YELLOW}Verifying rollback...${NC}"

# Check deployment status
FRONTEND_READY=$(kubectl get deployment "my-app-${ENVIRONMENT}-frontend" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")
BACKEND_READY=$(kubectl get deployment "my-app-${ENVIRONMENT}-backend" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")

if [[ "$FRONTEND_READY" == "True" && "$BACKEND_READY" == "True" ]]; then
    echo -e "${GREEN}✓ Rollback successful!${NC}"
    echo -e "${GREEN}Frontend: Ready${NC}"
    echo -e "${GREEN}Backend: Ready${NC}"
    exit 0
else
    echo -e "${RED}✗ Rollback may have failed!${NC}"
    echo -e "${RED}Frontend: $FRONTEND_READY${NC}"
    echo -e "${RED}Backend: $BACKEND_READY${NC}"
    exit 1
fi
