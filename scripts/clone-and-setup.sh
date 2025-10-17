#!/bin/bash
# Clone MCP server repository and setup deployment structure
# Usage: ./clone-and-setup.sh <github_url> <deployment_name> <version>

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check arguments
if [ $# -lt 3 ]; then
    log_error "Usage: $0 <github_url> <deployment_name> <version>"
    log_error "Example: $0 https://github.com/user/mcp-server mcp-grafana v1.0.0"
    exit 1
fi

GITHUB_URL="$1"
DEPLOYMENT_NAME="$2"
VERSION="$3"
BRANCH_NAME="${DEPLOYMENT_NAME}-${VERSION}"

# Get repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOYMENT_DIR="${REPO_ROOT}/deployments/${DEPLOYMENT_NAME}"

log_info "Setting up deployment: ${DEPLOYMENT_NAME} (${VERSION})"
log_info "Repository root: ${REPO_ROOT}"

# Check if deployment already exists
if [ -d "${DEPLOYMENT_DIR}" ]; then
    log_warn "Deployment directory already exists: ${DEPLOYMENT_DIR}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborted."
        exit 0
    fi
    rm -rf "${DEPLOYMENT_DIR}"
fi

# Create deployment directory structure
log_info "Creating deployment directory structure..."
mkdir -p "${DEPLOYMENT_DIR}/source"
mkdir -p "${DEPLOYMENT_DIR}/k8s"

# Clone MCP server repository
log_info "Cloning MCP server from: ${GITHUB_URL}"
cd "${DEPLOYMENT_DIR}"
git clone "${GITHUB_URL}" source || {
    log_error "Failed to clone repository"
    exit 1
}

# Detect repository type (Node.js, Python, Go)
log_info "Detecting repository type..."
if [ -f "source/package.json" ]; then
    REPO_TYPE="nodejs"
    BASE_DOCKERFILE="base-nodejs.Dockerfile"
    log_info "Detected Node.js project"
elif [ -f "source/requirements.txt" ] || [ -f "source/pyproject.toml" ]; then
    REPO_TYPE="python"
    BASE_DOCKERFILE="base-python.Dockerfile"
    log_info "Detected Python project"
elif [ -f "source/go.mod" ]; then
    REPO_TYPE="golang"
    BASE_DOCKERFILE="base-golang.Dockerfile"
    log_info "Detected Go project"
else
    log_warn "Could not detect repository type, defaulting to Node.js"
    REPO_TYPE="nodejs"
    BASE_DOCKERFILE="base-nodejs.Dockerfile"
fi

# Check if repository already has a Dockerfile
if [ -f "source/Dockerfile" ]; then
    log_info "Repository already has a Dockerfile, will use it from source directory"
    HAS_OWN_DOCKERFILE=true
else
    log_info "No Dockerfile found, using base template: ${BASE_DOCKERFILE}"
    cp "${REPO_ROOT}/shared/${BASE_DOCKERFILE}" ./Dockerfile
    HAS_OWN_DOCKERFILE=false
fi

# Create deployment metadata
log_info "Creating deployment metadata..."
cat > deployment.yaml <<EOF
# Cloudeefly Deployment Metadata
deployment:
  name: ${DEPLOYMENT_NAME}
  version: ${VERSION}
  github_url: ${GITHUB_URL}
  repo_type: ${REPO_TYPE}
  created_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Container configuration
container:
  image: harbor.wefactorit.com/karisimbi/${DEPLOYMENT_NAME}:${VERSION}
  port: 8000

# Kubernetes configuration
kubernetes:
  namespace: mcp-servers
  replicas: 2
  resources:
    requests:
      cpu: "100m"
      memory: "128Mi"
    limits:
      cpu: "500m"
      memory: "512Mi"

# Environment variables (add custom variables here)
environment:
  MCP_TRANSPORT: "sse"
  MCP_PORT: "8000"
  MCP_HOST: "0.0.0.0"
EOF

# Copy Kubernetes templates and prepare for customization
log_info "Copying Kubernetes manifest templates..."
for template in "${REPO_ROOT}"/shared/k8s-templates/*.yaml; do
    filename=$(basename "$template")
    cp "$template" "k8s/${filename}"
done

log_info "Creating build script..."
if [ "${HAS_OWN_DOCKERFILE}" = true ]; then
    # Build from source directory using repository's own Dockerfile
    cat > build.sh <<'EOF'
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
EOF
else
    # Build from deployment root using base template
    cat > build.sh <<'EOF'
#!/bin/bash
# Build and push Docker image for this deployment

set -euo pipefail

# Load deployment metadata
DEPLOYMENT_NAME=$(grep 'name:' deployment.yaml | head -1 | awk '{print $2}')
VERSION=$(grep 'version:' deployment.yaml | head -1 | awk '{print $2}')
IMAGE=$(grep 'image:' deployment.yaml | awk '{print $2}')

echo "[INFO] Building Docker image: ${IMAGE}"
echo "[INFO] Using Cloudeefly base template"

# Build image from deployment root (using base template)
docker build -t "${IMAGE}" --platform linux/amd64 .

echo "[INFO] Pushing to Harbor registry..."
docker push "${IMAGE}"

echo "[SUCCESS] Image built and pushed successfully!"
EOF
fi

chmod +x build.sh

# Create deploy script
log_info "Creating deploy script..."
cat > deploy.sh <<'EOF'
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
EOF

chmod +x deploy.sh

log_info ""
log_info "================================================"
log_info "✅ Deployment setup complete!"
log_info "================================================"
log_info "Deployment: ${DEPLOYMENT_NAME}"
log_info "Version: ${VERSION}"
log_info "Location: ${DEPLOYMENT_DIR}"
log_info ""
log_info "Next steps:"
log_info "1. Review and customize: ${DEPLOYMENT_DIR}/deployment.yaml"
log_info "2. Review and customize: ${DEPLOYMENT_DIR}/Dockerfile"
log_info "3. Build image: cd ${DEPLOYMENT_DIR} && ./build.sh"
log_info "4. Deploy to K8s: ./deploy.sh"
log_info ""
log_info "Or commit and push to trigger GitOps pipeline:"
log_info "  git checkout -b ${BRANCH_NAME}"
log_info "  git add deployments/${DEPLOYMENT_NAME}"
log_info "  git commit -m 'Add ${DEPLOYMENT_NAME} ${VERSION}'"
log_info "  git push origin ${BRANCH_NAME}"
log_info "================================================"
