# MCP Grafana Deployment Status

## Deployment Information
- **Name**: mcp-grafana
- **Version**: v1.0.0
- **Source**: https://github.com/grafana/mcp-grafana
- **Type**: Go (Golang)
- **Created**: 2025-10-16T16:38:32Z

## Build Configuration
- **Image**: harbor.wefactorit.com/karisimbi/mcp-grafana:v1.0.0
- **Port**: 8000
- **Transport**: SSE (Server-Sent Events)
- **Platform**: linux/amd64

## Kubernetes Configuration
- **Namespace**: mcp-servers
- **Replicas**: 2
- **Resources**:
  - CPU Request: 100m
  - Memory Request: 128Mi
  - CPU Limit: 500m
  - Memory Limit: 512Mi

## Environment Variables
- `MCP_TRANSPORT`: sse
- `MCP_PORT`: 8000
- `MCP_HOST`: 0.0.0.0

## Deployment Steps

### ✅ Step 1: Repository Setup
- Cloned mcp-grafana source into `source/` directory
- Detected as Go project
- Found existing Dockerfile (customized for karisimbi_services structure)

### ✅ Step 2: Configuration
- Generated `deployment.yaml` with metadata
- Copied Kubernetes manifest templates
- Updated Dockerfile to reference `source/` directory
- Fixed template substitution script for proper parsing

### ✅ Step 3: Template Substitution
- Substituted all template variables in K8s manifests:
  - `deployment.yaml` - Main deployment configuration
  - `service.yaml` - ClusterIP service with session affinity
  - `namespace.yaml` - Namespace with Istio injection
  - `serviceentry.yaml` - Istio ServiceEntry
  - `virtualservice.yaml` - Istio routing configuration

### 🔄 Step 4: Docker Build (In Progress)
- Building multi-stage Docker image
- Current stage: Compiling Go binary (#17 builder)
- Expected output: ~30-50MB image
- Will push to Harbor registry upon completion

### ⏳ Step 5: Deploy to Kubernetes (Pending)
- Apply namespace and RBAC
- Deploy application
- Create service and Istio configs
- Wait for rollout completion
- Verify health checks

### ⏳ Step 6: Verification (Pending)
- Check pod status
- Test health endpoint
- Verify Istio integration
- Test MCP SSE connection

## Commands

### Build
```bash
cd /Users/sebastienpincemail/Lab/WEFIT/karisimbi_services/deployments/mcp-grafana
./build.sh
```

### Deploy
```bash
./deploy.sh
```

### Manual Deploy
```bash
export KUBECONFIG=~/.kube/karisimbiv3
kubectl apply -f k8s/
kubectl rollout status deployment/mcp-grafana -n mcp-servers
```

### Check Status
```bash
kubectl get pods -n mcp-servers -l app=mcp-grafana
kubectl logs -n mcp-servers -l app=mcp-grafana --tail=100
```

### Test Connectivity
```bash
kubectl run -it --rm test --image=curlimages/curl --restart=Never -- \
  curl -v http://mcp-grafana.mcp-servers.svc.cluster.local:8000/health
```

## Notes
- This is a test deployment to validate the karisimbi_services repository structure
- The deployment uses SSE transport (required for K8s deployments)
- Istio sidecar injection is enabled for mTLS and observability
- Session affinity is configured for long-running SSE connections

## Next Steps
1. Wait for Docker build completion
2. Push image to Harbor registry
3. Deploy to Kubernetes
4. Verify connectivity
5. Test MCP protocol
6. Document any issues/improvements
7. Push to GitHub remote
