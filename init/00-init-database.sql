-- Sleeper Fantasy Football Database Initialization
-- PostgreSQL 17
--
-- This script sets up the database structure and schemas
-- This runs FIRST before all other scripts

-- ============================================================================
-- DATABASE CONFIGURATION
-- ============================================================================

-- Set database parameters for better performance
ALTER DATABASE sleeper_db SET statement_timeout = '30min';
ALTER DATABASE sleeper_db SET lock_timeout = '10s';
ALTER DATABASE sleeper_db SET idle_in_transaction_session_timeout = '10min';

-- ============================================================================
-- SCHEMA STRUCTURE
-- ============================================================================

-- Create main schema for Sleeper data
CREATE SCHEMA IF NOT EXISTS sleeper;
COMMENT ON SCHEMA sleeper IS 'Main schema for Sleeper fantasy football data';

-- ============================================================================
-- PERMISSIONS
-- ============================================================================

-- Grant permissions on schema
GRANT USAGE ON SCHEMA sleeper TO sleeper_user;
GRANT CREATE ON SCHEMA sleeper TO sleeper_user;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA sleeper 
GRANT ALL ON TABLES TO sleeper_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA sleeper 
GRANT ALL ON SEQUENCES TO sleeper_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA sleeper 
GRANT EXECUTE ON FUNCTIONS TO sleeper_user;

-- ============================================================================
-- SEARCH PATH
-- ============================================================================

-- Set the default search path for the database
ALTER DATABASE sleeper_db SET search_path TO sleeper, public;

-- Set search path for current session
SET search_path TO sleeper, public;

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

-- Install useful extensions in public schema
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "pgcrypto" SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "pg_trgm" SCHEMA public; -- For text search

-- ============================================================================
-- DATABASE INFO
-- ============================================================================

-- Create a version tracking table in public schema
CREATE TABLE IF NOT EXISTS public.db_version (
    version VARCHAR(20) PRIMARY KEY,
    description TEXT,
    installed_at TIMESTAMP NOT NULL DEFAULT NOW(),
    installed_by VARCHAR(100) DEFAULT CURRENT_USER
);

-- Insert initial version
INSERT INTO public.db_version (version, description) 
VALUES ('1.0.0', 'Initial database schema for Sleeper fantasy football')
ON CONFLICT (version) DO NOTHING;

-- Display database info
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Sleeper Fantasy Football Database';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Database: %', current_database();
    RAISE NOTICE 'User: %', current_user;
    RAISE NOTICE 'Schema Created: sleeper';
    RAISE NOTICE 'Default Schema: sleeper';
    RAISE NOTICE 'Version: 1.0.0';
    RAISE NOTICE '================================================';
    RAISE NOTICE '';
END $$;