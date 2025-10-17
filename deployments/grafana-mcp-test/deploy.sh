#!/bin/bash
# Deploy this MCP server to Kubernetes

set -euo pipefail

# Load deployment metadata
DEPLOYMENT_NAME=$(grep 'name:' deployment.yaml | head -1 | awk '{print $2}')
VERSION=$(grep 'version:' deployment.yaml | head -1 | awk '{print $2}')
NAMESPACE=$(grep 'namespace:' deployment.yaml | awk '{print $2}')

echo "[INFO] Deploying ${DEPLOYMENT_NAME} (${VERSION}) to namespace ${NAMESPACE}"

# Apply Kubernetes manifests
echo "[INFO] Applying Kubernetes manifests..."
kubectl apply -f k8s/

echo "[SUCCESS] Deployment complete!"
echo "[INFO] Check status with: kubectl get pods -n ${NAMESPACE} -l app=${DEPLOYMENT_NAME}"
