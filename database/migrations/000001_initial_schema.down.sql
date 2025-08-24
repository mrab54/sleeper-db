-- Migration: 000001_initial_schema (rollback)
-- Description: Drops all schema objects
-- Date: 2025-08-24

-- Drop schema and all objects
DROP SCHEMA IF EXISTS sleeper CASCADE;

-- Drop extensions if needed
DROP EXTENSION IF EXISTS "uuid-ossp";
DROP EXTENSION IF EXISTS "pgcrypto";
DROP EXTENSION IF EXISTS "pg_trgm";
DROP EXTENSION IF EXISTS "btree_gist";
DROP EXTENSION IF EXISTS "pg_stat_statements";
