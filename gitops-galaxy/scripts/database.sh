# Add the Bitnami repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Create a namespace for the DB
kubectl create namespace db-layer

# Install PostgreSQL with persistence enabled
helm install my-db bitnami/postgresql \
  --namespace db-layer \
  --set primary.persistence.enabled=true \
  --set primary.persistence.size=1Gi \
  --set auth.database=startup_db


kubectl apply -f manifests/db/test-db-job.yaml