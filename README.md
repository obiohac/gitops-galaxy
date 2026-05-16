# Gitops-galaxy Project

[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.24+-326CE5?style=flat-square&logo=kubernetes)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm-3.12+-0F1689?style=flat-square&logo=helm)](https://helm.sh/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-Latest-1F76C2?style=flat-square)](https://argoproj.github.io/cd/)
[![Docker](https://img.shields.io/badge/Docker-Latest-2496ED?style=flat-square&logo=docker)](https://www.docker.com/)

Production-ready GitOps reference implementation for the gitops-galaxy application, deployed with ArgoCD, Helm, and Kubernetes across development, staging, and production environments.

## Table of Contents

- [Project Overview](#project-overview)
- [Features Implemented](#features-implemented)
- [Setup and Installation](#setup-and-installation)
- [Usage Guide](#usage-guide)
- [Project Structure](#project-structure)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Project Overview

This repository demonstrates a complete GitOps workflow for a full-stack application. Git is the source of truth, ArgoCD reconciles desired state into the cluster, and Helm provides reusable templates for each environment.

The application stack includes:

- Frontend: JavaScript application served through Nginx
- Backend: Python Flask API
- Database: PostgreSQL with persistent storage

The project is organized to support:

- Declarative Kubernetes deployments
- Environment-specific configuration for dev, staging, and prod
- Automated image updates through ArgoCD Image Updater
- Reproducible local setup using Vagrant

## Features Implemented

- GitOps-based deployment workflow with ArgoCD
- Multi-environment application manifests for dev, staging, and production
- Reusable Helm chart for the gitops-galaxy application
- PostgreSQL deployment with persistent volumes
- Resource quotas and environment-specific overrides
- Horizontal Pod Autoscaling for application workloads
- ArgoCD Image Updater integration with semantic version constraints
- Kubernetes manifests for raw deployment scenarios
- Helper scripts for environment setup and deployment automation

## Setup and Installation

### Prerequisites

- Docker
- Kubernetes 1.24 or later
- Helm 3.12 or later
- kubectl
- Vagrant 2.3 or later
- VirtualBox 6.1 or later
- Git

### Install Dependencies

```bash
# Add required Helm repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install ArgoCD CLI
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
```

### Local Installation with Vagrant

```bash
git clone https://gitea.kood.tech/charleso/gitops-galaxy
cd gitops-galaxy

vagrant up
vagrant ssh

cd /home/vagrant/project/scripts
chmod +x ../*.sh
../execution.sh
```

### Manual Kubernetes Installation

```bash
# Install Kubernetes with k3s
curl -sfL https://get.k3s.io | sh -

# Install ArgoCD
kubectl create namespace argocd
helm install argo-cd argo/argo-cd -n argocd

# Apply application manifests
kubectl apply -f argocd/applications/
```

## Usage Guide

### 1. Deploy the applications

```bash
kubectl apply -f argocd/applications/postgres-dev.yaml
kubectl apply -f argocd/applications/sherlock-app-dev.yaml
kubectl apply -f argocd/applications/sherlock-app-staging.yaml
kubectl apply -f argocd/applications/sherlock-app-prod.yaml
```

### 2. Sync applications with ArgoCD

```bash
argocd app sync postgres
argocd app sync sherlock-app-dev
argocd app sync sherlock-app-staging
argocd app sync sherlock-app-prod
```

### 3. Monitor application status

```bash
argocd app list
argocd app get sherlock-app-dev
kubectl get pods -n dev
kubectl get pods -n staging
kubectl get pods -n prod
```


### 4. Validate deployments

```bash
kubectl describe pod <pod-name> -n dev
kubectl get hpa -n dev
kubectl get pvc -n dev
```

## Project Structure

```text
gitops-helm-argocd-project/
├── argocd/                # ArgoCD application resources
├── environments/          # Environment-specific quotas and policies
├── helm-charts/           # Helm charts for the application and database
├── manifests/             # Raw Kubernetes manifests
├── scripts/               # Deployment and setup automation
├── src/                   # Backend and frontend source code
└── docs/                  # Documentation
```

## Configuration

The main application configuration is managed through Helm values files:

- `helm-charts/sherlock-app/values.yaml`
- `helm-charts/sherlock-app/values-dev.yaml`
- `helm-charts/sherlock-app/values-staging.yaml`
- `helm-charts/sherlock-app/values-prod.yaml`

Useful environment variables include:

```bash
export GIT_REPO_URL="https://github.com/obiohac/gitops-galaxy.git"
export GIT_BRANCH="main"
export DB_USER="postgres"
export DB_PASSWORD="secure-password"
export DB_NAME="sherlock"
```

## Troubleshooting

- If ArgoCD does not sync, check application status with `argocd app get <app-name>`.
- If pods are pending, inspect namespace quotas and resource limits.
- If the database is unreachable, verify the PostgreSQL service and PVC state.
- If image updates do not apply, confirm the image updater annotations and repository access.