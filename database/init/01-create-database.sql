-- ============================================================================
-- Database Creation Script
-- ============================================================================

-- Create database if it doesn't exist (run as superuser)
SELECT 'CREATE DATABASE sleeper_db'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'sleeper_db')\gexec

-- Connect to the database
\c sleeper_db

-- Create sleeper schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS sleeper;

-- Set default search path
ALTER DATABASE sleeper_db SET search_path TO sleeper, public;

-- Grant privileges
GRANT ALL PRIVILEGES ON SCHEMA sleeper TO sleeper_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA sleeper TO sleeper_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA sleeper TO sleeper_user;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA sleeper TO sleeper_user;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA sleeper
    GRANT ALL PRIVILEGES ON TABLES TO sleeper_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA sleeper
    GRANT ALL PRIVILEGES ON SEQUENCES TO sleeper_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA sleeper
    GRANT ALL PRIVILEGES ON FUNCTIONS TO sleeper_user;