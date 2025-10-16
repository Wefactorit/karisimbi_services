# Base Dockerfile for Go MCP Servers
# This template provides a production-ready Go environment for MCP servers

# Multi-stage build for optimal image size
FROM golang:1.23-alpine AS builder

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Copy go.mod and go.sum first for better caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary with optimizations
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w -X main.version=${VERSION:-dev} -X main.commit=${COMMIT:-unknown} -X main.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -o /bin/mcp-server \
    ./cmd/server

# Production stage - use distroless for minimal attack surface
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /app

# Copy CA certificates from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy the binary from builder
COPY --from=builder /bin/mcp-server /app/mcp-server

# Use nonroot user (uid 65532)
USER nonroot:nonroot

# Environment variables for MCP
ENV MCP_TRANSPORT=sse
ENV MCP_PORT=8000
ENV MCP_HOST=0.0.0.0

# Expose MCP port
EXPOSE 8000

# Health check (note: distroless doesn't have shell, so we rely on K8s probes)
# K8s will use HTTP GET on /health endpoint

# Default command
ENTRYPOINT ["/app/mcp-server"]
CMD ["--transport", "sse", "--address", "0.0.0.0:8000"]
