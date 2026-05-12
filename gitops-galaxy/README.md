# GitOps Galaxy - Enterprise-Grade Kubernetes GitOps Platform

A comprehensive, production-ready GitOps solution for managing multi-environment Kubernetes deployments using Helm, ArgoCD, and HashiCorp Vault.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Deployment](#deployment)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

GitOps Galaxy is a university project demonstrating enterprise-grade Kubernetes operations with:

- **Multi-environment deployments** (dev, staging, production)
- **Declarative infrastructure** as code using Helm and YAML
- **Automated GitOps** workflows with ArgoCD
- **Continuous image updates** via ArgoCD Image Updater
- **Secure secret management** with HashiCorp Vault and External Secrets
- **Automated CI/CD** pipelines with GitHub Actions
- **Resource quotas and network policies** for each environment
- **Horizontal Pod Autoscaling** for production workloads
- **Rollback capabilities** for safe deployments

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/Maliksaad231224/Gitops-ArgoCD-Vagrant-Environment.git
cd gitops-galaxy

# Install prerequisites
make cluster-setup
make argocd-install

# Deploy to development
make deploy-dev

# View status
make status
```

## 📦 Installation

```bash
# Complete installation
make cluster-setup
make argocd-install
make image-updater-setup
make external-secrets-setup
make vault-setup
```

## 🎯 Deployment

```bash
# Deploy to development
make deploy-dev

# Deploy to staging
make deploy-staging

# Deploy to production
make deploy-prod
```

## 📊 Status & Monitoring

```bash
# View all deployments
make status

# View logs
make logs-frontend-dev
make logs-backend-dev
make logs-argocd

# Test deployment
make test-helm
make test-connectivity
```

## 🔄 Rollback

```bash
# Rollback development
make rollback-dev

# Rollback staging
make rollback-staging

# Rollback production
make rollback-prod
```

## 🔧 Configuration

- **Helm Values**: `helm/my-app-chart/values-*.yaml`
- **ArgoCD Apps**: `argocd/applications/app-*.yaml`
- **Secrets**: `secrets/vault/` and `argocd/argocd-image-updater-config.yaml`
- **CI/CD**: `.github/workflows/deploy-*.yaml`

## 📚 Documentation

- [Architecture Guide](docs/architecture.md)
- [Helm Chart Documentation](docs/helm-chart.md)
- [ArgoCD Guide](docs/argocd-guide.md)
- [Troubleshooting](docs/troubleshooting.md)

## 🧪 Testing

```bash
# Test Helm charts
make test-helm

# Validate manifests
make test-manifests

# Test database
make test-connectivity
```

## 🐛 Troubleshooting

See [Troubleshooting Guide](docs/troubleshooting.md) for:
- ArgoCD Image Updater issues
- RBAC permission errors
- Database connection problems
- Image pull errors

## 📝 Project Structure

```
gitops-galaxy/
├── helm/                          # Helm charts
│   ├── my-app-chart/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   ├── values-staging.yaml
│   │   ├── values-prod.yaml
│   │   └── templates/
│   └── postgres/                  # Database chart
├── argocd/                        # ArgoCD configuration
│   ├── applications/
│   ├── argocd-project.yaml
│   ├── argocd-rbac.yaml
│   └── argocd-image-updater-config.yaml
├── k8s/                           # Kubernetes manifests
│   ├── namespaces/
│   └── jobs/
├── secrets/                       # Secret management
│   └── vault/
├── ci-cd/                         # CI/CD configuration
│   ├── github-actions/
│   └── scripts/
├── docs/                          # Documentation
├── Makefile                       # Common operations
└── README.md                      # This file
```

## 🔒 Security Features

- **RBAC**: Least-privilege access control
- **Network Policies**: Ingress/egress restrictions
- **Pod Security**: Non-root containers, security contexts
- **Secret Management**: Vault integration with External Secrets
- **Resource Quotas**: Namespace-level resource limits
- **Pod Disruption Budgets**: High availability protection

## 📈 Features

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| Auto-sync | ✓ | ✓ | Manual |
| HPA | ✗ | ✓ | ✓ |
| Resource Quotas | ✓ | ✓ | ✓ |
| Network Policies | ✓ | ✓ | ✓ |
| External Secrets | ✓ | ✓ | ✓ |
| Replicas | 1 | 2 | 3 |
| Ingress | ✗ | ✓ | ✓ |

## 🤝 Contributing

1. Create a feature branch
2. Make your changes
3. Test thoroughly
4. Submit a pull request

## 📧 Support

For help with:
- Installation: See `make help`
- Configuration: Check the docs folder
- Troubleshooting: See troubleshooting guide

---

**Version**: 1.0.0
**Last Updated**: May 2026
**Status**: Production-Ready