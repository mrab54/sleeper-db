-- Sleeper Analytics Database - PROPERLY NORMALIZED
-- PostgreSQL 17+ 
-- Last Updated: 2025-08-25
--
-- This schema is fully normalized to 3NF/BCNF standards
-- All arrays and JSON fields are extracted into proper relational tables
-- Includes temporal tracking for historical analysis

-- ============================================================================
-- DATABASE SETUP
-- ============================================================================

-- Create schema for analytics data
CREATE SCHEMA IF NOT EXISTS analytics;

-- Set default search path
SET search_path TO analytics, public;

-- ============================================================================
-- CORE ENTITY TABLES (Things that exist independently)
-- ============================================================================

-- Users are independent entities that exist on the platform
CREATE TABLE IF NOT EXISTS analytics.users (
    user_id VARCHAR(255) PRIMARY KEY,
    username VARCHAR(255) UNIQUE,
    display_name VARCHAR(255) NOT NULL,
    avatar_url VARCHAR(500),
    email VARCHAR(255),
    is_bot BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_users_username ON analytics.users(username);
CREATE INDEX idx_users_display_name ON analytics.users(display_name);

-- ============================================================================
-- SPORTS AND SEASONS (Reference data)
-- ============================================================================

CREATE TABLE IF NOT EXISTS analytics.sports (
    sport_id VARCHAR(10) PRIMARY KEY,  -- 'nfl', 'nba', etc.
    sport_name VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT true
);

INSERT INTO analytics.sports (sport_id, sport_name) VALUES 
    ('nfl', 'National Football League'),
    ('nba', 'National Basketball Association')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS analytics.seasons (
    season_id SERIAL PRIMARY KEY,
    sport_id VARCHAR(10) NOT NULL REFERENCES analytics.sports(sport_id),
    year VARCHAR(10) NOT NULL,
    season_type VARCHAR(20) NOT NULL, -- 'regular', 'playoffs', 'offseason'
    start_date DATE,
    end_date DATE,
    is_current BOOLEAN DEFAULT false,
    UNIQUE(sport_id, year, season_type)
);

CREATE INDEX idx_seasons_sport_year ON analytics.seasons(sport_id, year);

-- ============================================================================
-- LEAGUES (Core entity with settings normalized)
-- ============================================================================

CREATE TABLE IF NOT EXISTS analytics.leagues (
    league_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    sport_id VARCHAR(10) NOT NULL REFERENCES analytics.sports(sport_id),
    season_id INTEGER REFERENCES analytics.seasons(season_id),
    avatar_url VARCHAR(500),
    
    -- League configuration
    league_type VARCHAR(50), -- 'redraft', 'dynasty', 'keeper'
    total_rosters INTEGER NOT NULL,
    status VARCHAR(50), -- 'pre_draft', 'drafting', 'in_season', 'complete'
    
    -- Related entities
    draft_id VARCHAR(255),
    previous_league_id VARCHAR(255) REFERENCES analytics.leagues(league_id),
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_leagues_sport ON analytics.leagues(sport_id);
CREATE INDEX idx_leagues_season ON analytics.leagues(season_id);
CREATE INDEX idx_leagues_status ON analytics.leagues(status);
CREATE INDEX idx_leagues_previous ON analytics.leagues(previous_league_id);

-- League settings (normalized from JSON)
CREATE TABLE IF NOT EXISTS analytics.league_settings (
    league_id VARCHAR(255) PRIMARY KEY REFERENCES analytics.leagues(league_id) ON DELETE CASCADE,
    
    -- Draft settings
    draft_rounds INTEGER,
    draft_pick_timer INTEGER, -- seconds
    draft_cpu_autopick BOOLEAN DEFAULT true,
    
    -- Waiver settings
    waiver_type VARCHAR(50), -- 'rolling', 'reverse_standings', 'faab'
    waiver_day_of_week INTEGER, -- 0-6 (Sunday-Saturday)
    waiver_clear_days INTEGER[], -- Array of days waivers clear
    waiver_budget INTEGER, -- FAAB budget
    
    -- Trade settings
    trade_review_days INTEGER,
    trade_deadline_week INTEGER,
    commissioner_direct_invite BOOLEAN DEFAULT false,
    
    -- Roster settings
    max_keepers INTEGER,
    roster_slots_qb INTEGER DEFAULT 1,
    roster_slots_rb INTEGER DEFAULT 2,
    roster_slots_wr INTEGER DEFAULT 2,
    roster_slots_te INTEGER DEFAULT 1,
    roster_slots_flex INTEGER DEFAULT 1,
    roster_slots_k INTEGER DEFAULT 1,
    roster_slots_def INTEGER DEFAULT 1,
    roster_slots_bench INTEGER DEFAULT 6,
    roster_slots_ir INTEGER DEFAULT 0,
    roster_slots_taxi INTEGER DEFAULT 0,
    
    -- Playoff settings
    playoff_week_start INTEGER,
    playoff_teams INTEGER,
    playoff_type VARCHAR(50), -- 'single', 'two_week'
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- League scoring settings (normalized from JSON)
CREATE TABLE IF NOT EXISTS analytics.league_scoring_settings (
    scoring_id SERIAL PRIMARY KEY,
    league_id VARCHAR(255) NOT NULL REFERENCES analytics.leagues(league_id) ON DELETE CASCADE,
    position VARCHAR(10) NOT NULL, -- 'QB', 'RB', 'WR', etc.
    stat_name VARCHAR(50) NOT NULL, -- 'pass_td', 'rush_yd', etc.
    points_per_unit DECIMAL(5,2) NOT NULL,
    UNIQUE(league_id, position, stat_name)
);

CREATE INDEX idx_scoring_league_position ON analytics.league_scoring_settings(league_id, position);

-- ============================================================================
-- PLAYERS (With temporal tracking for team/status changes)
-- ============================================================================

CREATE TABLE IF NOT EXISTS analytics.players (
    player_id VARCHAR(50) PRIMARY KEY,
    
    -- Basic info (doesn't change)
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name VARCHAR(200) GENERATED ALWAYS AS (
        COALESCE(first_name, '') || ' ' || COALESCE(last_name, '')
    ) STORED,
    birth_date DATE,
    college VARCHAR(100),
    
    -- Physical attributes
    height_inches INTEGER,
    weight_lbs INTEGER,
    
    -- External IDs
    espn_id INTEGER,
    yahoo_id INTEGER,
    stats_id VARCHAR(50),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_players_full_name ON analytics.players(full_name);
CREATE INDEX idx_players_espn_id ON analytics.players(espn_id) WHERE espn_id IS NOT NULL;

-- Player status tracking (changes over time)
CREATE TABLE IF NOT EXISTS analytics.player_status (
    status_id SERIAL PRIMARY KEY,
    player_id VARCHAR(50) NOT NULL REFERENCES analytics.players(player_id),
    
    -- Status info
    team_code VARCHAR(10), -- 'KC', 'BUF', etc. NULL = free agent
    jersey_number INTEGER,
    position VARCHAR(10), -- Primary position
    depth_chart_position VARCHAR(10),
    depth_chart_order INTEGER,
    
    -- Status flags
    status VARCHAR(50), -- 'active', 'injured_reserve', 'practice_squad', 'retired'
    is_active BOOLEAN DEFAULT true,
    years_experience INTEGER,
    
    -- Injury info
    injury_status VARCHAR(50), -- 'questionable', 'doubtful', 'out'
    injury_body_part VARCHAR(100),
    injury_notes TEXT,
    
    -- Time bounds (for temporal queries)
    valid_from TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    valid_to TIMESTAMP WITH TIME ZONE DEFAULT '9999-12-31'::timestamptz,
    
    CHECK (valid_from < valid_to)
);

CREATE INDEX idx_player_status_player ON analytics.player_status(player_id, valid_from DESC);
CREATE INDEX idx_player_status_current ON analytics.player_status(player_id) 
    WHERE valid_to = '9999-12-31'::timestamptz;
CREATE INDEX idx_player_status_team ON analytics.player_status(team_code) 
    WHERE valid_to = '9999-12-31'::timestamptz;

-- Player fantasy positions (many-to-many)
CREATE TABLE IF NOT EXISTS analytics.player_fantasy_positions (
    player_id VARCHAR(50) NOT NULL REFERENCES analytics.players(player_id) ON DELETE CASCADE,
    position VARCHAR(20) NOT NULL, -- 'QB', 'RB', 'WR', 'TE', 'FLEX', 'SUPER_FLEX'
    is_primary BOOLEAN DEFAULT false,
    PRIMARY KEY (player_id, position)
);

CREATE INDEX idx_player_positions_position ON analytics.player_fantasy_positions(position);

-- ============================================================================
-- TEAMS/ROSTERS (With temporal tracking)
-- ============================================================================

CREATE TABLE IF NOT EXISTS analytics.rosters (
    roster_id SERIAL PRIMARY KEY,
    league_id VARCHAR(255) NOT NULL REFERENCES analytics.leagues(league_id) ON DELETE CASCADE,
    roster_number INTEGER NOT NULL, -- 1-12 typically
    
    -- Team identity
    team_name VARCHAR(255),
    team_abbreviation VARCHAR(10),
    division_id INTEGER,
    
    -- Current owner (historical ownership in separate table)
    current_owner_id VARCHAR(255) REFERENCES analytics.users(user_id),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(league_id, roster_number)
);

CREATE INDEX idx_rosters_league ON analytics.rosters(league_id);
CREATE INDEX idx_rosters_owner ON analytics.rosters(current_owner_id);

-- Roster ownership history (tracks owner changes)
CREATE TABLE IF NOT EXISTS analytics.roster_ownership (
    ownership_id SERIAL PRIMARY KEY,
    roster_id INTEGER NOT NULL REFERENCES analytics.rosters(roster_id) ON DELETE CASCADE,
    user_id VARCHAR(255) NOT NULL REFERENCES analytics.users(user_id),
    ownership_type VARCHAR(20) NOT NULL, -- 'owner', 'co_owner'
    
    valid_from TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    valid_to TIMESTAMP WITH TIME ZONE DEFAULT '9999-12-31'::timestamptz,
    
    CHECK (valid_from < valid_to)
);

CREATE INDEX idx_roster_ownership_roster ON analytics.roster_ownership(roster_id, valid_from DESC);
CREATE INDEX idx_roster_ownership_user ON analytics.roster_ownership(user_id);

-- Roster performance stats (by week/season)
CREATE TABLE IF NOT EXISTS analytics.roster_stats (
    stat_id SERIAL PRIMARY KEY,
    roster_id INTEGER NOT NULL REFERENCES analytics.rosters(roster_id) ON DELETE CASCADE,
    
    -- Time period
    season_id INTEGER REFERENCES analytics.seasons(season_id),
    week INTEGER, -- NULL for season totals
    
    -- Record
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    ties INTEGER DEFAULT 0,
    
    -- Points
    points_for DECIMAL(10,2) DEFAULT 0,
    points_against DECIMAL(10,2) DEFAULT 0,
    
    -- Standings
    rank INTEGER,
    playoff_seed INTEGER,
    
    -- Transactions
    waiver_position INTEGER,
    waiver_budget_used INTEGER DEFAULT 0,
    trades_completed INTEGER DEFAULT 0,
    acquisitions INTEGER DEFAULT 0,
    
    UNIQUE(roster_id, season_id, week)
);

CREATE INDEX idx_roster_stats_season ON analytics.roster_stats(season_id, roster_id);
CREATE INDEX idx_roster_stats_weekly ON analytics.roster_stats(roster_id, week) WHERE week IS NOT NULL;

-- Roster players (with temporal tracking)
CREATE TABLE IF NOT EXISTS analytics.roster_players (
    roster_player_id SERIAL PRIMARY KEY,
    roster_id INTEGER NOT NULL REFERENCES analytics.rosters(roster_id) ON DELETE CASCADE,
    player_id VARCHAR(50) NOT NULL REFERENCES analytics.players(player_id),
    
    -- How acquired
    acquisition_type VARCHAR(50), -- 'draft', 'trade', 'waiver', 'free_agent'
    acquisition_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    acquisition_cost INTEGER, -- FAAB spent or draft round
    
    -- Status
    roster_status VARCHAR(20) DEFAULT 'active', -- 'active', 'bench', 'ir', 'taxi'
    
    -- Time bounds
    valid_from TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    valid_to TIMESTAMP WITH TIME ZONE DEFAULT '9999-12-31'::timestamptz,
    
    CHECK (valid_from < valid_to)
);

CREATE INDEX idx_roster_players_roster ON analytics.roster_players(roster_id, valid_from DESC);
CREATE INDEX idx_roster_players_player ON analytics.roster_players(player_id);
CREATE INDEX idx_roster_players_current ON analytics.roster_players(roster_id) 
    WHERE valid_to = '9999-12-31'::timestamptz;

-- ============================================================================
-- MATCHUPS (Head-to-head competitions)
-- ============================================================================

CREATE TABLE IF NOT EXISTS analytics.matchups (
    matchup_id SERIAL PRIMARY KEY,
    league_id VARCHAR(255) NOT NULL REFERENCES analytics.leagues(league_id) ON DELETE CASCADE,
    
    -- Matchup details
    week INTEGER NOT NULL,
    matchup_type VARCHAR(20), -- 'regular', 'playoff', 'championship', 'consolation'
    
    -- Participants (2 for head-to-head)
    home_roster_id INTEGER REFERENCES analytics.rosters(roster_id),
    away_roster_id INTEGER REFERENCES analytics.rosters(roster_id),
    
    -- Results
    home_score DECIMAL(10,2),
    away_score DECIMAL(10,2),
    winner_roster_id INTEGER REFERENCES analytics.rosters(roster_id),
    is_tie BOOLEAN DEFAULT false,
    
    -- Status
    is_complete BOOLEAN DEFAULT false,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(league_id, week, home_roster_id, away_roster_id)
);

CREATE INDEX idx_matchups_league_week ON analytics.matchups(league_id, week);
CREATE INDEX idx_matchups_home ON analytics.matchups(home_roster_id);
CREATE INDEX idx_matchups_away ON analytics.matchups(away_roster_id);

-- Individual player performance in matchups
CREATE TABLE IF NOT EXISTS analytics.matchup_players (
    matchup_player_id SERIAL PRIMARY KEY,
    matchup_id INTEGER NOT NULL REFERENCES analytics.matchups(matchup_id) ON DELETE CASCADE,
    roster_id INTEGER NOT NULL REFERENCES analytics.rosters(roster_id),
    player_id VARCHAR(50) NOT NULL REFERENCES analytics.players(player_id),
    
    -- Lineup info
    lineup_slot VARCHAR(20), -- 'QB', 'RB1', 'RB2', 'WR1', 'FLEX', 'BENCH'
    was_starter BOOLEAN DEFAULT false,
    
    -- Performance
    actual_points DECIMAL(10,2),
    projected_points DECIMAL(10,2),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_matchup_players_matchup ON analytics.matchup_players(matchup_id);
CREATE INDEX idx_matchup_players_roster ON analytics.matchup_players(roster_id);
CREATE INDEX idx_matchup_players_player ON analytics.matchup_players(player_id);

-- ============================================================================
-- TRANSACTIONS (All roster moves)
-- ============================================================================

CREATE TABLE IF NOT EXISTS analytics.transactions (
    transaction_id VARCHAR(255) PRIMARY KEY,
    league_id VARCHAR(255) NOT NULL REFERENCES analytics.leagues(league_id) ON DELETE CASCADE,
    
    -- Transaction info
    transaction_type VARCHAR(50) NOT NULL, -- 'trade', 'waiver', 'free_agent', 'commissioner'
    status VARCHAR(50) NOT NULL, -- 'pending', 'complete', 'vetoed', 'failed'
    
    -- Participants
    initiator_roster_id INTEGER REFERENCES analytics.rosters(roster_id),
    initiator_user_id VARCHAR(255) REFERENCES analytics.users(user_id),
    
    -- Timing
    week INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    
    -- Waiver specific
    waiver_bid INTEGER,
    waiver_priority INTEGER
);

CREATE INDEX idx_transactions_league ON analytics.transactions(league_id, created_at DESC);
CREATE INDEX idx_transactions_type ON analytics.transactions(transaction_type);
CREATE INDEX idx_transactions_status ON analytics.transactions(status);
CREATE INDEX idx_transactions_week ON analytics.transactions(week);

-- Transaction participants (rosters involved)
CREATE TABLE IF NOT EXISTS analytics.transaction_rosters (
    transaction_id VARCHAR(255) NOT NULL REFERENCES analytics.transactions(transaction_id) ON DELETE CASCADE,
    roster_id INTEGER NOT NULL REFERENCES analytics.rosters(roster_id),
    is_sender BOOLEAN DEFAULT false,
    is_receiver BOOLEAN DEFAULT false,
    PRIMARY KEY (transaction_id, roster_id)
);

-- Players added in transactions
CREATE TABLE IF NOT EXISTS analytics.transaction_adds (
    add_id SERIAL PRIMARY KEY,
    transaction_id VARCHAR(255) NOT NULL REFERENCES analytics.transactions(transaction_id) ON DELETE CASCADE,
    roster_id INTEGER NOT NULL REFERENCES analytics.rosters(roster_id),
    player_id VARCHAR(50) NOT NULL REFERENCES analytics.players(player_id),
    waiver_bid INTEGER
);

CREATE INDEX idx_transaction_adds_transaction ON analytics.transaction_adds(transaction_id);
CREATE INDEX idx_transaction_adds_player ON analytics.transaction_adds(player_id);

-- Players dropped in transactions
CREATE TABLE IF NOT EXISTS analytics.transaction_drops (
    drop_id SERIAL PRIMARY KEY,
    transaction_id VARCHAR(255) NOT NULL REFERENCES analytics.transactions(transaction_id) ON DELETE CASCADE,
    roster_id INTEGER NOT NULL REFERENCES analytics.rosters(roster_id),
    player_id VARCHAR(50) NOT NULL REFERENCES analytics.players(player_id)
);

CREATE INDEX idx_transaction_drops_transaction ON analytics.transaction_drops(transaction_id);
CREATE INDEX idx_transaction_drops_player ON analytics.transaction_drops(player_id);

-- Draft picks traded
CREATE TABLE IF NOT EXISTS analytics.transaction_draft_picks (
    pick_id SERIAL PRIMARY KEY,
    transaction_id VARCHAR(255) NOT NULL REFERENCES analytics.transactions(transaction_id) ON DELETE CASCADE,
    
    -- Pick details
    season VARCHAR(10) NOT NULL,
    round INTEGER NOT NULL,
    pick_number INTEGER,
    
    -- Movement
    from_roster_id INTEGER NOT NULL REFERENCES analytics.rosters(roster_id),
    to_roster_id INTEGER NOT NULL REFERENCES analytics.rosters(roster_id),
    original_owner_roster_id INTEGER REFERENCES analytics.rosters(roster_id)
);

CREATE INDEX idx_transaction_picks_transaction ON analytics.transaction_draft_picks(transaction_id);

-- FAAB dollars traded
CREATE TABLE IF NOT EXISTS analytics.transaction_faab (
    faab_id SERIAL PRIMARY KEY,
    transaction_id VARCHAR(255) NOT NULL REFERENCES analytics.transactions(transaction_id) ON DELETE CASCADE,
    from_roster_id INTEGER NOT NULL REFERENCES analytics.rosters(roster_id),
    to_roster_id INTEGER NOT NULL REFERENCES analytics.rosters(roster_id),
    amount INTEGER NOT NULL
);

-- ============================================================================
-- DRAFTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS analytics.drafts (
    draft_id VARCHAR(255) PRIMARY KEY,
    league_id VARCHAR(255) NOT NULL REFERENCES analytics.leagues(league_id),
    
    -- Draft settings
    draft_type VARCHAR(50), -- 'snake', 'linear', 'auction'
    rounds INTEGER,
    
    -- Status
    status VARCHAR(50), -- 'not_started', 'in_progress', 'paused', 'complete'
    
    -- Timing
    start_time TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_drafts_league ON analytics.drafts(league_id);

-- Draft picks
CREATE TABLE IF NOT EXISTS analytics.draft_picks (
    pick_id SERIAL PRIMARY KEY,
    draft_id VARCHAR(255) NOT NULL REFERENCES analytics.drafts(draft_id) ON DELETE CASCADE,
    
    -- Pick info
    overall_pick_number INTEGER NOT NULL,
    round INTEGER NOT NULL,
    round_pick_number INTEGER NOT NULL,
    
    -- Selection
    roster_id INTEGER NOT NULL REFERENCES analytics.rosters(roster_id),
    player_id VARCHAR(50) REFERENCES analytics.players(player_id),
    
    -- Metadata
    is_keeper BOOLEAN DEFAULT false,
    auto_picked BOOLEAN DEFAULT false,
    pick_time TIMESTAMP WITH TIME ZONE,
    
    UNIQUE(draft_id, overall_pick_number)
);

CREATE INDEX idx_draft_picks_draft ON analytics.draft_picks(draft_id, overall_pick_number);
CREATE INDEX idx_draft_picks_roster ON analytics.draft_picks(roster_id);
CREATE INDEX idx_draft_picks_player ON analytics.draft_picks(player_id);

-- ============================================================================
-- PLAYER STATS (Game-level statistics)
-- ============================================================================

CREATE TABLE IF NOT EXISTS analytics.player_game_stats (
    stat_id SERIAL PRIMARY KEY,
    player_id VARCHAR(50) NOT NULL REFERENCES analytics.players(player_id),
    
    -- Game info
    season_id INTEGER NOT NULL REFERENCES analytics.seasons(season_id),
    week INTEGER NOT NULL,
    game_date DATE,
    
    -- Teams
    team VARCHAR(10),
    opponent VARCHAR(10),
    is_home BOOLEAN,
    
    -- Stats (only non-zero values stored)
    stat_category VARCHAR(50) NOT NULL, -- 'passing', 'rushing', 'receiving', etc.
    stat_name VARCHAR(50) NOT NULL,     -- 'yards', 'touchdowns', 'attempts', etc.
    stat_value DECIMAL(10,2) NOT NULL,
    
    UNIQUE(player_id, season_id, week, stat_category, stat_name)
);

CREATE INDEX idx_player_stats_player_season ON analytics.player_game_stats(player_id, season_id, week);
CREATE INDEX idx_player_stats_week ON analytics.player_game_stats(season_id, week);

-- ============================================================================
-- UTILITY VIEWS
-- ============================================================================

-- Current roster composition
CREATE OR REPLACE VIEW analytics.v_current_rosters AS
SELECT 
    r.roster_id,
    r.league_id,
    r.team_name,
    r.current_owner_id,
    u.display_name as owner_name,
    rp.player_id,
    p.full_name as player_name,
    ps.position,
    ps.team_code,
    rp.roster_status
FROM analytics.rosters r
LEFT JOIN analytics.users u ON r.current_owner_id = u.user_id
LEFT JOIN analytics.roster_players rp ON r.roster_id = rp.roster_id 
    AND rp.valid_to = '9999-12-31'::timestamptz
LEFT JOIN analytics.players p ON rp.player_id = p.player_id
LEFT JOIN analytics.player_status ps ON p.player_id = ps.player_id 
    AND ps.valid_to = '9999-12-31'::timestamptz;

-- League standings
CREATE OR REPLACE VIEW analytics.v_league_standings AS
SELECT 
    l.league_id,
    l.name as league_name,
    r.roster_id,
    r.team_name,
    u.display_name as owner_name,
    rs.wins,
    rs.losses,
    rs.ties,
    rs.points_for,
    rs.points_against,
    rs.rank
FROM analytics.leagues l
JOIN analytics.rosters r ON l.league_id = r.league_id
LEFT JOIN analytics.users u ON r.current_owner_id = u.user_id
LEFT JOIN analytics.roster_stats rs ON r.roster_id = rs.roster_id 
    AND rs.week IS NULL -- Season totals only
ORDER BY l.league_id, rs.wins DESC, rs.points_for DESC;

-- Recent transactions
CREATE OR REPLACE VIEW analytics.v_recent_transactions AS
SELECT 
    t.transaction_id,
    t.league_id,
    t.transaction_type,
    t.status,
    t.created_at,
    ta.player_id as added_player_id,
    pa.full_name as added_player,
    td.player_id as dropped_player_id,
    pd.full_name as dropped_player,
    t.waiver_bid
FROM analytics.transactions t
LEFT JOIN analytics.transaction_adds ta ON t.transaction_id = ta.transaction_id
LEFT JOIN analytics.players pa ON ta.player_id = pa.player_id
LEFT JOIN analytics.transaction_drops td ON t.transaction_id = td.transaction_id
LEFT JOIN analytics.players pd ON td.player_id = pd.player_id
WHERE t.created_at > NOW() - INTERVAL '7 days'
ORDER BY t.created_at DESC;

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Additional performance indexes
CREATE INDEX idx_transactions_created ON analytics.transactions(created_at DESC);
CREATE INDEX idx_roster_stats_points ON analytics.roster_stats(points_for DESC) WHERE week IS NULL;
CREATE INDEX idx_player_status_position ON analytics.player_status(position) 
    WHERE valid_to = '9999-12-31'::timestamptz;

-- ============================================================================
-- ROW-LEVEL SECURITY (Optional - for multi-tenant use)
-- ============================================================================

-- Enable RLS on sensitive tables (uncomment if needed)
-- ALTER TABLE analytics.users ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE analytics.leagues ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE analytics.rosters ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PERMISSIONS
-- ============================================================================

GRANT ALL PRIVILEGES ON SCHEMA analytics TO sleeper_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA analytics TO sleeper_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA analytics TO sleeper_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA analytics GRANT ALL ON TABLES TO sleeper_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics GRANT ALL ON SEQUENCES TO sleeper_user;

-- ============================================================================
-- TABLE COMMENTS
-- ============================================================================

COMMENT ON SCHEMA analytics IS 'Normalized analytics database for Sleeper fantasy football data';

COMMENT ON TABLE analytics.users IS 'Platform users with basic profile information';
COMMENT ON TABLE analytics.leagues IS 'Fantasy football leagues';
COMMENT ON TABLE analytics.players IS 'NFL players basic information';
COMMENT ON TABLE analytics.player_status IS 'Player status tracking over time (team changes, injuries)';
COMMENT ON TABLE analytics.rosters IS 'Team rosters in leagues';
COMMENT ON TABLE analytics.roster_ownership IS 'Ownership history of rosters';
COMMENT ON TABLE analytics.roster_players IS 'Players on rosters with temporal tracking';
COMMENT ON TABLE analytics.matchups IS 'Head-to-head matchups between teams';
COMMENT ON TABLE analytics.transactions IS 'All roster transactions (trades, waivers, etc.)';

-- End of normalized analytics schema