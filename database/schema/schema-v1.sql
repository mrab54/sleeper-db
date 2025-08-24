-- Sleeper Fantasy Football Database Schema v1.0
-- PostgreSQL 15+
-- Generated: 2025-08-24
-- 
-- This schema is designed based on comprehensive analysis of the Sleeper API
-- It provides a normalized structure for efficient querying and data integrity

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For text search optimization

-- ============================================================================
-- ENUMS
-- ============================================================================

CREATE TYPE league_status AS ENUM (
    'pre_draft',
    'drafting', 
    'in_season',
    'playoffs',
    'complete'
);

CREATE TYPE transaction_type AS ENUM (
    'trade',
    'waiver',
    'free_agent'
);

CREATE TYPE transaction_status AS ENUM (
    'pending',
    'complete',
    'failed',
    'cancelled'
);

CREATE TYPE roster_transaction_action AS ENUM (
    'add',
    'drop'
);

CREATE TYPE player_status AS ENUM (
    'active',
    'inactive',
    'injured_reserve',
    'out',
    'questionable',
    'doubtful',
    'suspended',
    'retired',
    'practice_squad'
);

CREATE TYPE draft_type AS ENUM (
    'snake',
    'auction',
    'linear'
);

CREATE TYPE draft_status AS ENUM (
    'pre_draft',
    'drafting',
    'paused',
    'complete'
);

CREATE TYPE sync_entity_type AS ENUM (
    'league',
    'roster',
    'matchup',
    'transaction',
    'player',
    'draft',
    'user'
);

CREATE TYPE sync_action AS ENUM (
    'fetch',
    'update',
    'error',
    'skip'
);

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- Users table - Sleeper platform users
CREATE TABLE users (
    user_id VARCHAR(255) PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    avatar VARCHAR(500),
    is_bot BOOLEAN DEFAULT FALSE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_display_name_trgm ON users USING gin(display_name gin_trgm_ops);

-- Leagues table - Fantasy football leagues
CREATE TABLE leagues (
    league_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    season VARCHAR(10) NOT NULL,
    sport VARCHAR(50) DEFAULT 'nfl',
    status league_status NOT NULL DEFAULT 'pre_draft',
    total_rosters INTEGER NOT NULL,
    draft_id VARCHAR(255),
    previous_league_id VARCHAR(255) REFERENCES leagues(league_id),
    avatar VARCHAR(500),
    company_id VARCHAR(255),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_leagues_season ON leagues(season);
CREATE INDEX idx_leagues_status ON leagues(status);
CREATE INDEX idx_leagues_draft_id ON leagues(draft_id);
CREATE INDEX idx_leagues_previous ON leagues(previous_league_id);

-- League settings - Normalized from league.settings
CREATE TABLE league_settings (
    league_id VARCHAR(255) PRIMARY KEY REFERENCES leagues(league_id) ON DELETE CASCADE,
    playoff_week_start INTEGER,
    leg INTEGER DEFAULT 1,
    max_keepers INTEGER DEFAULT 0,
    draft_rounds INTEGER,
    trade_deadline INTEGER,
    waiver_type INTEGER, -- 0: None, 1: Traditional, 2: FAAB
    waiver_day_of_week INTEGER, -- 0-6 (Sunday-Saturday)
    waiver_hour INTEGER, -- 0-23
    waiver_budget INTEGER DEFAULT 100,
    reserve_slots INTEGER DEFAULT 0,
    taxi_slots INTEGER DEFAULT 0,
    taxi_years INTEGER,
    taxi_allow_vets BOOLEAN DEFAULT FALSE,
    best_ball BOOLEAN DEFAULT FALSE,
    disable_trades BOOLEAN DEFAULT FALSE,
    pick_trading BOOLEAN DEFAULT TRUE,
    settings_json JSONB DEFAULT '{}', -- Store full settings for reference
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- League scoring settings - Normalized from league.scoring_settings
CREATE TABLE league_scoring_settings (
    league_id VARCHAR(255) PRIMARY KEY REFERENCES leagues(league_id) ON DELETE CASCADE,
    -- Passing
    pass_td DECIMAL(5,2) DEFAULT 4.0,
    pass_yd DECIMAL(5,4) DEFAULT 0.04,
    pass_int DECIMAL(5,2) DEFAULT -1.0,
    pass_2pt DECIMAL(5,2) DEFAULT 2.0,
    pass_int_td DECIMAL(5,2) DEFAULT -6.0,
    -- Rushing
    rush_td DECIMAL(5,2) DEFAULT 6.0,
    rush_yd DECIMAL(5,4) DEFAULT 0.1,
    rush_2pt DECIMAL(5,2) DEFAULT 2.0,
    -- Receiving
    rec_td DECIMAL(5,2) DEFAULT 6.0,
    rec_yd DECIMAL(5,4) DEFAULT 0.1,
    rec DECIMAL(5,2) DEFAULT 0.0, -- PPR setting
    rec_2pt DECIMAL(5,2) DEFAULT 2.0,
    -- Fumbles
    fum_lost DECIMAL(5,2) DEFAULT -2.0,
    fum_rec_td DECIMAL(5,2) DEFAULT 6.0,
    -- Kicking
    fg_made_0_19 DECIMAL(5,2) DEFAULT 3.0,
    fg_made_20_29 DECIMAL(5,2) DEFAULT 3.0,
    fg_made_30_39 DECIMAL(5,2) DEFAULT 3.0,
    fg_made_40_49 DECIMAL(5,2) DEFAULT 4.0,
    fg_made_50_plus DECIMAL(5,2) DEFAULT 5.0,
    fg_missed DECIMAL(5,2) DEFAULT -1.0,
    xp_made DECIMAL(5,2) DEFAULT 1.0,
    xp_missed DECIMAL(5,2) DEFAULT -1.0,
    -- Defense
    def_td DECIMAL(5,2) DEFAULT 6.0,
    def_int DECIMAL(5,2) DEFAULT 2.0,
    def_sack DECIMAL(5,2) DEFAULT 1.0,
    def_ff DECIMAL(5,2) DEFAULT 1.0,
    def_fr DECIMAL(5,2) DEFAULT 2.0,
    def_blk DECIMAL(5,2) DEFAULT 2.0,
    def_safety DECIMAL(5,2) DEFAULT 2.0,
    def_pr_td DECIMAL(5,2) DEFAULT 6.0,
    def_kr_td DECIMAL(5,2) DEFAULT 6.0,
    scoring_json JSONB DEFAULT '{}', -- Store full scoring settings
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Rosters - Team rosters in a league
CREATE TABLE rosters (
    id SERIAL PRIMARY KEY,
    roster_id INTEGER NOT NULL,
    league_id VARCHAR(255) NOT NULL REFERENCES leagues(league_id) ON DELETE CASCADE,
    owner_id VARCHAR(255) REFERENCES users(user_id) ON DELETE SET NULL,
    co_owner_ids VARCHAR(255)[] DEFAULT ARRAY[]::VARCHAR[],
    -- Record
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    ties INTEGER DEFAULT 0,
    total_moves INTEGER DEFAULT 0,
    waiver_position INTEGER,
    waiver_budget_used INTEGER DEFAULT 0,
    -- Points
    points_for DECIMAL(10,2) DEFAULT 0,
    points_against DECIMAL(10,2) DEFAULT 0,
    points_for_decimal DECIMAL(10,2) DEFAULT 0, -- For tiebreakers
    points_against_decimal DECIMAL(10,2) DEFAULT 0,
    -- Settings
    team_name VARCHAR(255),
    avatar VARCHAR(500),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(league_id, roster_id)
);

CREATE INDEX idx_rosters_league ON rosters(league_id);
CREATE INDEX idx_rosters_owner ON rosters(owner_id);
CREATE INDEX idx_rosters_co_owners ON rosters USING gin(co_owner_ids);
CREATE INDEX idx_rosters_league_roster ON rosters(league_id, roster_id);

-- Players - NFL players
CREATE TABLE players (
    player_id VARCHAR(50) PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name VARCHAR(200),
    search_full_name VARCHAR(200), -- Lowercase for searching
    position VARCHAR(10),
    fantasy_positions VARCHAR(10)[], -- Can play multiple positions
    team VARCHAR(10), -- NFL team abbreviation
    status player_status DEFAULT 'active',
    injury_status VARCHAR(50),
    injury_body_part VARCHAR(50),
    injury_notes TEXT,
    -- Player details
    number INTEGER,
    years_exp INTEGER,
    age INTEGER,
    birth_date DATE,
    height VARCHAR(10), -- Format: "6'2"
    weight INTEGER, -- In pounds
    college VARCHAR(100),
    -- IDs from other platforms
    espn_id VARCHAR(50),
    yahoo_id VARCHAR(50),
    sportradar_id VARCHAR(50),
    rotowire_id VARCHAR(50),
    rotoworld_id VARCHAR(50),
    fantasy_data_id VARCHAR(50),
    -- Metadata
    metadata JSONB DEFAULT '{}',
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_players_position ON players(position);
CREATE INDEX idx_players_team ON players(team);
CREATE INDEX idx_players_status ON players(status);
CREATE INDEX idx_players_search_name_trgm ON players USING gin(search_full_name gin_trgm_ops);
CREATE INDEX idx_players_fantasy_positions ON players USING gin(fantasy_positions);

-- Roster players - Junction table for roster-player relationships
CREATE TABLE roster_players (
    id SERIAL PRIMARY KEY,
    roster_id INTEGER NOT NULL,
    league_id VARCHAR(255) NOT NULL,
    player_id VARCHAR(50) REFERENCES players(player_id) ON DELETE CASCADE,
    is_starter BOOLEAN DEFAULT FALSE,
    slot_position VARCHAR(20), -- QB, RB, WR, TE, FLEX, SUPER_FLEX, K, DEF, BN, IR
    acquisition_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (league_id, roster_id) REFERENCES rosters(league_id, roster_id) ON DELETE CASCADE,
    UNIQUE(roster_id, league_id, player_id)
);

CREATE INDEX idx_roster_players_roster ON roster_players(roster_id, league_id);
CREATE INDEX idx_roster_players_player ON roster_players(player_id);
CREATE INDEX idx_roster_players_starters ON roster_players(is_starter) WHERE is_starter = TRUE;

-- Matchups - Weekly matchups
CREATE TABLE matchups (
    id SERIAL PRIMARY KEY,
    league_id VARCHAR(255) NOT NULL REFERENCES leagues(league_id) ON DELETE CASCADE,
    week INTEGER NOT NULL,
    matchup_id INTEGER NOT NULL, -- Groups teams in same matchup
    roster_id INTEGER NOT NULL,
    points DECIMAL(10,2) DEFAULT 0,
    custom_points DECIMAL(10,2),
    is_playoff BOOLEAN DEFAULT FALSE,
    is_consolation BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (league_id, roster_id) REFERENCES rosters(league_id, roster_id) ON DELETE CASCADE,
    UNIQUE(league_id, week, roster_id)
);

CREATE INDEX idx_matchups_league_week ON matchups(league_id, week);
CREATE INDEX idx_matchups_matchup_id ON matchups(matchup_id);
CREATE INDEX idx_matchups_playoff ON matchups(is_playoff) WHERE is_playoff = TRUE;

-- Matchup players - Player performance in matchups
CREATE TABLE matchup_players (
    id SERIAL PRIMARY KEY,
    matchup_id INTEGER NOT NULL REFERENCES matchups(id) ON DELETE CASCADE,
    player_id VARCHAR(50) REFERENCES players(player_id) ON DELETE CASCADE,
    is_starter BOOLEAN DEFAULT FALSE,
    slot_position VARCHAR(20),
    points DECIMAL(10,2) DEFAULT 0,
    projected_points DECIMAL(10,2),
    game_id VARCHAR(50),
    stats JSONB DEFAULT '{}', -- Detailed stats
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_matchup_players_matchup ON matchup_players(matchup_id);
CREATE INDEX idx_matchup_players_player ON matchup_players(player_id);
CREATE INDEX idx_matchup_players_starters ON matchup_players(is_starter) WHERE is_starter = TRUE;

-- Transactions - League transactions
CREATE TABLE transactions (
    transaction_id VARCHAR(255) PRIMARY KEY,
    league_id VARCHAR(255) NOT NULL REFERENCES leagues(league_id) ON DELETE CASCADE,
    type transaction_type NOT NULL,
    status transaction_status DEFAULT 'complete',
    week INTEGER,
    creator_user_id VARCHAR(255) REFERENCES users(user_id) ON DELETE SET NULL,
    created BIGINT NOT NULL, -- Unix timestamp from API
    consenter_ids VARCHAR(255)[] DEFAULT ARRAY[]::VARCHAR[],
    roster_ids INTEGER[] DEFAULT ARRAY[]::INTEGER[],
    -- Trade specific
    draft_picks JSONB, -- Traded draft picks
    -- Waiver specific
    waiver_budget JSONB, -- FAAB bids by roster
    waiver_priority INTEGER,
    -- Metadata
    settings JSONB DEFAULT '{}',
    leg INTEGER DEFAULT 1,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_transactions_league ON transactions(league_id);
CREATE INDEX idx_transactions_type ON transactions(type);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_week ON transactions(week);
CREATE INDEX idx_transactions_created ON transactions(created);
CREATE INDEX idx_transactions_creator ON transactions(creator_user_id);

-- Transaction details - Players involved in transactions
CREATE TABLE transaction_details (
    id SERIAL PRIMARY KEY,
    transaction_id VARCHAR(255) NOT NULL REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    roster_id INTEGER NOT NULL,
    action roster_transaction_action NOT NULL,
    player_id VARCHAR(50) REFERENCES players(player_id) ON DELETE CASCADE,
    waiver_bid INTEGER, -- FAAB bid amount
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_transaction_details_transaction ON transaction_details(transaction_id);
CREATE INDEX idx_transaction_details_player ON transaction_details(player_id);
CREATE INDEX idx_transaction_details_action ON transaction_details(action);

-- Drafts - League drafts
CREATE TABLE drafts (
    draft_id VARCHAR(255) PRIMARY KEY,
    league_id VARCHAR(255) REFERENCES leagues(league_id) ON DELETE CASCADE,
    type draft_type NOT NULL,
    status draft_status DEFAULT 'pre_draft',
    sport VARCHAR(50) DEFAULT 'nfl',
    season VARCHAR(10) NOT NULL,
    start_time BIGINT, -- Unix timestamp
    season_type VARCHAR(50),
    settings JSONB DEFAULT '{}',
    draft_order JSONB, -- User ID to draft position mapping
    slot_to_roster_id JSONB, -- Draft slot to roster ID mapping
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_drafts_league ON drafts(league_id);
CREATE INDEX idx_drafts_status ON drafts(status);
CREATE INDEX idx_drafts_season ON drafts(season);

-- Draft picks - Individual draft selections
CREATE TABLE draft_picks (
    id SERIAL PRIMARY KEY,
    draft_id VARCHAR(255) NOT NULL REFERENCES drafts(draft_id) ON DELETE CASCADE,
    pick_no INTEGER NOT NULL,
    round INTEGER NOT NULL,
    draft_slot INTEGER NOT NULL,
    player_id VARCHAR(50) REFERENCES players(player_id) ON DELETE SET NULL,
    picked_by VARCHAR(255) REFERENCES users(user_id) ON DELETE SET NULL,
    roster_id INTEGER,
    is_keeper BOOLEAN DEFAULT FALSE,
    bid_amount INTEGER, -- For auction drafts
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(draft_id, pick_no)
);

CREATE INDEX idx_draft_picks_draft ON draft_picks(draft_id);
CREATE INDEX idx_draft_picks_player ON draft_picks(player_id);
CREATE INDEX idx_draft_picks_picked_by ON draft_picks(picked_by);
CREATE INDEX idx_draft_picks_round ON draft_picks(round);

-- Traded picks - Future draft picks that have been traded
CREATE TABLE traded_picks (
    id SERIAL PRIMARY KEY,
    league_id VARCHAR(255) NOT NULL REFERENCES leagues(league_id) ON DELETE CASCADE,
    season VARCHAR(10) NOT NULL,
    round INTEGER NOT NULL,
    original_roster_id INTEGER NOT NULL,
    current_roster_id INTEGER NOT NULL,
    previous_roster_id INTEGER,
    transaction_id VARCHAR(255) REFERENCES transactions(transaction_id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_traded_picks_league ON traded_picks(league_id);
CREATE INDEX idx_traded_picks_season ON traded_picks(season);
CREATE INDEX idx_traded_picks_current_roster ON traded_picks(current_roster_id);

-- Player stats - Weekly player statistics
CREATE TABLE player_stats (
    id SERIAL PRIMARY KEY,
    player_id VARCHAR(50) NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
    season VARCHAR(10) NOT NULL,
    week INTEGER NOT NULL,
    game_id VARCHAR(50),
    team VARCHAR(10),
    opponent VARCHAR(10),
    -- Stats stored as JSONB for flexibility
    stats JSONB NOT NULL DEFAULT '{}',
    -- Common fantasy points for quick queries
    fantasy_points_ppr DECIMAL(10,2),
    fantasy_points_standard DECIMAL(10,2),
    fantasy_points_half_ppr DECIMAL(10,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(player_id, season, week)
);

CREATE INDEX idx_player_stats_player_season ON player_stats(player_id, season);
CREATE INDEX idx_player_stats_week ON player_stats(week);
CREATE INDEX idx_player_stats_season_week ON player_stats(season, week);

-- Playoff brackets - Playoff matchup structure
CREATE TABLE playoff_brackets (
    id SERIAL PRIMARY KEY,
    league_id VARCHAR(255) NOT NULL REFERENCES leagues(league_id) ON DELETE CASCADE,
    bracket_type VARCHAR(50) NOT NULL, -- 'winners' or 'losers'
    round INTEGER NOT NULL,
    matchup_id INTEGER NOT NULL,
    team1_roster_id INTEGER,
    team2_roster_id INTEGER,
    winner_roster_id INTEGER,
    team1_points DECIMAL(10,2),
    team2_points DECIMAL(10,2),
    week INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(league_id, bracket_type, round, matchup_id)
);

CREATE INDEX idx_playoff_brackets_league ON playoff_brackets(league_id);
CREATE INDEX idx_playoff_brackets_type ON playoff_brackets(bracket_type);

-- ============================================================================
-- OPERATIONAL TABLES
-- ============================================================================

-- Sync log - Track all sync operations
CREATE TABLE sync_log (
    id SERIAL PRIMARY KEY,
    entity_type sync_entity_type NOT NULL,
    entity_id VARCHAR(255) NOT NULL,
    action sync_action NOT NULL,
    status VARCHAR(50) NOT NULL, -- success, failed, partial
    records_affected INTEGER DEFAULT 0,
    duration_ms INTEGER,
    error_message TEXT,
    details JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_sync_log_entity ON sync_log(entity_type, entity_id);
CREATE INDEX idx_sync_log_created ON sync_log(created_at DESC);
CREATE INDEX idx_sync_log_status ON sync_log(status);
CREATE INDEX idx_sync_log_entity_created ON sync_log(entity_type, created_at DESC);

-- Partition sync_log by month for performance
CREATE TABLE sync_log_y2025m01 PARTITION OF sync_log
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

-- API cache - Cache frequently accessed data
CREATE TABLE api_cache (
    cache_key VARCHAR(500) PRIMARY KEY,
    endpoint VARCHAR(500) NOT NULL,
    response_data JSONB NOT NULL,
    checksum VARCHAR(64) NOT NULL, -- SHA-256 hash
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    accessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    access_count INTEGER DEFAULT 1
);

CREATE INDEX idx_api_cache_endpoint ON api_cache(endpoint);
CREATE INDEX idx_api_cache_expires ON api_cache(expires_at);
CREATE INDEX idx_api_cache_accessed ON api_cache(accessed_at);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Current standings view
CREATE OR REPLACE VIEW v_league_standings AS
SELECT 
    r.league_id,
    r.roster_id,
    r.owner_id,
    u.display_name as owner_name,
    r.team_name,
    r.wins,
    r.losses,
    r.ties,
    r.points_for,
    r.points_against,
    r.points_for - r.points_against as point_differential,
    CASE 
        WHEN (r.wins + r.losses + r.ties) > 0 
        THEN ROUND(r.wins::DECIMAL / (r.wins + r.losses + r.ties)::DECIMAL, 3)
        ELSE 0
    END as win_percentage,
    RANK() OVER (
        PARTITION BY r.league_id 
        ORDER BY r.wins DESC, r.points_for DESC
    ) as standing
FROM rosters r
LEFT JOIN users u ON r.owner_id = u.user_id;

-- Recent transactions view
CREATE OR REPLACE VIEW v_recent_transactions AS
SELECT 
    t.transaction_id,
    t.league_id,
    t.type,
    t.status,
    t.week,
    t.created,
    u.display_name as creator_name,
    t.roster_ids,
    td.action,
    td.player_id,
    p.full_name as player_name,
    p.position as player_position
FROM transactions t
LEFT JOIN users u ON t.creator_user_id = u.user_id
LEFT JOIN transaction_details td ON t.transaction_id = td.transaction_id
LEFT JOIN players p ON td.player_id = p.player_id
ORDER BY t.created DESC;

-- Current week matchups view
CREATE OR REPLACE VIEW v_current_matchups AS
WITH current_week AS (
    SELECT MAX(week) as week FROM matchups WHERE points > 0
)
SELECT 
    m.league_id,
    m.week,
    m.matchup_id,
    m.roster_id,
    r.team_name,
    u.display_name as owner_name,
    m.points,
    m.is_playoff
FROM matchups m
JOIN current_week cw ON m.week = cw.week
JOIN rosters r ON m.league_id = r.league_id AND m.roster_id = r.roster_id
LEFT JOIN users u ON r.owner_id = u.user_id;

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Upsert user function
CREATE OR REPLACE FUNCTION upsert_user(
    p_user_id VARCHAR,
    p_username VARCHAR,
    p_display_name VARCHAR,
    p_avatar VARCHAR DEFAULT NULL,
    p_is_bot BOOLEAN DEFAULT FALSE,
    p_metadata JSONB DEFAULT '{}'
) RETURNS void AS $$
BEGIN
    INSERT INTO users (user_id, username, display_name, avatar, is_bot, metadata)
    VALUES (p_user_id, p_username, p_display_name, p_avatar, p_is_bot, p_metadata)
    ON CONFLICT (user_id) DO UPDATE SET
        username = EXCLUDED.username,
        display_name = EXCLUDED.display_name,
        avatar = COALESCE(EXCLUDED.avatar, users.avatar),
        is_bot = EXCLUDED.is_bot,
        metadata = users.metadata || EXCLUDED.metadata,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Upsert league function
CREATE OR REPLACE FUNCTION upsert_league(
    p_league_id VARCHAR,
    p_name VARCHAR,
    p_season VARCHAR,
    p_sport VARCHAR,
    p_status league_status,
    p_total_rosters INTEGER,
    p_draft_id VARCHAR DEFAULT NULL,
    p_previous_league_id VARCHAR DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'
) RETURNS void AS $$
BEGIN
    INSERT INTO leagues (
        league_id, name, season, sport, status, 
        total_rosters, draft_id, previous_league_id, metadata
    ) VALUES (
        p_league_id, p_name, p_season, p_sport, p_status,
        p_total_rosters, p_draft_id, p_previous_league_id, p_metadata
    )
    ON CONFLICT (league_id) DO UPDATE SET
        name = EXCLUDED.name,
        status = EXCLUDED.status,
        total_rosters = EXCLUDED.total_rosters,
        draft_id = COALESCE(EXCLUDED.draft_id, leagues.draft_id),
        metadata = leagues.metadata || EXCLUDED.metadata,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Calculate fantasy points function
CREATE OR REPLACE FUNCTION calculate_fantasy_points(
    p_stats JSONB,
    p_scoring_settings JSONB
) RETURNS DECIMAL AS $$
DECLARE
    total_points DECIMAL := 0;
    stat_key TEXT;
    stat_value DECIMAL;
    scoring_value DECIMAL;
BEGIN
    FOR stat_key, stat_value IN SELECT * FROM jsonb_each_text(p_stats)
    LOOP
        IF p_scoring_settings ? stat_key THEN
            scoring_value := (p_scoring_settings ->> stat_key)::DECIMAL;
            total_points := total_points + (stat_value * scoring_value);
        END IF;
    END LOOP;
    
    RETURN ROUND(total_points, 2);
END;
$$ LANGUAGE plpgsql;

-- Get roster players for a week
CREATE OR REPLACE FUNCTION get_roster_players_for_week(
    p_league_id VARCHAR,
    p_roster_id INTEGER,
    p_week INTEGER
) RETURNS TABLE(
    player_id VARCHAR,
    full_name VARCHAR,
    position VARCHAR,
    is_starter BOOLEAN,
    slot_position VARCHAR,
    points DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rp.player_id,
        p.full_name,
        p.position,
        rp.is_starter,
        rp.slot_position,
        COALESCE(mp.points, 0) as points
    FROM roster_players rp
    JOIN players p ON rp.player_id = p.player_id
    LEFT JOIN matchups m ON m.league_id = rp.league_id 
        AND m.roster_id = rp.roster_id 
        AND m.week = p_week
    LEFT JOIN matchup_players mp ON mp.matchup_id = m.id 
        AND mp.player_id = rp.player_id
    WHERE rp.league_id = p_league_id 
        AND rp.roster_id = p_roster_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Update timestamp triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_leagues_updated_at BEFORE UPDATE ON leagues
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_league_settings_updated_at BEFORE UPDATE ON league_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_league_scoring_settings_updated_at BEFORE UPDATE ON league_scoring_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rosters_updated_at BEFORE UPDATE ON rosters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_players_updated_at BEFORE UPDATE ON players
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_matchups_updated_at BEFORE UPDATE ON matchups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_transactions_updated_at BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_drafts_updated_at BEFORE UPDATE ON drafts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_traded_picks_updated_at BEFORE UPDATE ON traded_picks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_player_stats_updated_at BEFORE UPDATE ON player_stats
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_playoff_brackets_updated_at BEFORE UPDATE ON playoff_brackets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- PERMISSIONS (for Hasura)
-- ============================================================================

-- Grant permissions to the application user (adjust as needed)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sleeper_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO sleeper_user;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO sleeper_user;

-- ============================================================================
-- INITIAL DATA
-- ============================================================================

-- Insert NFL state tracking
CREATE TABLE IF NOT EXISTS nfl_state (
    id INTEGER PRIMARY KEY DEFAULT 1,
    season VARCHAR(10) NOT NULL,
    week INTEGER NOT NULL,
    season_type VARCHAR(50) NOT NULL, -- 'regular', 'post'
    leg INTEGER DEFAULT 1,
    display_week INTEGER,
    season_start_date DATE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT single_row CHECK (id = 1)
);

-- Insert initial NFL state (will be updated by sync)
INSERT INTO nfl_state (season, week, season_type, display_week)
VALUES ('2025', 1, 'regular', 1)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON SCHEMA public IS 'Sleeper Fantasy Football Database - Normalized structure for efficient querying and data integrity';
COMMENT ON TABLE users IS 'Sleeper platform users participating in leagues';
COMMENT ON TABLE leagues IS 'Fantasy football leagues with settings and metadata';
COMMENT ON TABLE rosters IS 'Team rosters within leagues, tracking ownership and performance';
COMMENT ON TABLE players IS 'NFL players with biographical and status information';
COMMENT ON TABLE roster_players IS 'Junction table linking rosters to their current players';
COMMENT ON TABLE matchups IS 'Weekly head-to-head matchups between rosters';
COMMENT ON TABLE transactions IS 'All league transactions including trades, waivers, and free agent acquisitions';
COMMENT ON TABLE sync_log IS 'Audit log of all data synchronization operations';
COMMENT ON FUNCTION calculate_fantasy_points IS 'Calculate fantasy points based on stats and scoring settings';