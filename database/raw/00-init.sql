-- Sleeper Raw API Database Schema
-- This database stores API responses exactly as received from Sleeper
-- No transformation, no normalization - just raw data storage
-- Last Updated: 2025-08-24

-- ============================================================================
-- DATABASE SETUP
-- ============================================================================

-- This should be run as superuser to create the database
-- CREATE DATABASE sleeper_raw;

-- Create schema for raw data
CREATE SCHEMA IF NOT EXISTS raw;

-- Set default search path
SET search_path TO raw, public;

-- ============================================================================
-- MAIN API RESPONSES TABLE
-- Stores every API call response with metadata
-- ============================================================================

CREATE TABLE IF NOT EXISTS raw.api_responses (
    id BIGSERIAL PRIMARY KEY,
    
    -- Request metadata
    endpoint VARCHAR(500) NOT NULL,        -- '/league/123/rosters'
    endpoint_type VARCHAR(100),            -- 'league', 'rosters', 'matchups', etc.
    request_method VARCHAR(10) DEFAULT 'GET',
    request_params JSONB,                  -- Query parameters if any
    request_headers JSONB,                  -- Headers sent
    
    -- Response metadata
    response_status INTEGER,                -- HTTP status code (200, 404, etc.)
    response_headers JSONB,                 -- Headers received (rate limit info, etc.)
    response_time_ms INTEGER,               -- Response time in milliseconds
    
    -- Response data
    response_body JSONB NOT NULL,          -- The actual API response
    response_hash VARCHAR(64),              -- SHA256 hash for change detection
    response_size_bytes INTEGER,           -- Size of response
    
    -- Processing metadata
    processing_status VARCHAR(50) DEFAULT 'new',  -- new, processing, processed, failed, skipped
    processed_at TIMESTAMP WITH TIME ZONE,
    processing_notes TEXT,
    
    -- Timestamps
    fetched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for efficient querying
CREATE INDEX idx_api_responses_endpoint ON raw.api_responses(endpoint);
CREATE INDEX idx_api_responses_endpoint_type ON raw.api_responses(endpoint_type);
CREATE INDEX idx_api_responses_fetched_at ON raw.api_responses(fetched_at DESC);
CREATE INDEX idx_api_responses_processing ON raw.api_responses(processing_status, fetched_at);
CREATE INDEX idx_api_responses_endpoint_latest ON raw.api_responses(endpoint, fetched_at DESC);
CREATE INDEX idx_api_responses_hash ON raw.api_responses(response_hash);

-- ============================================================================
-- ENTITY-SPECIFIC TABLES
-- Optimized storage for specific endpoint types with better querying
-- ============================================================================

-- League responses
CREATE TABLE IF NOT EXISTS raw.leagues (
    id BIGSERIAL PRIMARY KEY,
    league_id VARCHAR(255) NOT NULL,
    response_body JSONB NOT NULL,
    response_hash VARCHAR(64),
    processing_status VARCHAR(50) DEFAULT 'new',
    processed_at TIMESTAMP WITH TIME ZONE,
    fetched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_raw_leagues_league_id ON raw.leagues(league_id, fetched_at DESC);
CREATE INDEX idx_raw_leagues_processing ON raw.leagues(processing_status, fetched_at);
CREATE INDEX idx_raw_leagues_hash ON raw.leagues(league_id, response_hash);

-- User responses
CREATE TABLE IF NOT EXISTS raw.users (
    id BIGSERIAL PRIMARY KEY,
    league_id VARCHAR(255),                -- NULL for individual user lookups
    user_id VARCHAR(255),                  -- NULL for league user lists
    response_body JSONB NOT NULL,          -- Single user or array of users
    response_hash VARCHAR(64),
    processing_status VARCHAR(50) DEFAULT 'new',
    processed_at TIMESTAMP WITH TIME ZONE,
    fetched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_raw_users_league ON raw.users(league_id, fetched_at DESC);
CREATE INDEX idx_raw_users_user ON raw.users(user_id, fetched_at DESC);
CREATE INDEX idx_raw_users_processing ON raw.users(processing_status, fetched_at);

-- Roster responses
CREATE TABLE IF NOT EXISTS raw.rosters (
    id BIGSERIAL PRIMARY KEY,
    league_id VARCHAR(255) NOT NULL,
    response_body JSONB NOT NULL,          -- Array of rosters
    response_hash VARCHAR(64),
    processing_status VARCHAR(50) DEFAULT 'new',
    processed_at TIMESTAMP WITH TIME ZONE,
    fetched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_raw_rosters_league ON raw.rosters(league_id, fetched_at DESC);
CREATE INDEX idx_raw_rosters_processing ON raw.rosters(processing_status, fetched_at);
CREATE INDEX idx_raw_rosters_hash ON raw.rosters(league_id, response_hash);

-- Matchup responses
CREATE TABLE IF NOT EXISTS raw.matchups (
    id BIGSERIAL PRIMARY KEY,
    league_id VARCHAR(255) NOT NULL,
    week INTEGER NOT NULL,
    response_body JSONB NOT NULL,          -- Array of matchups
    response_hash VARCHAR(64),
    processing_status VARCHAR(50) DEFAULT 'new',
    processed_at TIMESTAMP WITH TIME ZONE,
    fetched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_raw_matchups_league_week ON raw.matchups(league_id, week, fetched_at DESC);
CREATE INDEX idx_raw_matchups_processing ON raw.matchups(processing_status, fetched_at);
CREATE INDEX idx_raw_matchups_hash ON raw.matchups(league_id, week, response_hash);

-- Transaction responses
CREATE TABLE IF NOT EXISTS raw.transactions (
    id BIGSERIAL PRIMARY KEY,
    league_id VARCHAR(255) NOT NULL,
    week INTEGER NOT NULL,                 -- Leg/round number
    response_body JSONB NOT NULL,          -- Array of transactions
    response_hash VARCHAR(64),
    processing_status VARCHAR(50) DEFAULT 'new',
    processed_at TIMESTAMP WITH TIME ZONE,
    fetched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_raw_transactions_league_week ON raw.transactions(league_id, week, fetched_at DESC);
CREATE INDEX idx_raw_transactions_processing ON raw.transactions(processing_status, fetched_at);
CREATE INDEX idx_raw_transactions_hash ON raw.transactions(league_id, week, response_hash);

-- Player responses (all NFL players)
CREATE TABLE IF NOT EXISTS raw.players (
    id BIGSERIAL PRIMARY KEY,
    sport VARCHAR(10) DEFAULT 'nfl',
    response_body JSONB NOT NULL,          -- Entire player database
    response_hash VARCHAR(64),
    response_size_mb DECIMAL(10,2),        -- These can be large (10+ MB)
    processing_status VARCHAR(50) DEFAULT 'new',
    processed_at TIMESTAMP WITH TIME ZONE,
    fetched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_raw_players_sport ON raw.players(sport, fetched_at DESC);
CREATE INDEX idx_raw_players_processing ON raw.players(processing_status, fetched_at);

-- Draft responses
CREATE TABLE IF NOT EXISTS raw.drafts (
    id BIGSERIAL PRIMARY KEY,
    draft_id VARCHAR(255) NOT NULL,
    response_body JSONB NOT NULL,
    response_hash VARCHAR(64),
    processing_status VARCHAR(50) DEFAULT 'new',
    processed_at TIMESTAMP WITH TIME ZONE,
    fetched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_raw_drafts_draft_id ON raw.drafts(draft_id, fetched_at DESC);
CREATE INDEX idx_raw_drafts_processing ON raw.drafts(processing_status, fetched_at);

-- Draft picks responses
CREATE TABLE IF NOT EXISTS raw.draft_picks (
    id BIGSERIAL PRIMARY KEY,
    draft_id VARCHAR(255) NOT NULL,
    response_body JSONB NOT NULL,          -- Array of picks
    response_hash VARCHAR(64),
    processing_status VARCHAR(50) DEFAULT 'new',
    processed_at TIMESTAMP WITH TIME ZONE,
    fetched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_raw_draft_picks_draft ON raw.draft_picks(draft_id, fetched_at DESC);
CREATE INDEX idx_raw_draft_picks_processing ON raw.draft_picks(processing_status, fetched_at);

-- NFL state responses
CREATE TABLE IF NOT EXISTS raw.nfl_state (
    id BIGSERIAL PRIMARY KEY,
    response_body JSONB NOT NULL,
    response_hash VARCHAR(64),
    processing_status VARCHAR(50) DEFAULT 'new',
    processed_at TIMESTAMP WITH TIME ZONE,
    fetched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_raw_nfl_state_fetched ON raw.nfl_state(fetched_at DESC);

-- ============================================================================
-- SYNC MANAGEMENT TABLES
-- ============================================================================

-- Track sync runs
CREATE TABLE IF NOT EXISTS raw.sync_runs (
    id BIGSERIAL PRIMARY KEY,
    sync_id UUID DEFAULT gen_random_uuid(),
    sync_type VARCHAR(50),                 -- 'full', 'incremental', 'catchup'
    league_id VARCHAR(255),
    
    -- Timing
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    duration_seconds INTEGER,
    
    -- Status
    status VARCHAR(50) DEFAULT 'running',  -- running, completed, failed, partial
    
    -- Metrics
    endpoints_called INTEGER DEFAULT 0,
    records_fetched INTEGER DEFAULT 0,
    records_changed INTEGER DEFAULT 0,
    bytes_fetched BIGINT DEFAULT 0,
    
    -- Error tracking
    errors INTEGER DEFAULT 0,
    error_details JSONB,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_sync_runs_league ON raw.sync_runs(league_id, started_at DESC);
CREATE INDEX idx_sync_runs_status ON raw.sync_runs(status, started_at DESC);
CREATE INDEX idx_sync_runs_sync_id ON raw.sync_runs(sync_id);

-- Track individual endpoint syncs within a run
CREATE TABLE IF NOT EXISTS raw.sync_endpoints (
    id BIGSERIAL PRIMARY KEY,
    sync_id UUID NOT NULL,
    endpoint VARCHAR(500) NOT NULL,
    
    -- Timing
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    duration_ms INTEGER,
    
    -- Status
    status VARCHAR(50) DEFAULT 'running',
    http_status INTEGER,
    
    -- Data
    records_count INTEGER,
    response_size_bytes INTEGER,
    data_changed BOOLEAN DEFAULT false,
    
    -- Error info
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_sync_endpoints_sync_id ON raw.sync_endpoints(sync_id);
CREATE INDEX idx_sync_endpoints_endpoint ON raw.sync_endpoints(endpoint, started_at DESC);

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Function to calculate response hash
CREATE OR REPLACE FUNCTION raw.calculate_hash(data JSONB)
RETURNS VARCHAR(64) AS $$
BEGIN
    RETURN encode(sha256(data::text::bytea), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to check if data has changed
CREATE OR REPLACE FUNCTION raw.data_changed(
    p_endpoint VARCHAR,
    p_new_hash VARCHAR
) RETURNS BOOLEAN AS $$
DECLARE
    v_last_hash VARCHAR;
BEGIN
    SELECT response_hash INTO v_last_hash
    FROM raw.api_responses
    WHERE endpoint = p_endpoint
    ORDER BY fetched_at DESC
    LIMIT 1;
    
    RETURN v_last_hash IS NULL OR v_last_hash != p_new_hash;
END;
$$ LANGUAGE plpgsql;

-- Function to get latest response for an endpoint
CREATE OR REPLACE FUNCTION raw.get_latest(
    p_endpoint VARCHAR
) RETURNS JSONB AS $$
DECLARE
    v_response JSONB;
BEGIN
    SELECT response_body INTO v_response
    FROM raw.api_responses
    WHERE endpoint = p_endpoint
    ORDER BY fetched_at DESC
    LIMIT 1;
    
    RETURN v_response;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- VIEWS FOR MONITORING
-- ============================================================================

-- View to see latest data per endpoint
CREATE OR REPLACE VIEW raw.v_latest_fetches AS
SELECT DISTINCT ON (endpoint)
    endpoint,
    endpoint_type,
    response_status,
    response_size_bytes,
    processing_status,
    fetched_at,
    NOW() - fetched_at as age
FROM raw.api_responses
ORDER BY endpoint, fetched_at DESC;

-- View to see sync health
CREATE OR REPLACE VIEW raw.v_sync_health AS
SELECT 
    endpoint_type,
    COUNT(*) as total_fetches,
    COUNT(CASE WHEN processing_status = 'processed' THEN 1 END) as processed,
    COUNT(CASE WHEN processing_status = 'failed' THEN 1 END) as failed,
    AVG(response_time_ms) as avg_response_ms,
    MAX(fetched_at) as last_fetch,
    NOW() - MAX(fetched_at) as time_since_fetch
FROM raw.api_responses
WHERE fetched_at > NOW() - INTERVAL '24 hours'
GROUP BY endpoint_type;

-- View to see data changes
CREATE OR REPLACE VIEW raw.v_recent_changes AS
WITH ranked AS (
    SELECT 
        endpoint,
        response_hash,
        fetched_at,
        LAG(response_hash) OVER (PARTITION BY endpoint ORDER BY fetched_at) as prev_hash
    FROM raw.api_responses
    WHERE fetched_at > NOW() - INTERVAL '24 hours'
)
SELECT 
    endpoint,
    fetched_at,
    CASE WHEN response_hash != prev_hash THEN 'changed' ELSE 'unchanged' END as status
FROM ranked
WHERE prev_hash IS NOT NULL
ORDER BY fetched_at DESC;

-- ============================================================================
-- PERMISSIONS
-- ============================================================================

-- Grant permissions (adjust user as needed)
GRANT ALL PRIVILEGES ON SCHEMA raw TO sleeper_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA raw TO sleeper_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA raw TO sleeper_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA raw TO sleeper_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT ALL ON TABLES TO sleeper_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT ALL ON SEQUENCES TO sleeper_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT EXECUTE ON FUNCTIONS TO sleeper_user;

-- ============================================================================
-- MAINTENANCE SETTINGS
-- ============================================================================

-- Enable JSONB compression for large responses
ALTER TABLE raw.api_responses SET (toast_tuple_target = 128);
ALTER TABLE raw.players SET (toast_tuple_target = 128);

-- Add table comments
COMMENT ON SCHEMA raw IS 'Raw API response storage from Sleeper Fantasy Football API';
COMMENT ON TABLE raw.api_responses IS 'Generic storage for all API responses with metadata';
COMMENT ON TABLE raw.leagues IS 'League-specific API responses';
COMMENT ON TABLE raw.rosters IS 'Roster endpoint responses (array of rosters per league)';
COMMENT ON TABLE raw.matchups IS 'Matchup endpoint responses by week';
COMMENT ON TABLE raw.transactions IS 'Transaction endpoint responses by week';
COMMENT ON TABLE raw.players IS 'Full NFL player database responses (large)';
COMMENT ON TABLE raw.sync_runs IS 'Track synchronization runs and their status';
COMMENT ON TABLE raw.sync_endpoints IS 'Track individual endpoint calls within a sync run';

-- ============================================================================
-- EXAMPLE USAGE
-- ============================================================================

/*
-- Insert a roster response
INSERT INTO raw.rosters (league_id, response_body, response_hash)
VALUES (
    '1199102384316362752',
    '[{"roster_id": 1, "owner_id": "123", "players": [...]}]'::jsonb,
    raw.calculate_hash('[{"roster_id": 1, "owner_id": "123", "players": [...]}]'::jsonb)
);

-- Check if data changed before inserting
INSERT INTO raw.rosters (league_id, response_body, response_hash)
SELECT 
    '1199102384316362752',
    $1::jsonb,
    raw.calculate_hash($1::jsonb)
WHERE raw.data_changed('/league/1199102384316362752/rosters', raw.calculate_hash($1::jsonb));

-- Get unprocessed records
SELECT * FROM raw.rosters 
WHERE processing_status = 'new'
ORDER BY fetched_at;

-- Mark as processed
UPDATE raw.rosters 
SET processing_status = 'processed', 
    processed_at = NOW()
WHERE id = 123;
*/

-- End of raw database schema