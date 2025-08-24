-- ============================================================================
-- PostgreSQL Extensions Setup
-- ============================================================================

-- Connect to the database
\c sleeper_db

-- UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA public;

-- Cryptographic functions
CREATE EXTENSION IF NOT EXISTS "pgcrypto" SCHEMA public;

-- Trigram similarity for fuzzy text search
CREATE EXTENSION IF NOT EXISTS "pg_trgm" SCHEMA public;

-- Additional useful extensions
CREATE EXTENSION IF NOT EXISTS "btree_gist" SCHEMA public;  -- For exclusion constraints
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" SCHEMA public;  -- Query performance monitoring

-- Grant usage on extensions to sleeper_user
GRANT USAGE ON SCHEMA public TO sleeper_user;