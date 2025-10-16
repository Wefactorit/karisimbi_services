# Karisimbi Services

Central repository for managing all MCP (Model Context Protocol) server deployments in the Karisimbi infrastructure.

## Overview

This repository follows a GitOps workflow where each MCP server deployment is:
1. Cloned from its source GitHub repository
2. Built into a Docker container
3. Deployed to Kubernetes via ArgoCD or Argo Workflows
4. Managed and monitored through the Cloudeefly platform

## Architecture

```
karisimbi_services/
├── .github/workflows/          # CI/CD pipelines
├── shared/
│   ├── base-nodejs.Dockerfile  # Base Dockerfile for Node.js MCP servers
│   ├── base-python.Dockerfile  # Base Dockerfile for Python MCP servers
│   ├── base-golang.Dockerfile  # Base Dockerfile for Go MCP servers
│   ├── build-scripts/          # Common build utilities
│   └── k8s-templates/          # Kubernetes manifest templates
├── deployments/
│   ├── mcp-grafana/           # Example MCP deployment
│   │   ├── source/            # Cloned MCP server code
│   │   ├── Dockerfile         # Custom or generated Dockerfile
│   │   ├── k8s/               # Kubernetes manifests
│   │   ├── deployment.yaml    # Deployment metadata and configuration
│   │   ├── build.sh           # Build script
│   │   └── deploy.sh          # Deploy script
│   └── mcp-{name}/            # Additional deployments...
└── scripts/
    ├── clone-and-setup.sh     # Clone MCP server and setup structure
    ├── substitute-templates.sh # Template variable substitution
    └── ...
```

## Quick Start

### Prerequisites

- Docker with Harbor registry access
- kubectl configured for Karisimbi cluster
- Git access to this repository
- Harbor credentials: `docker login harbor.wefactorit.com`

### Adding a New MCP Server

1. **Clone and setup the MCP server:**
   ```bash
   ./scripts/clone-and-setup.sh \
     https://github.com/user/mcp-server \
     mcp-grafana \
     v1.0.0
   ```

2. **Customize the deployment:**
   ```bash
   cd deployments/mcp-grafana

   # Edit deployment configuration
   vim deployment.yaml

   # Review/customize Dockerfile if needed
   vim Dockerfile
   ```

3. **Build and push Docker image:**
   ```bash
   ./build.sh
   ```

4. **Deploy to Kubernetes:**
   ```bash
   # Substitute template variables
   ../../scripts/substitute-templates.sh .

   # Deploy
   ./deploy.sh
   ```

### GitOps Workflow (Recommended)

For production deployments, use GitOps:

1. **Create a branch for the deployment:**
   ```bash
   git checkout -b mcp-grafana-v1.0.0
   git add deployments/mcp-grafana
   git commit -m "Add mcp-grafana v1.0.0 deployment"
   git push origin mcp-grafana-v1.0.0
   ```

2. **Trigger Argo Workflow:**
   The CI/CD pipeline will automatically:
   - Validate the deployment configuration
   - Build the Docker image
   - Push to Harbor registry
   - Deploy to Kubernetes via ArgoCD
   - Report status back to Cloudeefly API

## Deployment Configuration

Each deployment has a `deployment.yaml` file that defines:

```yaml
# Deployment metadata
deployment:
  name: mcp-grafana
  version: v1.0.0
  github_url: https://github.com/user/mcp-server
  repo_type: nodejs  # or python, golang
  created_at: 2025-01-15T10:30:00Z

# Container configuration
container:
  image: harbor.wefactorit.com/karisimbi/mcp-grafana:v1.0.0
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

# Environment variables
environment:
  MCP_TRANSPORT: "sse"
  MCP_PORT: "8000"
  MCP_HOST: "0.0.0.0"
  # Add custom environment variables here
```

## Docker Base Images

### Node.js MCP Servers

Use `shared/base-nodejs.Dockerfile` for Node.js-based MCP servers:
- Multi-stage build with Node 20 Alpine
- Production dependencies only
- Non-root user (uid 1001)
- Health checks configured
- SSE transport enabled

### Python MCP Servers

Use `shared/base-python.Dockerfile` for Python-based MCP servers:
- Multi-stage build with Python 3.12 slim
- Pip dependencies optimized
- Non-root user (uid 1001)
- Health checks configured
- SSE transport enabled

### Go MCP Servers

Use `shared/base-golang.Dockerfile` for Go-based MCP servers:
- Multi-stage build with Go 1.23
- Static binary compilation
- Distroless base image
- Minimal attack surface
- SSE transport enabled

## Kubernetes Resources

Each deployment includes:

### Deployment
- Rolling update strategy
- Resource limits and requests
- Health probes (liveness, readiness, startup)
- Istio sidecar injection
- Security context (non-root, read-only root filesystem)

### Service
- ClusterIP type
- Session affinity for long-running SSE connections
- Exposed on port 8000

### ServiceEntry (Istio)
- Mesh-internal service registration
- Enables service mesh features

### VirtualService (Istio)
- HTTP routing configuration
- Timeout and retry policies
- Circuit breaking

## Scripts

### clone-and-setup.sh
Clone an MCP server repository and setup the deployment structure:
```bash
./scripts/clone-and-setup.sh <github_url> <deployment_name> <version>
```

Features:
- Auto-detects repository type (Node.js, Python, Go)
- Creates deployment directory structure
- Copies appropriate Dockerfile template
- Generates deployment metadata
- Creates build and deploy scripts

### substitute-templates.sh
Substitute template variables in Kubernetes manifests:
```bash
./scripts/substitute-templates.sh <deployment_dir>
```

Substitutes:
- `{{DEPLOYMENT_NAME}}` - Deployment name
- `{{VERSION}}` - Version tag
- `{{IMAGE}}` - Full image name with tag
- `{{NAMESPACE}}` - Kubernetes namespace
- `{{REPLICAS}}` - Number of replicas
- `{{CPU_REQUEST}}`, `{{MEMORY_REQUEST}}` - Resource requests
- `{{CPU_LIMIT}}`, `{{MEMORY_LIMIT}}` - Resource limits
- `{{ENV_VARS}}` - Environment variables from deployment.yaml

### build-and-push.sh
Build Docker image and push to Harbor registry:
```bash
./shared/build-scripts/build-and-push.sh <deployment_dir> [tag]
```

Features:
- Multi-platform build (linux/amd64)
- Automatic Harbor login check
- Tags with version and latest
- Build metadata (version, date)
- Image size reporting

## CI/CD Integration

### Argo Workflows

The repository includes Argo Workflow templates for:
1. **Validation**: Validate deployment configuration
2. **Build**: Build Docker image and push to Harbor
3. **Deploy**: Deploy to Kubernetes via kubectl or ArgoCD
4. **Test**: Run smoke tests against deployed service
5. **Notify**: Report status back to Cloudeefly API

### GitHub Actions

Optional GitHub Actions workflows for:
- PR validation
- Automated builds on merge
- Security scanning (Trivy)
- Dependency updates

## Security

### Container Security
- Non-root user (uid 1001)
- Read-only root filesystem
- No privilege escalation
- Minimal base images (Alpine, distroless)
- Security context configured

### Network Security
- Istio service mesh with mTLS
- Network policies (coming soon)
- Ingress restrictions

### Image Security
- Harbor vulnerability scanning
- Signed images (Cosign - coming soon)
- SBOM generation (coming soon)

## Monitoring

### Prometheus Metrics
All deployments expose metrics on `/metrics`:
- Request duration
- Request count
- Error rates
- Custom MCP metrics

### Logging
Logs are collected via:
- Stdout/stderr (captured by Kubernetes)
- Structured JSON logging
- Centralized in Loki/Elasticsearch

### Tracing
- Istio distributed tracing
- Jaeger integration

## Troubleshooting

### Build Issues

**Problem**: Docker build fails
```bash
# Check Dockerfile syntax
docker build --no-cache -t test .

# Check base image availability
docker pull node:20-alpine
```

**Problem**: Cannot push to Harbor
```bash
# Re-login to Harbor
docker login harbor.wefactorit.com

# Check image name format
# Should be: harbor.wefactorit.com/karisimbi/{name}:{tag}
```

### Deployment Issues

**Problem**: Pods not starting
```bash
# Check pod status
kubectl get pods -n mcp-servers

# Check pod logs
kubectl logs -n mcp-servers <pod-name>

# Describe pod for events
kubectl describe pod -n mcp-servers <pod-name>
```

**Problem**: Health checks failing
```bash
# Test health endpoint locally
docker run -p 8000:8000 <image>
curl http://localhost:8000/health

# Check health probe configuration in deployment.yaml
```

### Networking Issues

**Problem**: Service not accessible
```bash
# Check service endpoints
kubectl get endpoints -n mcp-servers <service-name>

# Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://<service-name>.mcp-servers.svc.cluster.local:8000/health
```

## Best Practices

### Deployment Configuration
- Always specify resource limits and requests
- Use semantic versioning for tags
- Include health check endpoints in MCP servers
- Set appropriate timeout values for SSE connections

### Docker Images
- Use multi-stage builds to minimize image size
- Run as non-root user
- Don't include secrets in images
- Tag images with both version and latest

### Kubernetes
- Use namespaces to isolate deployments
- Configure pod anti-affinity for HA
- Set up horizontal pod autoscaling (HPA)
- Use secrets for sensitive configuration

### GitOps
- Create feature branches for new deployments
- Review and test before merging to main
- Use ArgoCD sync policies appropriately
- Document deployment changes in commit messages

## Support

- **Documentation**: This README and inline comments
- **Issues**: Report via Cloudeefly platform
- **Slack**: #mcp-deployments channel
- **Email**: support@cloudeefly.com

## License

Proprietary - Cloudeefly Platform
