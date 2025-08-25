# Multi-stage build for minimal production image
FROM golang:1.22-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make ca-certificates tzdata

# Set working directory
WORKDIR /build

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary with optimizations (using -mod=mod to ignore vendor)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -mod=mod \
    -ldflags="-w -s -X main.version=v0.1.0 -X main.commit=unknown -X main.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -tags netgo \
    -o sleeper-sync \
    ./cmd/sync

# Optional: Compress binary with UPX for even smaller size
# RUN apk add --no-cache upx && upx --best --lzma sleeper-sync

# Development stage - includes debugging tools
FROM golang:1.22-alpine AS development

RUN apk add --no-cache git make ca-certificates tzdata curl

WORKDIR /app

# Install air for hot reload in development (v1.52.3 is compatible with Go 1.22)
RUN go install github.com/air-verse/air@v1.52.3

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code (will be mounted as volume in dev)
COPY . .

# Expose port
EXPOSE 8000

# Use air for hot reload
CMD ["air", "-c", ".air.toml"]

# Production stage - minimal image
FROM scratch AS production

# Copy timezone data for proper time handling
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy CA certificates for HTTPS
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy the binary
COPY --from=builder /build/sleeper-sync /sleeper-sync

# Copy config file (optional, can be mounted)
# COPY --from=builder /build/config.yaml /config.yaml

# Expose port
EXPOSE 8000

# Run as non-root user for security
USER 1000:1000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/sleeper-sync", "health"]

# Run the binary
ENTRYPOINT ["/sleeper-sync"]