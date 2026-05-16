# Questions and Answers

## 1. How does Helm simplify Kubernetes application deployments?

Helm packages Kubernetes manifests into reusable charts, so a single release can install and manage multiple related resources together.

## 2. Why does Helm improve productivity and scalability?

Helm reduces repeated YAML, standardizes deployment patterns, and makes it easier to reuse the same app across multiple environments with different values.

## 3. What is the structure of a Helm chart?

A Helm chart typically contains `Chart.yaml`, a `templates/` directory, and one or more values files such as `values.yaml`, `values-dev.yaml`, `values-staging.yaml`, and `values-prod.yaml`.

## 4. How does ArgoCD implement GitOps principles?

ArgoCD treats Git as the source of truth, continuously compares Git state with cluster state, and syncs the cluster so it matches the repository.

## 5. Is the database deployed using a pre-existing Helm chart?

Yes. This repository includes database Helm values and deployment support, so the database is managed through chart-based deployment rather than hand-written one-off manifests.

Use this to verify: kubectl get pods -n db-layer -o wide
You need to ssh into Vagrant first using: Vagrant ssh 

## 6. How do you verify the database deployment status?

Check that the database namespace is created and that all database pods are in the `Running` state with no crash loops or pending pods.
Verify using: kubectl delete job db-test-ping -n db-layer --ignore-not-found

## 7. Does a Kubernetes job successfully connect to the deployed database?

Yes, the database test job should complete successfully and log a valid connection and basic database operations.

## 8. How do you verify the job execution?

Review the job logs and confirm the connection test finishes without errors and the database operations complete.

## 9. Is database persistence properly configured?

It should be. Persistence is verified by writing test data, deleting the database pod, and confirming the data still exists after the pod restarts.

## 10. How do values files customize a Helm chart?

Values files override chart defaults so the same templates can deploy different image tags, resource limits, environment variables, and replicas.

## 11. What changes can be applied through values files?

Image versions, CPU and memory limits, and environment variables can all be controlled through values files.

## 12. How does Helm rollback work?

Helm rollback restores a previous release revision, which returns the application to the last known stable state.

## 13. How do you test rollback functionality?

Deploy a broken version, run a rollback, and confirm the application returns to the previous healthy release.

## 14. What are Helm lifecycle hooks used for?

Helm hooks run at specific stages such as pre-install, post-install, pre-upgrade, or post-upgrade, and are useful for jobs like migrations, setup, cleanup, and validation.

## 15. How are Helm charts tested?

Helm charts can be tested with Helm test hooks and the `helm test` command, which runs validation pods or jobs against a release.

## 16. Is ArgoCD installed and operational in the cluster?

It should be installed with its UI, API, repo server, and application controller running in a healthy state.

## 17. How do you verify ArgoCD is healthy?

Check the UI, confirm the main ArgoCD components are healthy, and verify the CLI can connect and list resources.

## 18. What are the main components of ArgoCD?

The main components are the API server, repository server, application controller, and UI.

## 19. How is Git repository integration configured?

ArgoCD uses repository credentials and application manifests so it can pull deployment definitions directly from Git.

## 20. Is application tracking in ArgoCD properly configured?

Yes, application tracking is correct when the application shows `Synced`, `Healthy`, and the cluster state matches the Git state.

## 21. How do you create and manage applications in ArgoCD?

Use the Application custom resource definition to define source, destination, and sync behavior for each deployment.

## 22. How do you use the ArgoCD UI or CLI?

Use them to monitor health, inspect diffs, trigger syncs, review application history, and manage deployments.

## 23. Does RBAC follow least privilege?

It should. Users and roles must only receive the permissions needed for their tasks, with no unnecessary cluster-wide access.

## 24. How do sync options protect safe resource deletion?

Sync options can ensure new resources are applied before old ones are removed, and deletion happens only after a successful sync.

## 25. What is continuous reconciliation in ArgoCD?

Continuous reconciliation means ArgoCD keeps comparing desired Git state with live cluster state and corrects drift automatically.

## 26. How do you verify drift detection?

Make a manual change in the cluster, confirm ArgoCD detects the difference, and verify it restores the declared state.

## 27. Is ArgoCD Image Updater installed and operational?

Yes, it should be running as a separate component that watches images and updates deployment definitions when configured.

## 28. How does Image Updater handle patch updates with Git write-back?

When a new patch version is available, Image Updater updates the Git manifest or values file, then ArgoCD syncs the cluster to the new image.

## 29. How do you verify the patch update flow?

Push a patch release such as `v1.0.1`, confirm Git is updated, and verify the cluster syncs to the new image.

## 30. How does Image Updater ignore minor and major updates?

It uses version constraints or semver rules so only allowed patch updates are accepted, while minor and major jumps are skipped.

## 31. Does the CI/CD pipeline manage the full deployment workflow?

Yes, it should automate build, test, image push, manifest update, and deployment synchronization end to end.

## 32. Is ArgoCD Application resource management integrated into the CI/CD pipeline?

Yes, the pipeline should be able to create or update Application resources so deployments stay aligned with Git changes.

## 33. Is rollback properly implemented in the pipeline?

It should detect a failed deployment, then restore the previous stable version automatically or through a defined rollback step.

## 34. Does the documentation include all required components?

It should include a project overview, setup instructions, and a usage guide so the full workflow is reproducible.

## 35. Do the Helm charts follow best practices?

Yes, when the chart includes a proper `Chart.yaml`, centralized values, clearly named templates, and a standard Helm directory layout.

## 36. Does the code meet quality standards?

It should use consistent formatting, clear comments where needed, and language-specific best practices for maintainability.

## 37. Why is external secret management better than Kubernetes Secrets?

External secret management keeps sensitive data outside the cluster, supports centralized rotation, and reduces the risk of storing secrets directly in Git or plain cluster objects.

## 38. Is external secret integration configured and functional?

It should store secrets in the external system, let Kubernetes retrieve them through the secret operator or controller, and use the correct authentication method.

## 39. Is the multi-environment CI/CD pipeline properly configured?

Yes, it should use isolated namespaces, apply environment-specific configuration, and keep dev, staging, and production deployments independent.