# Database Migrations

This directory contains database migration files for the Sleeper DB project.

## Migration Tool

We use [golang-migrate](https://github.com/golang-migrate/migrate) for managing database migrations.

## Installation

```bash
# Install migrate CLI
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest

# Or use the provided script
./scripts/migrate.sh
```

## Usage

### Run all pending migrations
```bash
make db-migrate-up
# or
./scripts/migrate.sh up
```

### Rollback last migration
```bash
make db-migrate-down
# or
./scripts/migrate.sh down
```

### Create a new migration
```bash
make db-migrate-create NAME=add_new_table
# or
./scripts/migrate.sh create add_new_table
```

### Check current version
```bash
make db-migrate-version
# or
./scripts/migrate.sh version
```

### Force a specific version (use with caution)
```bash
./scripts/migrate.sh force 3
```

## Migration Files

Each migration consists of two files:
- `*.up.sql` - Forward migration
- `*.down.sql` - Rollback migration

Example:
- `000001_initial_schema.up.sql` - Creates initial database schema
- `000001_initial_schema.down.sql` - Drops all schema objects

## Best Practices

1. **Always test migrations** in a development environment first
2. **Keep migrations idempotent** where possible (use `IF NOT EXISTS`, `IF EXISTS`)
3. **Never edit existing migrations** that have been applied to production
4. **Include rollback logic** in down migrations
5. **Use transactions** for data migrations when possible
6. **Document complex migrations** with comments

## Migration Naming Convention

```
NNNNNN_description.up.sql
NNNNNN_description.down.sql
```

Where:
- `NNNNNN` is a 6-digit sequence number (automatically generated)
- `description` is a brief description using underscores

## Example Migration

```sql
-- 000002_add_user_preferences.up.sql
BEGIN;

CREATE TABLE IF NOT EXISTS sleeper.user_preferences (
    user_id VARCHAR(50) PRIMARY KEY REFERENCES sleeper.users(user_id),
    theme VARCHAR(20) DEFAULT 'light',
    notifications_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER update_user_preferences_updated_at 
    BEFORE UPDATE ON sleeper.user_preferences
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

COMMIT;
```

```sql
-- 000002_add_user_preferences.down.sql
BEGIN;

DROP TRIGGER IF EXISTS update_user_preferences_updated_at ON sleeper.user_preferences;
DROP TABLE IF EXISTS sleeper.user_preferences;

COMMIT;
```

## Troubleshooting

### Migration is stuck
If a migration fails partway through:
1. Check the `schema_migrations` table for the current version
2. Fix the issue in the database manually if needed
3. Use `migrate force <version>` to reset the migration state
4. Re-run migrations

### Connection issues
Ensure your database connection string is correct:
```
postgres://user:password@host:port/database?sslmode=disable&search_path=sleeper
```

### Schema not found
Make sure the `sleeper` schema exists:
```sql
CREATE SCHEMA IF NOT EXISTS sleeper;
```

## CI/CD Integration

Migrations should be run as part of the deployment process:

```yaml
# Example GitHub Actions step
- name: Run migrations
  run: |
    migrate -path ./database/migrations \
            -database "$DATABASE_URL" \
            up
```

## Backup Before Migration

Always backup the database before running migrations in production:

```bash
make db-backup
make db-migrate-up
```
