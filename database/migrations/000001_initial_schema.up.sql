-- Migration: 000001_initial_schema
-- Description: Initial database schema setup for Sleeper Fantasy Football
-- Date: 2025-08-24

BEGIN;

-- Create sleeper schema
CREATE SCHEMA IF NOT EXISTS sleeper;

-- Set search path
SET search_path TO sleeper, public;

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Create update trigger function
CREATE OR REPLACE FUNCTION sleeper.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create users table
CREATE TABLE IF NOT EXISTS sleeper.users (
    user_id VARCHAR(50) PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    display_name VARCHAR(100),
    avatar VARCHAR(255),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create leagues table
CREATE TABLE IF NOT EXISTS sleeper.leagues (
    league_id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    season INT NOT NULL,
    status VARCHAR(20) NOT NULL,
    sport VARCHAR(10) DEFAULT 'nfl',
    total_rosters INT NOT NULL,
    settings JSONB NOT NULL,
    scoring_settings JSONB NOT NULL,
    roster_positions JSONB NOT NULL,
    metadata JSONB DEFAULT '{}',
    previous_league_id VARCHAR(50),
    draft_id VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create rosters table
CREATE TABLE IF NOT EXISTS sleeper.rosters (
    roster_id SERIAL PRIMARY KEY,
    league_id VARCHAR(50) NOT NULL REFERENCES sleeper.leagues(league_id) ON DELETE CASCADE,
    owner_id VARCHAR(50) NOT NULL REFERENCES sleeper.users(user_id),
    roster_number INT NOT NULL,
    settings JSONB DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    starters JSONB,
    reserve JSONB,
    taxi JSONB,
    wins INT DEFAULT 0,
    losses INT DEFAULT 0,
    ties INT DEFAULT 0,
    points_for DECIMAL(10,2) DEFAULT 0,
    points_against DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(league_id, roster_number)
);

-- Create players table
CREATE TABLE IF NOT EXISTS sleeper.players (
    player_id VARCHAR(50) PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name VARCHAR(200),
    position VARCHAR(10),
    team VARCHAR(10),
    age INT,
    years_exp INT,
    college VARCHAR(100),
    weight INT,
    height INT,
    birth_date DATE,
    birth_country VARCHAR(50),
    birth_state VARCHAR(50),
    birth_city VARCHAR(100),
    injury_status VARCHAR(20),
    injury_body_part VARCHAR(50),
    injury_start_date DATE,
    injury_notes TEXT,
    practice_participation VARCHAR(20),
    practice_description TEXT,
    status VARCHAR(20),
    sport VARCHAR(10) DEFAULT 'nfl',
    search_first_name VARCHAR(100),
    search_last_name VARCHAR(100),
    search_full_name VARCHAR(200),
    depth_chart_position VARCHAR(10),
    depth_chart_order INT,
    stats JSONB DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create roster_players table
CREATE TABLE IF NOT EXISTS sleeper.roster_players (
    id SERIAL PRIMARY KEY,
    roster_id INT NOT NULL REFERENCES sleeper.rosters(roster_id) ON DELETE CASCADE,
    player_id VARCHAR(50) NOT NULL REFERENCES sleeper.players(player_id),
    status VARCHAR(20) DEFAULT 'bench',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(roster_id, player_id)
);

-- Create matchups table
CREATE TABLE IF NOT EXISTS sleeper.matchups (
    id SERIAL PRIMARY KEY,
    league_id VARCHAR(50) NOT NULL REFERENCES sleeper.leagues(league_id) ON DELETE CASCADE,
    week INT NOT NULL,
    matchup_id INT NOT NULL,
    roster_id INT NOT NULL REFERENCES sleeper.rosters(roster_id) ON DELETE CASCADE,
    points DECIMAL(10,2),
    custom_points DECIMAL(10,2),
    players_points JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(league_id, week, roster_id)
);

-- Create transactions table
CREATE TABLE IF NOT EXISTS sleeper.transactions (
    transaction_id VARCHAR(100) PRIMARY KEY,
    league_id VARCHAR(50) NOT NULL REFERENCES sleeper.leagues(league_id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL,
    transaction_type VARCHAR(20),
    status VARCHAR(20) NOT NULL,
    status_updated BIGINT,
    roster_ids JSONB NOT NULL,
    settings JSONB DEFAULT '{}',
    adds JSONB DEFAULT '{}',
    drops JSONB DEFAULT '{}',
    draft_picks JSONB DEFAULT '[]',
    waiver_budget JSONB DEFAULT '[]',
    metadata JSONB DEFAULT '{}',
    creator VARCHAR(50),
    created BIGINT,
    leg INT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create sync_log table
CREATE TABLE IF NOT EXISTS sleeper.sync_log (
    id SERIAL PRIMARY KEY,
    sync_type VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(100),
    status VARCHAR(20) NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    records_processed INT DEFAULT 0,
    error_message TEXT,
    metadata JSONB DEFAULT '{}'
) PARTITION BY RANGE (started_at);

-- Create initial partition for sync_log
CREATE TABLE IF NOT EXISTS sleeper.sync_log_2025_01 PARTITION OF sleeper.sync_log
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

-- Create indexes
CREATE INDEX idx_users_username ON sleeper.users(username);
CREATE INDEX idx_leagues_season ON sleeper.leagues(season);
CREATE INDEX idx_leagues_status ON sleeper.leagues(status);
CREATE INDEX idx_rosters_owner ON sleeper.rosters(owner_id);
CREATE INDEX idx_rosters_league ON sleeper.rosters(league_id);
CREATE INDEX idx_players_position ON sleeper.players(position);
CREATE INDEX idx_players_team ON sleeper.players(team);
CREATE INDEX idx_players_name_trgm ON sleeper.players USING gin(full_name gin_trgm_ops);
CREATE INDEX idx_roster_players_roster ON sleeper.roster_players(roster_id);
CREATE INDEX idx_roster_players_player ON sleeper.roster_players(player_id);
CREATE INDEX idx_matchups_league_week ON sleeper.matchups(league_id, week);
CREATE INDEX idx_matchups_roster ON sleeper.matchups(roster_id);
CREATE INDEX idx_transactions_league ON sleeper.transactions(league_id);
CREATE INDEX idx_transactions_type ON sleeper.transactions(type);
CREATE INDEX idx_transactions_created ON sleeper.transactions(created);
CREATE INDEX idx_sync_log_type_status ON sleeper.sync_log(sync_type, status);

-- Add update triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON sleeper.users
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

CREATE TRIGGER update_leagues_updated_at BEFORE UPDATE ON sleeper.leagues
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

CREATE TRIGGER update_rosters_updated_at BEFORE UPDATE ON sleeper.rosters
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

CREATE TRIGGER update_players_updated_at BEFORE UPDATE ON sleeper.players
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

CREATE TRIGGER update_roster_players_updated_at BEFORE UPDATE ON sleeper.roster_players
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

CREATE TRIGGER update_matchups_updated_at BEFORE UPDATE ON sleeper.matchups
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

CREATE TRIGGER update_transactions_updated_at BEFORE UPDATE ON sleeper.transactions
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Grant permissions
GRANT USAGE ON SCHEMA sleeper TO sleeper_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA sleeper TO sleeper_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA sleeper TO sleeper_user;

-- Add comment documentation
COMMENT ON SCHEMA sleeper IS 'Sleeper Fantasy Football database schema';
COMMENT ON TABLE sleeper.users IS 'Sleeper platform users';
COMMENT ON TABLE sleeper.leagues IS 'Fantasy football leagues';
COMMENT ON TABLE sleeper.rosters IS 'Team rosters within leagues';
COMMENT ON TABLE sleeper.players IS 'NFL players and their metadata';
COMMENT ON TABLE sleeper.roster_players IS 'Many-to-many relationship between rosters and players';
COMMENT ON TABLE sleeper.matchups IS 'Weekly matchup data';
COMMENT ON TABLE sleeper.transactions IS 'League transactions (trades, waivers, etc.)';
COMMENT ON TABLE sleeper.sync_log IS 'Synchronization audit log';

COMMIT;
