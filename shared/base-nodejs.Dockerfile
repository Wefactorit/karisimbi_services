# Base Dockerfile for Node.js MCP Servers
# This template provides a production-ready Node.js environment for MCP servers

# Multi-stage build for optimal image size
FROM node:20-alpine AS builder

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache python3 make g++

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Build if needed (e.g., TypeScript compilation)
RUN if [ -f "tsconfig.json" ]; then npm run build; fi

# Production stage
FROM node:20-alpine

WORKDIR /app

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Copy dependencies and built files from builder
COPY --from=builder /build/node_modules ./node_modules
COPY --from=builder /build/package*.json ./

# Copy built files or source
COPY --from=builder /build/dist ./dist 2>/dev/null || COPY --from=builder /build/src ./src

# Create non-root user
RUN addgroup -g 1001 -S mcp && \
    adduser -S -D -H -u 1001 -h /app -s /sbin/nologin -G mcp -g mcp mcp && \
    chown -R mcp:mcp /app

USER mcp

# Environment variables for MCP
ENV NODE_ENV=production
ENV MCP_TRANSPORT=sse
ENV MCP_PORT=8000
ENV MCP_HOST=0.0.0.0

# Expose MCP port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8000/health || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Default command (override in deployment-specific Dockerfile)
CMD ["node", "dist/index.js", "--transport", "sse", "--port", "8000"]
