#!/bin/bash
# Substitute template variables in Kubernetes manifests
# Usage: ./substitute-templates.sh <deployment_dir>

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check arguments
if [ $# -lt 1 ]; then
    log_error "Usage: $0 <deployment_dir>"
    exit 1
fi

DEPLOYMENT_DIR="$1"

if [ ! -d "${DEPLOYMENT_DIR}" ]; then
    log_error "Deployment directory not found: ${DEPLOYMENT_DIR}"
    exit 1
fi

if [ ! -f "${DEPLOYMENT_DIR}/deployment.yaml" ]; then
    log_error "deployment.yaml not found in: ${DEPLOYMENT_DIR}"
    exit 1
fi

log_info "Substituting template variables for deployment: $(basename ${DEPLOYMENT_DIR})"

# Parse deployment.yaml using simple grep/awk (avoiding yq dependency)
DEPLOYMENT_NAME=$(grep -A 5 '^deployment:' "${DEPLOYMENT_DIR}/deployment.yaml" | grep 'name:' | head -1 | awk '{print $2}')
VERSION=$(grep -A 5 '^deployment:' "${DEPLOYMENT_DIR}/deployment.yaml" | grep 'version:' | head -1 | awk '{print $2}')
GITHUB_REPO=$(grep -A 5 '^deployment:' "${DEPLOYMENT_DIR}/deployment.yaml" | grep 'github_url:' | awk '{print $2}')
CREATED_AT=$(grep -A 5 '^deployment:' "${DEPLOYMENT_DIR}/deployment.yaml" | grep 'created_at:' | awk '{print $2}')

IMAGE=$(grep -A 3 '^container:' "${DEPLOYMENT_DIR}/deployment.yaml" | grep 'image:' | awk '{print $2}')

NAMESPACE=$(grep -A 10 '^kubernetes:' "${DEPLOYMENT_DIR}/deployment.yaml" | grep 'namespace:' | awk '{print $2}')
REPLICAS=$(grep -A 10 '^kubernetes:' "${DEPLOYMENT_DIR}/deployment.yaml" | grep 'replicas:' | awk '{print $2}')

CPU_REQUEST=$(grep -A 15 '^kubernetes:' "${DEPLOYMENT_DIR}/deployment.yaml" | grep -A 5 'requests:' | grep 'cpu:' | awk '{print $2}' | tr -d '"')
MEMORY_REQUEST=$(grep -A 15 '^kubernetes:' "${DEPLOYMENT_DIR}/deployment.yaml" | grep -A 5 'requests:' | grep 'memory:' | awk '{print $2}' | tr -d '"')
CPU_LIMIT=$(grep -A 15 '^kubernetes:' "${DEPLOYMENT_DIR}/deployment.yaml" | grep -A 5 'limits:' | grep 'cpu:' | awk '{print $2}' | tr -d '"')
MEMORY_LIMIT=$(grep -A 15 '^kubernetes:' "${DEPLOYMENT_DIR}/deployment.yaml" | grep -A 5 'limits:' | grep 'memory:' | awk '{print $2}' | tr -d '"')

# Generate environment variables section
ENV_VARS=""
while IFS=: read -r key value; do
    if [ -n "$key" ] && [ -n "$value" ]; then
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        ENV_VARS="${ENV_VARS}        - name: ${key}\n          value: \"${value}\"\n"
    fi
done < <(grep -A 100 '^environment:' "${DEPLOYMENT_DIR}/deployment.yaml" | grep -v '^environment:' | grep ':' || true)

# Generate unique deployment ID
DEPLOYMENT_ID="${DEPLOYMENT_NAME}-$(date +%s)"

# Harbor registry secret (base64 encoded docker config)
# This should be provided as an environment variable or generated
HARBOR_REGISTRY_SECRET="${HARBOR_REGISTRY_SECRET:-placeholder}"

log_info "Deployment: ${DEPLOYMENT_NAME}"
log_info "Version: ${VERSION}"
log_info "Image: ${IMAGE}"
log_info "Namespace: ${NAMESPACE}"
log_info "Replicas: ${REPLICAS}"

# Process each template file
for template in "${DEPLOYMENT_DIR}/k8s"/*.yaml; do
    if [ -f "$template" ]; then
        filename=$(basename "$template")
        log_info "Processing: ${filename}"

        # Create temporary file for substitution
        temp_file=$(mktemp)

        # Perform substitutions
        sed -e "s|{{DEPLOYMENT_NAME}}|${DEPLOYMENT_NAME}|g" \
            -e "s|{{VERSION}}|${VERSION}|g" \
            -e "s|{{DEPLOYMENT_ID}}|${DEPLOYMENT_ID}|g" \
            -e "s|{{GITHUB_REPO}}|${GITHUB_REPO}|g" \
            -e "s|{{CREATED_AT}}|${CREATED_AT}|g" \
            -e "s|{{IMAGE}}|${IMAGE}|g" \
            -e "s|{{NAMESPACE}}|${NAMESPACE}|g" \
            -e "s|{{REPLICAS}}|${REPLICAS}|g" \
            -e "s|{{CPU_REQUEST}}|${CPU_REQUEST}|g" \
            -e "s|{{MEMORY_REQUEST}}|${MEMORY_REQUEST}|g" \
            -e "s|{{CPU_LIMIT}}|${CPU_LIMIT}|g" \
            -e "s|{{MEMORY_LIMIT}}|${MEMORY_LIMIT}|g" \
            -e "s|{{HARBOR_REGISTRY_SECRET}}|${HARBOR_REGISTRY_SECRET}|g" \
            "$template" > "$temp_file"

        # Handle environment variables (multi-line substitution)
        if [ -n "$ENV_VARS" ]; then
            awk -v env_vars="$ENV_VARS" '{
                if ($0 ~ /{{ENV_VARS}}/) {
                    printf "%s", env_vars
                } else {
                    print $0
                }
            }' "$temp_file" > "$temp_file.tmp"
            mv "$temp_file.tmp" "$temp_file"
        else
            # Remove ENV_VARS placeholder if no env vars
            sed -i.bak '/{{ENV_VARS}}/d' "$temp_file"
            rm -f "$temp_file.bak"
        fi

        # Replace original file
        mv "$temp_file" "$template"
    fi
done

log_info "✅ Template substitution complete!"
log_info "Manifests ready in: ${DEPLOYMENT_DIR}/k8s/"
