# Repository References Documentation

**Repository URL:** `https://github.com/obiohac/gitops-galaxy`

## Files Containing Repository References

This document lists all files in the GitOps Galaxy project where the repository URL is referenced.

### Updated Files (Previously had placeholders)
- ✅ `manifests/argocd/applications.yaml` - **UPDATED** (had `YOUR_USERNAME` placeholder, now corrected)
- ✅ `manifests/argocd/applications/app-of-apps.yaml` - **UPDATED** (had `your-org` placeholder, now corrected)

### Files with Correct Repository URL

#### ArgoCD Applications
1. **manifests/argocd/applications.yaml**
   - Line 12: gitops-app-dev repoURL
   - Line 58: gitops-app-staging repoURL
   - Line 111: gitops-app-prod repoURL

2. **manifests/argocd/applications/app-of-apps.yaml**
   - Line 13: repoURL reference
   - Line 41: environment variable reference

3. **manifests/argocd/applications/app-of-apps-staging.yaml**
   - Line 13: repoURL reference
   - Line 43: environment variable reference

4. **manifests/argocd/applications/app-of-apps-prod.yaml**
   - Line 13: repoURL reference
   - Line 43: environment variable reference

#### Backend Applications
5. **manifests/argocd/applications/backend-app-dev.yaml**
   - Line 12: repoURL reference
   - Line 48: environment variable reference

6. **manifests/argocd/applications/backend-app-staging.yaml**
   - Line 12: repoURL reference
   - Line 48: environment variable reference

7. **manifests/argocd/applications/backend-app-prod.yaml**
   - Line 12: repoURL reference
   - Line 48: environment variable reference

#### Frontend Applications
8. **manifests/argocd/applications/frontend-app-dev.yaml**
   - Line 14: repoURL reference
   - Line 69: environment variable reference

9. **manifests/argocd/applications/frontend-app-staging.yaml**
   - Line 14: repoURL reference
   - Line 69: environment variable reference

10. **manifests/argocd/applications/frontend-app-prod.yaml**
    - Line 14: repoURL reference
    - Line 67: environment variable reference

#### Database Applications
11. **manifests/argocd/applications/postgres-app-dev.yaml**
    - Line 12: repoURL reference

12. **manifests/argocd/applications/postgres-app-staging.yaml**
    - Line 12: repoURL reference

13. **manifests/argocd/applications/postgres-app-prod.yaml**
    - Line 12: repoURL reference

#### Kubernetes Application
14. **manifests/argocd/applications/kubernetes-app.yaml**
    - Line 12: repoURL reference

#### Shell Scripts
15. **gitops-galaxy/scripts/setup-github-repo.sh**
    - Line 7: GITHUB_REPO environment variable

16. **setup.sh** (root directory)
    - Line 18: Repository URL in kubectl secret creation

## Summary

- **Total Files Containing Repository References:** 16 files
- **Files Updated (Placeholders Fixed):** 2 files
- **Files Already Correct:** 14 files

All repository references now point to the correct GitHub repository: `https://github.com/obiohac/gitops-galaxy`

