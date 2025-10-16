#!/bin/bash
# Build and push Docker image to Harbor registry
# Usage: ./build-and-push.sh <deployment_dir> [tag]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check arguments
if [ $# -lt 1 ]; then
    log_error "Usage: $0 <deployment_dir> [tag]"
    exit 1
fi

DEPLOYMENT_DIR="$1"
CUSTOM_TAG="${2:-}"

if [ ! -d "${DEPLOYMENT_DIR}" ]; then
    log_error "Deployment directory not found: ${DEPLOYMENT_DIR}"
    exit 1
fi

if [ ! -f "${DEPLOYMENT_DIR}/deployment.yaml" ]; then
    log_error "deployment.yaml not found in: ${DEPLOYMENT_DIR}"
    exit 1
fi

if [ ! -f "${DEPLOYMENT_DIR}/Dockerfile" ]; then
    log_error "Dockerfile not found in: ${DEPLOYMENT_DIR}"
    exit 1
fi

# Parse deployment metadata
DEPLOYMENT_NAME=$(grep -A 5 '^deployment:' "${DEPLOYMENT_DIR}/deployment.yaml" | grep 'name:' | head -1 | awk '{print $2}')
VERSION=$(grep -A 5 '^deployment:' "${DEPLOYMENT_DIR}/deployment.yaml" | grep 'version:' | head -1 | awk '{print $2}')

# Determine image tag
if [ -n "${CUSTOM_TAG}" ]; then
    IMAGE_TAG="${CUSTOM_TAG}"
else
    IMAGE_TAG="${VERSION}"
fi

IMAGE_NAME="harbor.wefactorit.com/karisimbi/${DEPLOYMENT_NAME}"
IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

log_info "================================================"
log_info "Building Docker Image"
log_info "================================================"
log_info "Deployment: ${DEPLOYMENT_NAME}"
log_info "Version: ${VERSION}"
log_info "Image: ${IMAGE}"
log_info "================================================"

# Change to deployment directory
cd "${DEPLOYMENT_DIR}"

# Step 1: Build Docker image
log_step "Building Docker image..."
docker build \
    -t "${IMAGE}" \
    -t "${IMAGE_NAME}:latest" \
    --platform linux/amd64 \
    --build-arg VERSION="${VERSION}" \
    --build-arg BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    . || {
    log_error "Docker build failed"
    exit 1
}

# Step 2: Check if Harbor is accessible
log_step "Checking Harbor registry access..."
if ! docker login harbor.wefactorit.com 2>/dev/null; then
    log_warn "Not logged into Harbor registry"
    log_info "Attempting to log in..."
    docker login harbor.wefactorit.com || {
        log_error "Failed to log in to Harbor. Please run: docker login harbor.wefactorit.com"
        exit 1
    }
fi

# Step 3: Push image with version tag
log_step "Pushing image with tag: ${IMAGE_TAG}"
docker push "${IMAGE}" || {
    log_error "Failed to push image with tag: ${IMAGE_TAG}"
    exit 1
}

# Step 4: Push latest tag
log_step "Pushing image with tag: latest"
docker push "${IMAGE_NAME}:latest" || {
    log_error "Failed to push image with tag: latest"
    exit 1
}

# Step 5: Display image info
log_info "================================================"
log_info "✅ Build and push complete!"
log_info "================================================"
log_info "Image: ${IMAGE}"
log_info "Latest: ${IMAGE_NAME}:latest"
log_info ""
log_info "Image size:"
docker images "${IMAGE_NAME}" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep -E "REPOSITORY|${IMAGE_TAG}|latest"
log_info "================================================"
log_info ""
log_info "Next steps:"
log_info "1. Deploy to Kubernetes: cd ${DEPLOYMENT_DIR} && ./deploy.sh"
log_info "2. Or create ArgoCD application for GitOps deployment"
log_info "================================================"
