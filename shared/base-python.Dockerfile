# Base Dockerfile for Python MCP Servers
# This template provides a production-ready Python environment for MCP servers

# Multi-stage build for optimal image size
FROM python:3.12-slim AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc g++ make && \
    rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

# Copy source code
COPY . .

# Production stage
FROM python:3.12-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends dumb-init curl && \
    rm -rf /var/lib/apt/lists/*

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local

# Copy application code
COPY --from=builder /build .

# Create non-root user
RUN useradd -m -u 1001 -s /bin/bash mcp && \
    chown -R mcp:mcp /app

USER mcp

# Update PATH to use installed packages
ENV PATH=/root/.local/bin:$PATH

# Environment variables for MCP
ENV PYTHONUNBUFFERED=1
ENV MCP_TRANSPORT=sse
ENV MCP_PORT=8000
ENV MCP_HOST=0.0.0.0

# Expose MCP port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Default command (override in deployment-specific Dockerfile)
CMD ["python", "-m", "mcp_server", "--transport", "sse", "--port", "8000"]
