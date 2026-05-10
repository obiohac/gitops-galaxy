# Architecture Guide

## System Overview

GitOps Galaxy uses a declarative, Git-driven architecture:

**Git Repository** → **GitHub Actions** → **Container Registry** → **ArgoCD** → **Kubernetes**

## Key Components

### 1. Git Repository (Source of Truth)
- Helm charts and values files
- ArgoCD application manifests
- Kubernetes manifests
- CI/CD workflow definitions

### 2. GitHub Actions (CI/CD)
- Builds Docker images
- Pushes to container registry
- Updates Helm values
- Commits changes back to Git

### 3. Container Registry (GHCR)
- Stores frontend/backend images
- Supports multiple tags (staging, prod, v1.0.0)
- Image scanning and vulnerability checks

### 4. ArgoCD (GitOps Controller)
- Monitors Git repository
- Syncs desired state to cluster
- Automatic or manual deployment
- Rollback capability

### 5. Kubernetes Cluster
- Runs applications across namespaces
- dev, staging, prod environments
- PostgreSQL database (db-layer namespace)
- Vault for secret management

## Multi-Environment Architecture

### Development (dev namespace)
- Single replicas, minimal resources
- Auto-sync from Git
- Direct database access
- No Ingress required

### Staging (staging namespace)
- 2 replicas with HPA
- Ingress with staging domain
- Database access
- Security policies enabled

### Production (prod namespace)
- 3 replicas with HPA (up to 10)
- Ingress with production domain
- High resource limits
- Manual ArgoCD sync
- Backup and disaster recovery

## Data Flow

```
Developer Code Commit
    ↓
GitHub Actions Trigger
    ├─ Build Docker images
    ├─ Push to GHCR
    ├─ Update Helm values
    └─ Commit to Git
        ↓
ArgoCD Detects Change
    ├─ Poll Git repository (3min interval)
    ├─ Compare with cluster state
    └─ Sync manifests
        ↓
Kubernetes Applies Changes
    ├─ Create/update pods
    ├─ Run health checks
    └─ Complete deployment
```

## Security Architecture

### RBAC
- ArgoCD Server: Read applications, manage users
- Application Controller: Deploy apps, manage resources
- Image Updater: Update application specs
- External Secrets: Fetch Vault secrets

### Secrets Management
```
Vault Secret Store
    ↓
External Secrets Operator
    ↓
Kubernetes Secret (auto-created)
    ↓
Pod environment variables/volumes
```

### Network Policies
- Default deny all traffic
- Allow DNS egress
- Allow pod-to-pod communication
- Allow Ingress from external

## Component Interactions

```
┌─────────────────────────────────────────────────────┐
│           GitHub Repository (Git)                   │
│  helm/, argocd/, k8s/, .github/workflows/           │
└─────────────────────────────────────────────────────┘
         ↑ (update image refs)  ↓ (read manifests)
         │                      │
    ┌────┴──────────────────────┴────┐
    │   GitHub Actions (CI/CD)       │
    │  • Build images               │
    │  • Push to registry           │
    │  • Update values files        │
    └────┬──────────────────────────┬────┐
         │                          │    │
         ↓                          ↓    ↓
┌──────────────────┐    ┌──────────────────────┐
│   GHCR Registry  │    │  Kubernetes Cluster  │
│  • Frontend img  │    │                      │
│  • Backend img   │    │  ┌────────────────┐  │
└──────────────────┘    │  │ ArgoCD (argocd)│  │
                        │  │ • Server       │  │
                        │  │ • Controller   │  │
                        │  │ • Image Upd.   │  │
                        │  └────────────────┘  │
                        │  ┌────────────────┐  │
                        │  │ dev namespace  │  │
                        │  │ • Frontend pod │  │
                        │  │ • Backend pod  │  │
                        │  └────────────────┘  │
                        │  ┌────────────────┐  │
                        │  │ staging ns     │  │
                        │  │ • Frontend (2) │  │
                        │  │ • Backend (2)  │  │
                        │  └────────────────┘  │
                        │  ┌────────────────┐  │
                        │  │ prod namespace │  │
                        │  │ • Frontend (3) │  │
                        │  │ • Backend (3)  │  │
                        │  └────────────────┘  │
                        │  ┌────────────────┐  │
                        │  │ db-layer ns    │  │
                        │  │ • PostgreSQL   │  │
                        │  └────────────────┘  │
                        │  ┌────────────────┐  │
                        │  │ vault ns       │  │
                        │  │ • Vault server │  │
                        │  └────────────────┘  │
                        └──────────────────────┘
```

## Environment Comparison

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| **Replicas** | 1 | 2 | 3 |
| **HPA** | No | Yes (5 max) | Yes (10 max) |
| **Ingress** | No | Yes | Yes |
| **Sync** | Auto | Auto | Manual |
| **CPU Req** | 100m | 200m | 500m |
| **Memory Req** | 64Mi | 128Mi | 256Mi |
| **Quotas** | 1 CPU | 2 CPU | 8 CPU |
| **Backup** | No | No | Daily |

## Technology Stack

- **Orchestration**: Kubernetes (k3s)
- **Package Mgmt**: Helm 3
- **GitOps CD**: ArgoCD
- **Image Tracking**: ArgoCD Image Updater
- **CI/CD**: GitHub Actions
- **Secrets**: HashiCorp Vault + External Secrets
- **Database**: PostgreSQL
- **Frontend**: Nginx
- **Backend**: Flask API
- **Registry**: GitHub Container Registry (GHCR)

## Deployment Safety Features

### Pre-deployment
- Helm chart linting
- YAML validation
- Docker image scanning
- Test in dev first

### During Deployment
- Health checks (liveness/readiness)
- Gradual rollout
- Pod Disruption Budgets
- Resource quotas

### Post-deployment
- Verify rollout status
- Monitor logs/metrics
- Automated rollback on failure
- Manual rollback capability

---

Last Updated: May 2026


Add your description here.

## Usage

How to use this architecture.

## Examples

```
// Code examples here
```