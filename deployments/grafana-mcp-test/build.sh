#!/bin/bash
# Build and push Docker image for this deployment

set -euo pipefail

# Load deployment metadata
DEPLOYMENT_NAME=$(grep 'name:' deployment.yaml | head -1 | awk '{print $2}')
VERSION=$(grep 'version:' deployment.yaml | head -1 | awk '{print $2}')
IMAGE=$(grep 'image:' deployment.yaml | awk '{print $2}')

echo "[INFO] Building Docker image: ${IMAGE}"
echo "[INFO] Using repository's own Dockerfile from source/"

# Build image from source directory (repository has its own Dockerfile)
docker build -t "${IMAGE}" --platform linux/amd64 -f source/Dockerfile source/

echo "[INFO] Pushing to Harbor registry..."
docker push "${IMAGE}"

echo "[SUCCESS] Image built and pushed successfully!"
