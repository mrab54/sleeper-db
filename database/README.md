# Sleeper Database Architecture

## Overview

This project uses a **two-database architecture** for optimal data management:

1. **Raw Database** (`sleeper_raw`) - Stores API responses exactly as received
2. **Analytics Database** (`sleeper_db`) - Normalized, queryable data for applications

## Database Structure

```
database/
├── raw/                    # Raw database (API responses)
│   └── 00-init.sql        # Creates tables for storing raw API data
│
├── analytics/             # Analytics database (normalized)
│   └── 00-init.sql        # Creates normalized tables with proper relationships
│
└── migrations/            # Future schema changes
    └── *.sql              # Migration files (not used during initial setup)
```

## Raw Database (`sleeper_raw`)

**Port**: 5434 (host) → 5432 (container)  
**Container**: `sleeper-postgres-raw`

### Purpose
- Stores every API response with metadata
- Provides audit trail and replay capability
- Enables change detection before processing
- Debugging and data recovery

### Key Tables
- `raw.api_responses` - Generic storage for all endpoints
- `raw.leagues` - League-specific responses
- `raw.rosters` - Roster arrays by league
- `raw.matchups` - Weekly matchup data
- `raw.transactions` - Transaction data by week
- `raw.players` - Full NFL player database
- `raw.sync_runs` - Track sync operations
- `raw.sync_endpoints` - Track individual API calls

### Features
- Response hashing for change detection
- Processing status tracking (new → processing → processed)
- Built-in monitoring views
- Append-only design (never deletes data)

## Analytics Database (`sleeper_db`)

**Port**: 5433 (host) → 5432 (container)  
**Container**: `sleeper-postgres`

### Purpose
- Normalized data structure for efficient querying
- Proper foreign key relationships
- Optimized for application use
- Support for complex analytics

### Key Tables
- `sleeper.users` - Platform users
- `sleeper.leagues` - Fantasy leagues
- `sleeper.players` - NFL players
- `sleeper.rosters` - Team rosters with standings
- `sleeper.roster_players` - Player-roster relationships
- `sleeper.matchups` - Weekly matchups
- `sleeper.transactions` - Trades, waivers, adds/drops
- `sleeper.sync_log` - Sync operation tracking (partitioned)

### Features
- 3NF normalized design
- Foreign key constraints
- Optimized indexes
- Partitioned tables for performance
- Cascade deletes for data integrity

## Connecting to Databases

### From Host Machine

```bash
# Raw database
psql -h localhost -p 5434 -U sleeper_user -d sleeper_raw

# Analytics database
psql -h localhost -p 5433 -U sleeper_user -d sleeper_db
```

### From Docker

```bash
# Raw database
docker exec -it sleeper-postgres-raw psql -U sleeper_user -d sleeper_raw

# Analytics database
docker exec -it sleeper-postgres psql -U sleeper_user -d sleeper_db
```

### Connection Strings

```
# Raw database
postgresql://sleeper_user:password@localhost:5434/sleeper_raw

# Analytics database
postgresql://sleeper_user:password@localhost:5433/sleeper_db
```

## ETL Flow

```
Sleeper API → Raw Database → ETL Process → Analytics Database → Application
                    ↓                              ↓
               (Append Only)                  (Normalized)
               (JSON Storage)                 (Relational)
```

## Initialization

Both databases are automatically initialized when you run:

```bash
docker-compose up -d
```

The initialization scripts run in this order:

1. **Raw Database**: `/database/raw/00-init.sql`
2. **Analytics Database**: `/database/analytics/00-init.sql`

## Monitoring

### Check Database Health

```sql
-- Raw database: See latest fetches
SELECT * FROM raw.v_latest_fetches;

-- Raw database: Check sync health
SELECT * FROM raw.v_sync_health;

-- Analytics database: Check data freshness
SELECT 
    'rosters' as table_name,
    MAX(updated_at) as last_update,
    COUNT(*) as records
FROM sleeper.rosters;
```

### View Recent Changes

```sql
-- Raw database: See what data changed
SELECT * FROM raw.v_recent_changes
WHERE fetched_at > NOW() - INTERVAL '1 hour';
```

## Backup and Restore

### Backup

```bash
# Backup raw database
docker exec sleeper-postgres-raw pg_dump -U sleeper_user sleeper_raw > backup_raw_$(date +%Y%m%d).sql

# Backup analytics database  
docker exec sleeper-postgres pg_dump -U sleeper_user sleeper_db > backup_analytics_$(date +%Y%m%d).sql
```

### Restore

```bash
# Restore raw database
docker exec -i sleeper-postgres-raw psql -U sleeper_user sleeper_raw < backup_raw_20250824.sql

# Restore analytics database
docker exec -i sleeper-postgres psql -U sleeper_user sleeper_db < backup_analytics_20250824.sql
```

## Troubleshooting

### Reset Databases

```bash
# Stop services
docker-compose down

# Remove volumes (DESTROYS ALL DATA!)
docker volume rm sleeper-db_postgres_data sleeper-db_postgres_raw_data

# Restart
docker-compose up -d
```

### Check Logs

```bash
# Raw database logs
docker logs sleeper-postgres-raw

# Analytics database logs
docker logs sleeper-postgres
```

### Common Issues

1. **"database does not exist"** - The databases are created on first startup
2. **"relation does not exist"** - Check if init scripts ran successfully
3. **Port conflicts** - Ensure ports 5433 and 5434 are available

## Development Tips

1. **Start with raw database** - Get API data flowing first
2. **Test ETL locally** - Use small datasets initially
3. **Monitor processing status** - Check for stuck records
4. **Use transactions** - Ensure data consistency during ETL
5. **Index strategically** - Add indexes based on actual query patterns

## Next Steps

1. Implement extraction service to populate raw database
2. Build ETL pipeline to transform data
3. Create API endpoints for querying analytics database
4. Set up monitoring dashboards in Grafana
5. Configure automated backups