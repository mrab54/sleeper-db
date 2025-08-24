# Container Orchestration & Deployment Architecture Decision

Generated: 2025-08-24

## Executive Summary

**Recommendation**: Start with **Docker Compose** for development and initial production, with a clear migration path to **Kubernetes** when scaling requirements increase. This pragmatic approach balances simplicity with future scalability.

## Requirements Analysis

### Current Project Needs
- 3-5 containerized services (PostgreSQL, Hasura, Sync Service, Redis, Monitoring)
- Single league initially (12 users)
- Moderate traffic (< 100 concurrent users)
- Development simplicity priority
- Cost-conscious deployment

### Future Scaling Needs
- Multiple leagues support (10-100 leagues)
- High availability requirements
- Auto-scaling during game times
- Multi-region potential
- Advanced monitoring/observability

## Options Evaluated

### Comparison Matrix

| Criteria | Docker Compose | Docker Swarm | Kubernetes | Weight | 
|----------|---------------|--------------|------------|--------|
| **Learning Curve** | Simple (10/10) | Moderate (7/10) | Complex (4/10) | 20% |
| **Development Experience** | Excellent (10/10) | Good (7/10) | Complex (5/10) | 25% |
| **Production Readiness** | Limited (6/10) | Good (8/10) | Excellent (10/10) | 15% |
| **Scaling Capability** | Manual (4/10) | Good (7/10) | Excellent (10/10) | 10% |
| **High Availability** | None (2/10) | Built-in (8/10) | Excellent (10/10) | 10% |
| **Cost (Small Scale)** | Minimal (10/10) | Low (8/10) | Higher (5/10) | 10% |
| **Monitoring** | Basic (5/10) | Good (7/10) | Excellent (10/10) | 5% |
| **Community/Support** | Good (8/10) | Limited (5/10) | Excellent (10/10) | 5% |
| **Weighted Score** | **7.85/10** | **6.90/10** | **6.65/10** | - |

## Phased Deployment Strategy

### Phase 1: Docker Compose (Weeks 1-8) ✅

**Rationale**: Perfect for rapid development and initial deployment

```yaml
# docker-compose.yml - Production configuration
version: '3.8'

networks:
  sleeper-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.0.0/16

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  prometheus_data:
    driver: local
  grafana_data:
    driver: local

services:
  # Core Services
  postgres:
    image: postgres:15-alpine
    container_name: sleeper-postgres
    restart: unless-stopped
    networks:
      - sleeper-net
    ports:
      - "127.0.0.1:5432:5432"
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=en_US.UTF-8"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G

  redis:
    image: redis:7-alpine
    container_name: sleeper-redis
    restart: unless-stopped
    networks:
      - sleeper-net
    ports:
      - "127.0.0.1:6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

  hasura:
    image: hasura/graphql-engine:v2.36.0
    container_name: sleeper-hasura
    restart: unless-stopped
    networks:
      - sleeper-net
    ports:
      - "127.0.0.1:8080:8080"
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      HASURA_GRAPHQL_DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      HASURA_GRAPHQL_ENABLE_CONSOLE: "${HASURA_ENABLE_CONSOLE}"
      HASURA_GRAPHQL_DEV_MODE: "${HASURA_DEV_MODE}"
      HASURA_GRAPHQL_ADMIN_SECRET: "${HASURA_ADMIN_SECRET}"
      HASURA_GRAPHQL_UNAUTHORIZED_ROLE: anonymous
      HASURA_GRAPHQL_ENABLE_TELEMETRY: "false"
      HASURA_GRAPHQL_ENABLE_QUERY_CACHING: "true"
      HASURA_GRAPHQL_REDIS_URL: "redis://redis:6379"
      HASURA_GRAPHQL_RATE_LIMIT_REDIS_URL: "redis://redis:6379"
    volumes:
      - ./hasura/metadata:/hasura-metadata:ro
      - ./hasura/migrations:/hasura-migrations:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/healthz"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G

  sync-service:
    build:
      context: ./sync-service
      dockerfile: Dockerfile
      target: production
    image: sleeper-sync:latest
    container_name: sleeper-sync
    restart: unless-stopped
    networks:
      - sleeper-net
    ports:
      - "127.0.0.1:8000:8000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      REDIS_URL: redis://redis:6379
      SLEEPER_API_BASE_URL: ${SLEEPER_API_BASE_URL}
      PRIMARY_LEAGUE_ID: ${PRIMARY_LEAGUE_ID}
      LOG_LEVEL: ${LOG_LEVEL:-INFO}
      ENVIRONMENT: production
      GOMAXPROCS: 4
    healthcheck:
      test: ["CMD", "/sleeper-sync", "health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 512M  # Go uses much less memory
        reservations:
          cpus: '0.5'
          memory: 64M

  # Monitoring Stack
  prometheus:
    image: prom/prometheus:latest
    container_name: sleeper-prometheus
    restart: unless-stopped
    networks:
      - sleeper-net
    ports:
      - "127.0.0.1:9090:9090"
    volumes:
      - ./monitoring/prometheus:/etc/prometheus:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

  grafana:
    image: grafana/grafana:latest
    container_name: sleeper-grafana
    restart: unless-stopped
    networks:
      - sleeper-net
    ports:
      - "127.0.0.1:3000:3000"
    environment:
      GF_SECURITY_ADMIN_USER: ${GRAFANA_ADMIN_USER}
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD}
      GF_INSTALL_PLUGINS: redis-datasource
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning:ro
    depends_on:
      - prometheus
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M

  # Nginx Reverse Proxy (Production)
  nginx:
    image: nginx:alpine
    container_name: sleeper-nginx
    restart: unless-stopped
    networks:
      - sleeper-net
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
    depends_on:
      - hasura
      - sync-service
      - grafana
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
```

**Development Override:**
```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  postgres:
    ports:
      - "5432:5432"  # Expose for local development

  hasura:
    environment:
      HASURA_GRAPHQL_ENABLE_CONSOLE: "true"
      HASURA_GRAPHQL_DEV_MODE: "true"
    ports:
      - "8080:8080"  # Direct access

  sync-service:
    build:
      target: development  # Multi-stage build
    volumes:
      - ./sync-service/src:/app/src  # Live reload
    environment:
      RELOAD: "true"
    ports:
      - "8000:8000"  # Direct access
```

**Usage:**
```bash
# Development
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Production
docker-compose up -d

# Scaling manually
docker-compose up -d --scale sync-service=3
```

### Phase 2: Docker Swarm (Optional, Months 3-6)

**When to consider**: If you need basic orchestration without Kubernetes complexity

```yaml
# docker-stack.yml
version: '3.8'

services:
  sync-service:
    image: sleeper-sync:latest
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      placement:
        constraints:
          - node.role == worker
      resources:
        limits:
          cpus: '2'
          memory: 1G
        reservations:
          cpus: '1'
          memory: 512M
```

**Deployment:**
```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-stack.yml sleeper

# Scale service
docker service scale sleeper_sync-service=5
```

### Phase 3: Kubernetes (When needed)

**Migration triggers:**
- More than 10 leagues
- Need for auto-scaling
- Multi-region deployment
- Advanced traffic management
- Complex deployment strategies

```yaml
# kubernetes/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sync-service
  namespace: sleeper
spec:
  replicas: 3
  selector:
    matchLabels:
      app: sync-service
  template:
    metadata:
      labels:
        app: sync-service
    spec:
      containers:
      - name: sync-service
        image: sleeper-sync:latest
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: url
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: sync-service-hpa
  namespace: sleeper
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: sync-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## Development Workflow

### Local Development Setup

```bash
# Makefile for development workflow
.PHONY: help dev prod test clean

help:
	@echo "Available commands:"
	@echo "  make dev    - Start development environment"
	@echo "  make prod   - Start production environment"
	@echo "  make test   - Run tests"
	@echo "  make clean  - Clean up resources"

dev:
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

dev-build:
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache

prod:
	docker-compose up -d

logs:
	docker-compose logs -f

ps:
	docker-compose ps

restart:
	docker-compose restart $(service)

exec:
	docker-compose exec $(service) $(cmd)

test:
	docker-compose -f docker-compose.test.yml up --abort-on-container-exit
	docker-compose -f docker-compose.test.yml down

migrate:
	docker-compose exec hasura hasura migrate apply

clean:
	docker-compose down -v
	docker system prune -f
```

### CI/CD Pipeline

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: |
          docker-compose -f docker-compose.test.yml up --abort-on-container-exit
          
  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build images
        run: |
          docker-compose build
          docker-compose push
          
  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to server
        uses: appleboy/ssh-action@v0.1.5
        with:
          host: ${{ secrets.HOST }}
          username: ${{ secrets.USERNAME }}
          key: ${{ secrets.SSH_KEY }}
          script: |
            cd /opt/sleeper-db
            git pull
            docker-compose pull
            docker-compose up -d
```

## Monitoring & Operations

### Health Checks

```python
# sync-service/src/health.py
from fastapi import FastAPI, status
from typing import Dict
import asyncpg
import redis
import httpx

app = FastAPI()

@app.get("/health")
async def health_check() -> Dict:
    """Liveness probe"""
    return {"status": "healthy"}

@app.get("/ready")
async def readiness_check() -> Dict:
    """Readiness probe"""
    checks = {
        "database": False,
        "redis": False,
        "sleeper_api": False
    }
    
    # Check database
    try:
        conn = await asyncpg.connect(DATABASE_URL)
        await conn.fetchval("SELECT 1")
        await conn.close()
        checks["database"] = True
    except:
        pass
    
    # Check Redis
    try:
        r = redis.Redis.from_url(REDIS_URL)
        r.ping()
        checks["redis"] = True
    except:
        pass
    
    # Check Sleeper API
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{SLEEPER_API_BASE_URL}/state/nfl")
            checks["sleeper_api"] = response.status_code == 200
    except:
        pass
    
    all_healthy = all(checks.values())
    return {
        "ready": all_healthy,
        "checks": checks
    }
```

### Backup Strategy

```bash
#!/bin/bash
# scripts/backup.sh

# Backup PostgreSQL
docker-compose exec -T postgres pg_dump -U $POSTGRES_USER $POSTGRES_DB | gzip > backups/db_$(date +%Y%m%d_%H%M%S).sql.gz

# Backup volumes
docker run --rm -v sleeper-db_postgres_data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/postgres_data_$(date +%Y%m%d_%H%M%S).tar.gz -C /data .

# Backup Hasura metadata
docker-compose exec hasura hasura metadata export
tar czf backups/hasura_metadata_$(date +%Y%m%d_%H%M%S).tar.gz hasura/metadata/

# Rotate old backups (keep last 7 days)
find backups/ -name "*.gz" -mtime +7 -delete
```

## Go-Specific Deployment Benefits

### Container Size Comparison
| Runtime | Base Image | App Size | Total Size | Startup Time |
|---------|------------|----------|------------|--------------|
| Go | scratch | 8-12MB | 10-15MB | <100ms |
| Python | python:3.11-slim | 100MB+ | 150-200MB | 1-2s |
| Node.js | node:18-alpine | 80MB+ | 120-180MB | 500ms-1s |

### Go Dockerfile (Optimized)
```dockerfile
# Multi-stage build for minimal image
FROM golang:1.21-alpine AS builder

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache git make ca-certificates

# Copy go mod files for dependency caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build static binary with optimizations
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -extldflags '-static'" \
    -tags netgo \
    -o sleeper-sync ./cmd/sync

# Use UPX to compress binary further (optional)
RUN apk add --no-cache upx && \
    upx --best --lzma sleeper-sync

# Final stage - minimal image
FROM scratch

# Copy binary
COPY --from=builder /build/sleeper-sync /sleeper-sync

# Copy CA certificates for HTTPS
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy config file
COPY config/config.yaml /config.yaml

# Non-root user for security
USER 1000:1000

EXPOSE 8000

ENTRYPOINT ["/sleeper-sync"]
```

### Resource Usage Benefits with Go

#### Memory Efficiency
```yaml
# Go service can handle same load with 10x less memory
services:
  sync-service-go:
    deploy:
      resources:
        limits:
          memory: 256M  # Handles 10,000+ concurrent connections
        reservations:
          memory: 64M   # Minimal idle memory
  
  # Compared to Python equivalent
  sync-service-python:
    deploy:
      resources:
        limits:
          memory: 2G    # Needs more for same performance
        reservations:
          memory: 512M  # Higher baseline usage
```

#### CPU Efficiency
- Go routines are lightweight (2KB stack vs 1MB for OS threads)
- Can spawn 100,000+ goroutines on modest hardware
- Built-in work stealing scheduler optimizes CPU usage
- No GIL (Global Interpreter Lock) like Python

### Deployment Speed Advantages
```bash
# Go deployment
docker build -t sleeper-sync .  # 30 seconds
docker push sleeper-sync         # 10MB upload - 5 seconds
docker pull sleeper-sync         # 10MB download - 5 seconds
docker run sleeper-sync          # Instant startup

# Python deployment  
docker build -t sleeper-sync .  # 2-3 minutes
docker push sleeper-sync         # 150MB upload - 30 seconds
docker pull sleeper-sync         # 150MB download - 30 seconds
docker run sleeper-sync          # 1-2 second startup
```

### Scaling Benefits
```yaml
# Can run many more Go instances on same hardware
services:
  sync-service:
    deploy:
      replicas: 10  # 10 Go instances = ~500MB total
      # vs 10 Python instances = ~5GB total
```

## Cost Analysis

### Docker Compose (Single Server) - With Go
- **Server**: $10-20/month (DigitalOcean/Linode 2GB RAM) - Go needs less memory
- **Storage**: $10/month (100GB)
- **Backup**: $5/month
- **Total**: ~$25-35/month (40% cost reduction vs Python)

### Docker Swarm (3 nodes)
- **Servers**: $60-150/month (3x small instances)
- **Load Balancer**: $10/month
- **Storage**: $20/month
- **Total**: ~$90-180/month

### Kubernetes (Managed)
- **GKE/EKS/AKS**: $75/month (control plane)
- **Nodes**: $100-300/month (depending on size)
- **Storage**: $30/month
- **Load Balancer**: $20/month
- **Total**: ~$225-425/month

## Migration Path

### From Docker Compose to Swarm
1. Export volumes to shared storage
2. Push images to registry
3. Convert compose file to stack file
4. Initialize swarm and deploy

### From Docker Compose/Swarm to Kubernetes
1. Convert compose to Kubernetes manifests (using Kompose)
2. Set up persistent volumes
3. Configure ingress
4. Deploy with kubectl/Helm

```bash
# Using Kompose for migration
kompose convert -f docker-compose.yml -o kubernetes/
```

## Final Recommendation

### Start with Docker Compose because:
1. **Fastest time to market** - Can deploy in hours, not days
2. **Lowest operational overhead** - Single docker-compose.yml to maintain
3. **Perfect for current scale** - Handles 100+ concurrent users easily
4. **Easy debugging** - Direct access to containers and logs
5. **Cost effective** - Runs on single $40/month server

### Migration triggers to Kubernetes:
- User base exceeds 1000 concurrent users
- Need for zero-downtime deployments
- Multi-region requirements
- Complex traffic management needs
- Team has Kubernetes expertise

### Success metrics to monitor:
- Response time > 500ms consistently
- Memory usage > 80% consistently  
- Need for > 3 service replicas
- Manual scaling becomes painful
- Deployment frequency > 5 per day

The pragmatic approach of starting simple with Docker Compose while maintaining clean architecture for future migration provides the best balance of development velocity and production readiness.