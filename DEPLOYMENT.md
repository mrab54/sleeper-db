# Deployment Guide

This guide covers building and deploying the Sleeper Fantasy Football Database with sync service.

## Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM available
- 10GB+ disk space
- (Optional) Domain name for production deployment

## Quick Start (Development)

### 1. Clone and Configure

```bash
# Clone the repository
git clone https://github.com/yourusername/sleeper-db.git
cd sleeper-db

# Copy and edit environment variables
cp .env.example .env
# Edit .env with your preferred editor
# IMPORTANT: Change all password/secret values!
```

### 2. Build and Start Services

```bash
# Build and start all services
make up

# Or manually:
docker compose up -d --build

# Check service status
make ps
```

### 3. Verify Services

```bash
# Check health of services
curl http://localhost:8082/health  # Sync service
curl http://localhost:8080/healthz  # Hasura
curl http://localhost:8081          # API docs

# View logs
make logs-sync     # Sync service logs
make logs-hasura   # Hasura logs
make logs-db       # Database logs
```

### 4. Initialize Data

```bash
# Option 1: Sync a specific user's leagues (recommended for testing)
make sync-user USER_ID=your_username

# Option 2: Run full sync (takes longer, ~5-10 minutes)
make sync-all

# Option 3: If you have a league ID
make sync-league LEAGUE_ID=your_league_id
```

## Production Deployment

### 1. Server Requirements

- **Minimum**: 2 CPU cores, 4GB RAM, 20GB disk
- **Recommended**: 4 CPU cores, 8GB RAM, 50GB SSD
- **OS**: Ubuntu 20.04+ or similar Linux distribution
- **Docker**: Version 20.10+ with Docker Compose v2

### 2. Security Setup

```bash
# Create secure passwords
openssl rand -base64 32  # For POSTGRES_PASSWORD
openssl rand -base64 32  # For HASURA_ADMIN_SECRET
openssl rand -base64 32  # For WEBHOOK_SECRET

# Update .env with secure values
nano .env
```

### 3. Production Deployment

```bash
# Use production compose file
docker compose -f docker-compose.prod.yml up -d --build

# Or with override
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### 4. Configure Scheduled Syncs

The sync service includes webhook endpoints for Hasura scheduled triggers:

```bash
# Apply Hasura metadata (includes cron triggers)
curl -X POST http://localhost:8080/v1/metadata \
  -H "X-Hasura-Admin-Secret: your-admin-secret" \
  -d '{"type": "reload_metadata"}'
```

Scheduled syncs will run automatically:
- **Full sync**: Daily at 3 AM UTC
- **Incremental sync**: Every 5 minutes

### 5. Manual Sync Commands

```bash
# Full sync - syncs all data
docker exec sleeper-sync /app/sleeper-sync sync all

# Incremental sync - only active leagues
docker exec sleeper-sync /app/sleeper-sync sync incremental

# Sync specific league
docker exec sleeper-sync /app/sleeper-sync sync league LEAGUE_ID

# Sync user's leagues
docker exec sleeper-sync /app/sleeper-sync sync user USER_ID
```

## Monitoring

### Health Checks

```bash
# Sync service health
curl http://localhost:8082/health

# Database connection
docker exec sleeper-postgres pg_isready

# Hasura health
curl http://localhost:8080/healthz
```

### Metrics

Prometheus metrics are available at:
```bash
curl http://localhost:9090/metrics
```

Key metrics to monitor:
- Sync duration
- API request rate
- Database connection pool
- Error rates

### Logs

```bash
# All logs
docker compose logs -f

# Specific service logs
docker compose logs -f sync
docker compose logs -f postgres
docker compose logs -f hasura

# Last 100 lines
docker compose logs --tail=100 sync
```

## Backup and Recovery

### Database Backup

```bash
# Backup database
docker exec sleeper-postgres pg_dump -U sleeper_user sleeper_db > backup_$(date +%Y%m%d).sql

# Backup with compression
docker exec sleeper-postgres pg_dump -U sleeper_user -Fc sleeper_db > backup_$(date +%Y%m%d).dump

# Automated daily backup (add to crontab)
0 2 * * * docker exec sleeper-postgres pg_dump -U sleeper_user sleeper_db | gzip > /backups/sleeper_$(date +\%Y\%m\%d).sql.gz
```

### Database Restore

```bash
# Restore from SQL backup
docker exec -i sleeper-postgres psql -U sleeper_user sleeper_db < backup.sql

# Restore from compressed backup
docker exec -i sleeper-postgres pg_restore -U sleeper_user -d sleeper_db < backup.dump
```

## Troubleshooting

### Common Issues

#### 1. Sync Service Won't Start
```bash
# Check logs
docker compose logs sync

# Verify database is ready
docker exec sleeper-postgres pg_isready

# Check config file
cat sleeper-sync/config.yaml
```

#### 2. Database Connection Failed
```bash
# Verify credentials
docker compose exec postgres psql -U sleeper_user -d sleeper_db

# Check network
docker network ls
docker network inspect sleeper-db_sleeper-net
```

#### 3. API Rate Limiting
```bash
# Check current rate limit usage in logs
docker compose logs sync | grep "rate limit"

# Adjust rate limit in config.yaml
# rate_limit_per_minute: 900  # Default
```

#### 4. Out of Memory
```bash
# Check memory usage
docker stats

# Increase limits in docker-compose.prod.yml
# deploy:
#   resources:
#     limits:
#       memory: 1G  # Increase as needed
```

### Reset Everything

```bash
# Stop and remove everything
make clean

# Remove all data (WARNING: Deletes all data!)
docker compose down -v
rm -rf postgres_data/

# Fresh start
make up
make sync-user USER_ID=your_username
```

## Performance Tuning

### Database Optimization

Edit PostgreSQL settings in docker-compose.prod.yml:
```yaml
command: >
  postgres
  -c max_connections=200
  -g shared_buffers=512MB  # 25% of RAM
  -c effective_cache_size=2GB  # 50-75% of RAM
  -c maintenance_work_mem=128MB
  -c work_mem=4MB
```

### Sync Service Optimization

Edit sleeper-sync/config.yaml:
```yaml
sync:
  league_batch_size: 20  # Increase for more parallelism
  roster_batch_size: 200  # Increase for larger batches
  
database:
  max_connections: 50  # Increase connection pool
```

## Updating

### Update to Latest Version

```bash
# Pull latest changes
git pull origin main

# Rebuild services
docker compose build --no-cache

# Restart with new version
docker compose down
docker compose up -d
```

### Database Migrations

```bash
# Run migrations (if any)
docker exec sleeper-postgres psql -U sleeper_user -d sleeper_db -f /docker-entrypoint-initdb.d/migrations.sql
```

## Security Best Practices

1. **Change all default passwords** in .env
2. **Use HTTPS** in production (nginx reverse proxy)
3. **Restrict database access** to localhost only
4. **Enable Hasura authentication** for production
5. **Regular backups** with offsite storage
6. **Monitor logs** for suspicious activity
7. **Keep Docker images updated**

## Support

- Check logs first: `make logs`
- Database issues: `make db-console`
- Sync issues: `make logs-sync`
- API issues: Check http://localhost:8081 for documentation

## Additional Resources

- [Sleeper API Documentation](https://docs.sleeper.com)
- [Hasura Documentation](https://hasura.io/docs)
- [PostgreSQL Tuning](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server)