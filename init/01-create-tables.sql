-- Sleeper Fantasy Football Database Schema
-- PostgreSQL 17
-- 
-- This script creates all tables for the Sleeper fantasy football database.
-- Tables are created in dependency order to ensure foreign key constraints are satisfied.

-- ============================================================================
-- SCHEMA SETUP
-- ============================================================================

-- Create schema for Sleeper data
CREATE SCHEMA IF NOT EXISTS sleeper;

-- Set search path to include our schema
SET search_path TO sleeper, public;

-- Enable extensions if needed (in public schema)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA public;

-- Drop tables if they exist (in reverse dependency order)
DROP TABLE IF EXISTS sleeper.league_member CASCADE;
DROP TABLE IF EXISTS sleeper.player_trending CASCADE;
DROP TABLE IF EXISTS sleeper.traded_draft_pick CASCADE;
DROP TABLE IF EXISTS sleeper.draft_pick CASCADE;
DROP TABLE IF EXISTS sleeper.draft_slot CASCADE;
DROP TABLE IF EXISTS sleeper.draft CASCADE;
DROP TABLE IF EXISTS sleeper.transaction_draft_pick CASCADE;
DROP TABLE IF EXISTS sleeper.transaction_player CASCADE;
DROP TABLE IF EXISTS sleeper.transaction_roster CASCADE;
DROP TABLE IF EXISTS sleeper.transaction CASCADE;
DROP TABLE IF EXISTS sleeper.playoff_matchup CASCADE;
DROP TABLE IF EXISTS sleeper.playoff_bracket CASCADE;
DROP TABLE IF EXISTS sleeper.matchup_player_stat CASCADE;
DROP TABLE IF EXISTS sleeper.matchup_team CASCADE;
DROP TABLE IF EXISTS sleeper.matchup CASCADE;
DROP TABLE IF EXISTS sleeper.lineup_player CASCADE;
DROP TABLE IF EXISTS sleeper.weekly_lineup CASCADE;
DROP TABLE IF EXISTS sleeper.roster_player CASCADE;
DROP TABLE IF EXISTS sleeper.roster_co_owner CASCADE;
DROP TABLE IF EXISTS sleeper.roster CASCADE;
DROP TABLE IF EXISTS sleeper.player_fantasy_position CASCADE;
DROP TABLE IF EXISTS sleeper.player CASCADE;
DROP TABLE IF EXISTS sleeper.nfl_team CASCADE;
DROP TABLE IF EXISTS sleeper.league_roster_position CASCADE;
DROP TABLE IF EXISTS sleeper.league_scoring_setting CASCADE;
DROP TABLE IF EXISTS sleeper.league_setting CASCADE;
DROP TABLE IF EXISTS sleeper.league CASCADE;
DROP TABLE IF EXISTS sleeper.sport_state CASCADE;
DROP TABLE IF EXISTS sleeper.season CASCADE;
DROP TABLE IF EXISTS sleeper.sport CASCADE;
DROP TABLE IF EXISTS sleeper.user CASCADE;

-- ============================================================================
-- REFERENCE TABLES
-- ============================================================================

-- Sport Table
CREATE TABLE sleeper.sport (
    sport_id VARCHAR(10) PRIMARY KEY,  -- 'nfl', future: 'nba', etc.
    sport_name VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- NFL Team Table
CREATE TABLE sleeper.nfl_team (
    team_abbr VARCHAR(3) PRIMARY KEY,  -- 'KC', 'BUF', etc.
    team_name VARCHAR(50) NOT NULL,
    conference VARCHAR(3),  -- 'AFC', 'NFC'
    division VARCHAR(10) NOT NULL,  -- 'East', 'West', 'North', 'South'
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- USER TABLES
-- ============================================================================

-- User Table
CREATE TABLE sleeper.user (
    user_id VARCHAR(50) PRIMARY KEY,  -- From Sleeper API
    username VARCHAR(50) UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    avatar VARCHAR(100),  -- Avatar ID for CDN URL construction
    is_bot BOOLEAN DEFAULT FALSE,
    email VARCHAR(255),
    phone VARCHAR(20),
    real_name VARCHAR(100),
    verification_status VARCHAR(20),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    sleeper_created_at TIMESTAMP,  -- When account was created in Sleeper
    metadata JSONB  -- Flexible storage for additional user attributes
);

-- ============================================================================
-- SEASON TABLES
-- ============================================================================

-- Season Table
CREATE TABLE sleeper.season (
    season_id SERIAL PRIMARY KEY,
    sport_id VARCHAR(10) NOT NULL REFERENCES sleeper.sport(sport_id),
    year VARCHAR(4) NOT NULL,  -- '2024'
    season_type VARCHAR(20) NOT NULL,  -- 'regular', 'post', 'off'
    start_date DATE,
    end_date DATE,
    is_current BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(sport_id, year)
);

-- Sport State Table
CREATE TABLE sleeper.sport_state (
    state_id SERIAL PRIMARY KEY,
    sport_id VARCHAR(10) NOT NULL REFERENCES sleeper.sport(sport_id),
    season_id INTEGER REFERENCES sleeper.season(season_id),
    current_week INTEGER NOT NULL,
    season_type VARCHAR(20) NOT NULL,
    season VARCHAR(4) NOT NULL,
    display_week INTEGER,
    leg INTEGER,
    league_season VARCHAR(4),
    league_create_season VARCHAR(4),
    previous_season VARCHAR(4),
    season_start_date DATE,
    season_has_scores BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(sport_id, season)
);

-- ============================================================================
-- LEAGUE TABLES
-- ============================================================================

-- League Table
CREATE TABLE sleeper.league (
    league_id VARCHAR(50) PRIMARY KEY,  -- From Sleeper API
    season_id INTEGER NOT NULL REFERENCES sleeper.season(season_id),
    sport_id VARCHAR(10) NOT NULL REFERENCES sleeper.sport(sport_id),
    name VARCHAR(255) NOT NULL,
    avatar VARCHAR(100),  -- Avatar ID for CDN URL construction
    status VARCHAR(20) NOT NULL,  -- 'pre_draft', 'drafting', 'in_season', 'complete'
    season_type VARCHAR(20),
    total_rosters INTEGER NOT NULL,
    draft_id VARCHAR(50),  -- Reference to drafts table
    previous_league_id VARCHAR(50) REFERENCES sleeper.league(league_id),
    bracket_id VARCHAR(50),
    loser_bracket_id VARCHAR(50),
    shard INTEGER,
    company_id VARCHAR(50),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_transaction_id VARCHAR(50),
    last_message_time TIMESTAMP,
    display_order INTEGER,
    metadata JSONB,  -- Custom league metadata
    last_synced_at TIMESTAMP,
    api_version BIGINT  -- For change detection
);

-- League Setting Table
CREATE TABLE sleeper.league_setting (
    league_id VARCHAR(50) PRIMARY KEY REFERENCES sleeper.league(league_id) ON DELETE CASCADE,
    max_keepers INTEGER DEFAULT 0,
    draft_rounds INTEGER,
    trade_deadline INTEGER,
    waiver_type VARCHAR(20),  -- 'traditional', 'faab'
    waiver_day_of_week INTEGER,  -- 0-6
    waiver_budget INTEGER DEFAULT 100,
    waiver_clear_days INTEGER,
    playoff_week_start INTEGER,
    playoff_teams INTEGER DEFAULT 6,
    daily_waivers BOOLEAN DEFAULT FALSE,
    reserve_slots INTEGER DEFAULT 0,
    reserve_allow_out BOOLEAN DEFAULT TRUE,
    reserve_allow_na BOOLEAN DEFAULT FALSE,
    reserve_allow_dnr BOOLEAN DEFAULT FALSE,
    reserve_allow_doubtful BOOLEAN DEFAULT TRUE,
    taxi_slots INTEGER DEFAULT 0,
    taxi_years INTEGER,
    taxi_allow_vets BOOLEAN DEFAULT FALSE,
    taxi_deadline INTEGER,
    pick_trading BOOLEAN DEFAULT TRUE,
    disable_trades BOOLEAN DEFAULT FALSE,
    trade_review_days INTEGER DEFAULT 1,
    commissioner_direct_invite BOOLEAN DEFAULT TRUE,
    capacity_override BOOLEAN DEFAULT FALSE,
    disable_counter BOOLEAN DEFAULT FALSE,
    type INTEGER DEFAULT 0,  -- League type
    best_ball BOOLEAN DEFAULT FALSE,
    last_report INTEGER,
    last_scored_leg INTEGER,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- League Scoring Setting Table
CREATE TABLE sleeper.league_scoring_setting (
    league_id VARCHAR(50) PRIMARY KEY REFERENCES sleeper.league(league_id) ON DELETE CASCADE,
    pass_td DECIMAL(4,2) DEFAULT 6.0,
    pass_yd DECIMAL(4,2) DEFAULT 0.04,
    pass_int DECIMAL(4,2) DEFAULT -2.0,
    pass_2pt DECIMAL(4,2) DEFAULT 2.0,
    rush_td DECIMAL(4,2) DEFAULT 6.0,
    rush_yd DECIMAL(4,2) DEFAULT 0.1,
    rush_2pt DECIMAL(4,2) DEFAULT 2.0,
    rec_td DECIMAL(4,2) DEFAULT 6.0,
    rec_yd DECIMAL(4,2) DEFAULT 0.1,
    rec DECIMAL(4,2) DEFAULT 0.0,  -- PPR value
    rec_2pt DECIMAL(4,2) DEFAULT 2.0,
    fum_lost DECIMAL(4,2) DEFAULT -2.0,
    fum_rec_td DECIMAL(4,2) DEFAULT 6.0,
    fg_0_19 DECIMAL(4,2) DEFAULT 3.0,
    fg_20_29 DECIMAL(4,2) DEFAULT 3.0,
    fg_30_39 DECIMAL(4,2) DEFAULT 3.0,
    fg_40_49 DECIMAL(4,2) DEFAULT 4.0,
    fg_50_plus DECIMAL(4,2) DEFAULT 5.0,
    fg_miss DECIMAL(4,2) DEFAULT -1.0,
    xp_make DECIMAL(4,2) DEFAULT 1.0,
    xp_miss DECIMAL(4,2) DEFAULT -1.0,
    def_td DECIMAL(4,2) DEFAULT 6.0,
    def_sack DECIMAL(4,2) DEFAULT 1.0,
    def_int DECIMAL(4,2) DEFAULT 2.0,
    def_fum_rec DECIMAL(4,2) DEFAULT 2.0,
    def_safety DECIMAL(4,2) DEFAULT 2.0,
    def_blk DECIMAL(4,2) DEFAULT 2.0,
    def_points_allowed_0 DECIMAL(4,2) DEFAULT 10.0,
    def_points_allowed_1_6 DECIMAL(4,2) DEFAULT 7.0,
    def_points_allowed_7_13 DECIMAL(4,2) DEFAULT 4.0,
    def_points_allowed_14_20 DECIMAL(4,2) DEFAULT 1.0,
    def_points_allowed_21_27 DECIMAL(4,2) DEFAULT 0.0,
    def_points_allowed_28_34 DECIMAL(4,2) DEFAULT -1.0,
    def_points_allowed_35_plus DECIMAL(4,2) DEFAULT -4.0,
    bonus_pass_yd_300 DECIMAL(4,2) DEFAULT 0.0,
    bonus_pass_yd_400 DECIMAL(4,2) DEFAULT 0.0,
    bonus_rush_yd_100 DECIMAL(4,2) DEFAULT 0.0,
    bonus_rush_yd_200 DECIMAL(4,2) DEFAULT 0.0,
    bonus_rec_yd_100 DECIMAL(4,2) DEFAULT 0.0,
    bonus_rec_yd_200 DECIMAL(4,2) DEFAULT 0.0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    additional_scoring JSONB  -- For any non-standard scoring settings
);

-- League Roster Position Table
CREATE TABLE sleeper.league_roster_position (
    position_id SERIAL PRIMARY KEY,
    league_id VARCHAR(50) NOT NULL REFERENCES sleeper.league(league_id) ON DELETE CASCADE,
    position VARCHAR(20) NOT NULL,  -- 'QB', 'RB', 'WR', 'TE', 'FLEX', 'SUPER_FLEX', 'K', 'DEF', 'BN'
    count INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(league_id, position)
);

-- ============================================================================
-- PLAYER TABLES
-- ============================================================================

-- Player Table
CREATE TABLE sleeper.player (
    player_id VARCHAR(50) PRIMARY KEY,  -- From Sleeper API
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    full_name VARCHAR(100),
    search_full_name VARCHAR(100),  -- Normalized for searching
    position VARCHAR(10),  -- Primary position
    team_abbr VARCHAR(3) REFERENCES sleeper.nfl_team(team_abbr),
    status VARCHAR(30),  -- 'Active', 'Inactive', 'Injured Reserve', 'Practice Squad'
    injury_status VARCHAR(20),  -- 'Questionable', 'Doubtful', 'Out', NULL
    injury_body_part VARCHAR(50),
    injury_notes TEXT,
    injury_start_date DATE,
    practice_participation VARCHAR(30),
    practice_description VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    depth_chart_order INTEGER,
    depth_chart_position VARCHAR(20),
    jersey_number INTEGER,
    height INTEGER,  -- in inches
    weight INTEGER,  -- in pounds
    age INTEGER,
    years_exp INTEGER,
    birth_date DATE,
    birth_city VARCHAR(50),
    birth_state VARCHAR(50),
    birth_country VARCHAR(50),
    college VARCHAR(100),
    high_school VARCHAR(100),
    sport VARCHAR(10) DEFAULT 'nfl',
    search_rank INTEGER,  -- For search optimization
    news_updated TIMESTAMP,
    hashtag VARCHAR(50),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    metadata JSONB,  -- Additional flexible attributes
    external_ids JSONB,  -- Store all external IDs (ESPN, Yahoo, etc.)
    last_synced_at TIMESTAMP
);

-- Player Fantasy Position Table
CREATE TABLE sleeper.player_fantasy_position (
    player_id VARCHAR(50) NOT NULL REFERENCES sleeper.player(player_id) ON DELETE CASCADE,
    position VARCHAR(10) NOT NULL,
    PRIMARY KEY (player_id, position)
);

-- ============================================================================
-- ROSTER TABLES
-- ============================================================================

-- Roster Table
CREATE TABLE sleeper.roster (
    league_id VARCHAR(50) NOT NULL REFERENCES sleeper.league(league_id) ON DELETE CASCADE,
    roster_id INTEGER NOT NULL,  -- From Sleeper API (1-based within each league)
    owner_user_id VARCHAR(50) REFERENCES sleeper.user(user_id),
    roster_position INTEGER NOT NULL,  -- 1-based position in league
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    ties INTEGER DEFAULT 0,
    total_moves INTEGER DEFAULT 0,
    waiver_position INTEGER,
    waiver_budget_used INTEGER DEFAULT 0,
    fantasy_points_for DECIMAL(10,2) DEFAULT 0,
    fantasy_points_against DECIMAL(10,2) DEFAULT 0,
    points_for_decimal DECIMAL(10,2) DEFAULT 0,
    points_against_decimal DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_synced_at TIMESTAMP,
    api_checksum VARCHAR(64),  -- For change detection
    metadata JSONB,  -- Team name, avatar, custom settings
    PRIMARY KEY (league_id, roster_id),
    UNIQUE(league_id, roster_position),
    UNIQUE(league_id, owner_user_id)  -- One roster per user per league
);

-- Roster Co-Owner Table
CREATE TABLE sleeper.roster_co_owner (
    league_id VARCHAR(50) NOT NULL,
    roster_id INTEGER NOT NULL,
    user_id VARCHAR(50) NOT NULL REFERENCES sleeper.user(user_id),
    PRIMARY KEY (league_id, roster_id, user_id),
    FOREIGN KEY (league_id, roster_id) REFERENCES sleeper.roster(league_id, roster_id) ON DELETE CASCADE
);

-- Roster Player Table
CREATE TABLE sleeper.roster_player (
    roster_player_id SERIAL PRIMARY KEY,
    league_id VARCHAR(50) NOT NULL,
    roster_id INTEGER NOT NULL,
    player_id VARCHAR(50) NOT NULL REFERENCES sleeper.player(player_id),
    acquisition_date TIMESTAMP NOT NULL DEFAULT NOW(),
    acquisition_type VARCHAR(20),  -- 'draft', 'trade', 'waiver', 'free_agent'
    status VARCHAR(20) DEFAULT 'active',  -- 'active', 'reserve', 'taxi', 'inactive'
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(league_id, roster_id, player_id),
    FOREIGN KEY (league_id, roster_id) REFERENCES sleeper.roster(league_id, roster_id) ON DELETE CASCADE
);

-- Weekly Lineup Table
CREATE TABLE sleeper.weekly_lineup (
    lineup_id SERIAL PRIMARY KEY,
    league_id VARCHAR(50) NOT NULL,
    roster_id INTEGER NOT NULL,
    week INTEGER NOT NULL,
    season_id INTEGER NOT NULL REFERENCES sleeper.season(season_id),
    submitted_at TIMESTAMP,
    is_final BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(league_id, roster_id, week, season_id),
    FOREIGN KEY (league_id, roster_id) REFERENCES sleeper.roster(league_id, roster_id) ON DELETE CASCADE
);

-- Lineup Player Table
CREATE TABLE sleeper.lineup_player (
    lineup_player_id SERIAL PRIMARY KEY,
    lineup_id INTEGER NOT NULL REFERENCES sleeper.weekly_lineup(lineup_id) ON DELETE CASCADE,
    player_id VARCHAR(50) NOT NULL REFERENCES sleeper.player(player_id),
    roster_slot VARCHAR(20) NOT NULL,  -- 'QB', 'RB1', 'RB2', 'WR1', 'FLEX', 'BN1', etc.
    slot_index INTEGER NOT NULL,  -- Order within position
    projected_points DECIMAL(6,2),
    actual_points DECIMAL(6,2),
    is_starter BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- MATCHUP TABLES
-- ============================================================================

-- Matchup Table
CREATE TABLE sleeper.matchup (
    matchup_id SERIAL PRIMARY KEY,
    league_id VARCHAR(50) NOT NULL REFERENCES sleeper.league(league_id) ON DELETE CASCADE,
    week INTEGER NOT NULL,
    season_id INTEGER NOT NULL REFERENCES sleeper.season(season_id),
    matchup_number INTEGER NOT NULL,  -- Groups matchups together
    is_playoff BOOLEAN DEFAULT FALSE,
    is_consolation BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_synced_at TIMESTAMP,
    UNIQUE(league_id, week, season_id, matchup_number)
);

-- Matchup Team Table
CREATE TABLE sleeper.matchup_team (
    matchup_team_id SERIAL PRIMARY KEY,
    matchup_id INTEGER NOT NULL REFERENCES sleeper.matchup(matchup_id) ON DELETE CASCADE,
    league_id VARCHAR(50) NOT NULL,
    roster_id INTEGER NOT NULL,
    points DECIMAL(8,2) DEFAULT 0,
    custom_points DECIMAL(8,2),
    is_winner BOOLEAN,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(matchup_id, roster_id),
    FOREIGN KEY (league_id, roster_id) REFERENCES sleeper.roster(league_id, roster_id)
);

-- Matchup Player Stat Table
CREATE TABLE sleeper.matchup_player_stat (
    stat_id SERIAL PRIMARY KEY,
    matchup_team_id INTEGER NOT NULL REFERENCES sleeper.matchup_team(matchup_team_id) ON DELETE CASCADE,
    player_id VARCHAR(50) NOT NULL REFERENCES sleeper.player(player_id),
    points DECIMAL(6,2) NOT NULL,
    projected_points DECIMAL(6,2),
    is_starter BOOLEAN DEFAULT TRUE,
    slot_position VARCHAR(20),  -- Position they were started in
    stats JSONB,  -- Complete stats object from API
    breakdown JSONB,  -- Scoring breakdown
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- PLAYOFF TABLES
-- ============================================================================

-- Playoff Bracket Table
CREATE TABLE sleeper.playoff_bracket (
    bracket_id SERIAL PRIMARY KEY,
    league_id VARCHAR(50) NOT NULL REFERENCES sleeper.league(league_id) ON DELETE CASCADE,
    bracket_type VARCHAR(20) NOT NULL,  -- 'winners', 'losers', 'toilet'
    season_id INTEGER NOT NULL REFERENCES sleeper.season(season_id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(league_id, bracket_type, season_id)
);

-- Playoff Matchup Table
CREATE TABLE sleeper.playoff_matchup (
    playoff_matchup_id SERIAL PRIMARY KEY,
    bracket_id INTEGER NOT NULL REFERENCES sleeper.playoff_bracket(bracket_id) ON DELETE CASCADE,
    round INTEGER NOT NULL,
    matchup_number INTEGER NOT NULL,
    team1_league_id VARCHAR(50),
    team1_roster_id INTEGER,
    team2_league_id VARCHAR(50),
    team2_roster_id INTEGER,
    winner_league_id VARCHAR(50),
    winner_roster_id INTEGER,
    team1_seed INTEGER,
    team2_seed INTEGER,
    team1_from_matchup INTEGER REFERENCES sleeper.playoff_matchup(playoff_matchup_id),
    team1_from_result VARCHAR(1),  -- 'W' or 'L'
    team2_from_matchup INTEGER REFERENCES sleeper.playoff_matchup(playoff_matchup_id),
    team2_from_result VARCHAR(1),  -- 'W' or 'L'
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    FOREIGN KEY (team1_league_id, team1_roster_id) REFERENCES sleeper.roster(league_id, roster_id),
    FOREIGN KEY (team2_league_id, team2_roster_id) REFERENCES sleeper.roster(league_id, roster_id),
    FOREIGN KEY (winner_league_id, winner_roster_id) REFERENCES sleeper.roster(league_id, roster_id)
);

-- ============================================================================
-- TRANSACTION TABLES
-- ============================================================================

-- Transaction Table
CREATE TABLE sleeper.transaction (
    transaction_id VARCHAR(50) PRIMARY KEY,  -- From Sleeper API
    league_id VARCHAR(50) NOT NULL REFERENCES sleeper.league(league_id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL,  -- 'trade', 'waiver', 'free_agent', 'commissioner'
    status VARCHAR(20) NOT NULL,  -- 'complete', 'pending', 'failed'
    week INTEGER NOT NULL,
    season_id INTEGER NOT NULL REFERENCES sleeper.season(season_id),
    status_updated_at TIMESTAMP,
    creator_user_id VARCHAR(50) REFERENCES sleeper.user(user_id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMP,
    metadata JSONB,  -- Additional transaction details
    last_synced_at TIMESTAMP
);

-- Transaction Roster Involvement Table
CREATE TABLE sleeper.transaction_roster (
    transaction_id VARCHAR(50) NOT NULL REFERENCES sleeper.transaction(transaction_id) ON DELETE CASCADE,
    league_id VARCHAR(50) NOT NULL,
    roster_id INTEGER NOT NULL,
    is_consenter BOOLEAN DEFAULT FALSE,  -- Needs to approve
    has_consented BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (transaction_id, roster_id),
    FOREIGN KEY (league_id, roster_id) REFERENCES sleeper.roster(league_id, roster_id)
);

-- Transaction Player Table
CREATE TABLE sleeper.transaction_player (
    transaction_player_id SERIAL PRIMARY KEY,
    transaction_id VARCHAR(50) NOT NULL REFERENCES sleeper.transaction(transaction_id) ON DELETE CASCADE,
    player_id VARCHAR(50) NOT NULL REFERENCES sleeper.player(player_id),
    action VARCHAR(10) NOT NULL,  -- 'add' or 'drop'
    league_id VARCHAR(50) NOT NULL,
    roster_id INTEGER NOT NULL,
    waiver_bid INTEGER,  -- FAAB amount if applicable
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    FOREIGN KEY (league_id, roster_id) REFERENCES sleeper.roster(league_id, roster_id)
);

-- Transaction Draft Pick Table
CREATE TABLE sleeper.transaction_draft_pick (
    transaction_pick_id SERIAL PRIMARY KEY,
    transaction_id VARCHAR(50) NOT NULL REFERENCES sleeper.transaction(transaction_id) ON DELETE CASCADE,
    season VARCHAR(4) NOT NULL,
    round INTEGER NOT NULL,
    league_id VARCHAR(50) NOT NULL,
    from_roster_id INTEGER NOT NULL,
    to_roster_id INTEGER NOT NULL,
    original_owner_roster_id INTEGER,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    FOREIGN KEY (league_id, from_roster_id) REFERENCES sleeper.roster(league_id, roster_id),
    FOREIGN KEY (league_id, to_roster_id) REFERENCES sleeper.roster(league_id, roster_id),
    FOREIGN KEY (league_id, original_owner_roster_id) REFERENCES sleeper.roster(league_id, roster_id)
);

-- ============================================================================
-- DRAFT TABLES
-- ============================================================================

-- Draft Table
CREATE TABLE sleeper.draft (
    draft_id VARCHAR(50) PRIMARY KEY,  -- From Sleeper API
    league_id VARCHAR(50) NOT NULL REFERENCES sleeper.league(league_id),
    sport_id VARCHAR(10) NOT NULL REFERENCES sleeper.sport(sport_id),
    season_id INTEGER NOT NULL REFERENCES sleeper.season(season_id),
    type VARCHAR(20) NOT NULL,  -- 'snake', 'linear', 'auction'
    status VARCHAR(20) NOT NULL,  -- 'pre_draft', 'drafting', 'paused', 'complete'
    start_time TIMESTAMP,
    rounds INTEGER NOT NULL,
    picks_per_round INTEGER NOT NULL,
    reversal_round INTEGER DEFAULT 0,
    pick_timer INTEGER,  -- Seconds per pick
    nomination_timer INTEGER,  -- For auction drafts
    enforce_position_limits BOOLEAN DEFAULT FALSE,
    cpu_autopick BOOLEAN DEFAULT TRUE,
    autostart BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP,
    metadata JSONB  -- Additional draft settings
);

-- Draft Slot Table
CREATE TABLE sleeper.draft_slot (
    draft_id VARCHAR(50) NOT NULL REFERENCES sleeper.draft(draft_id) ON DELETE CASCADE,
    slot INTEGER NOT NULL,
    league_id VARCHAR(50),
    roster_id INTEGER,
    user_id VARCHAR(50) REFERENCES sleeper.user(user_id),
    is_keeper_slot BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (draft_id, slot),
    FOREIGN KEY (league_id, roster_id) REFERENCES sleeper.roster(league_id, roster_id)
);

-- Draft Pick Table
CREATE TABLE sleeper.draft_pick (
    pick_id SERIAL PRIMARY KEY,
    draft_id VARCHAR(50) NOT NULL REFERENCES sleeper.draft(draft_id) ON DELETE CASCADE,
    round INTEGER NOT NULL,
    pick_in_round INTEGER NOT NULL,
    overall_pick INTEGER NOT NULL,
    slot INTEGER NOT NULL,
    league_id VARCHAR(50),
    roster_id INTEGER,
    player_id VARCHAR(50) REFERENCES sleeper.player(player_id),
    picked_by_user_id VARCHAR(50) REFERENCES sleeper.user(user_id),
    pick_time TIMESTAMP,
    is_keeper BOOLEAN DEFAULT FALSE,
    auction_amount INTEGER,  -- For auction drafts
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    metadata JSONB,  -- Player info at time of pick
    UNIQUE(draft_id, overall_pick),
    FOREIGN KEY (league_id, roster_id) REFERENCES sleeper.roster(league_id, roster_id)
);

-- Traded Draft Pick Table
CREATE TABLE sleeper.traded_draft_pick (
    traded_pick_id SERIAL PRIMARY KEY,
    league_id VARCHAR(50) NOT NULL REFERENCES sleeper.league(league_id) ON DELETE CASCADE,
    season VARCHAR(4) NOT NULL,
    round INTEGER NOT NULL,
    original_owner_roster_id INTEGER NOT NULL,
    current_owner_roster_id INTEGER NOT NULL,
    previous_owner_roster_id INTEGER,
    trade_transaction_id VARCHAR(50) REFERENCES sleeper.transaction(transaction_id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    FOREIGN KEY (league_id, original_owner_roster_id) REFERENCES sleeper.roster(league_id, roster_id),
    FOREIGN KEY (league_id, current_owner_roster_id) REFERENCES sleeper.roster(league_id, roster_id),
    FOREIGN KEY (league_id, previous_owner_roster_id) REFERENCES sleeper.roster(league_id, roster_id)
);

-- ============================================================================
-- ANALYTICS TABLES
-- ============================================================================

-- Player Trending Table
CREATE TABLE sleeper.player_trending (
    trending_id SERIAL PRIMARY KEY,
    player_id VARCHAR(50) NOT NULL REFERENCES sleeper.player(player_id),
    sport_id VARCHAR(10) NOT NULL REFERENCES sleeper.sport(sport_id),
    trend_type VARCHAR(10) NOT NULL,  -- 'add' or 'drop'
    count INTEGER NOT NULL,
    date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(player_id, sport_id, trend_type, date)
);

-- League Member Table
CREATE TABLE sleeper.league_member (
    league_id VARCHAR(50) NOT NULL REFERENCES sleeper.league(league_id) ON DELETE CASCADE,
    user_id VARCHAR(50) NOT NULL REFERENCES sleeper.user(user_id),
    roster_id INTEGER,
    is_owner BOOLEAN DEFAULT FALSE,
    is_commissioner BOOLEAN DEFAULT FALSE,
    join_date TIMESTAMP NOT NULL DEFAULT NOW(),
    leave_date TIMESTAMP,
    display_name VARCHAR(100),
    team_name VARCHAR(100),
    avatar VARCHAR(100),  -- Avatar ID for CDN URL construction
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    metadata JSONB,  -- User-specific league settings
    PRIMARY KEY (league_id, user_id),
    FOREIGN KEY (league_id, roster_id) REFERENCES sleeper.roster(league_id, roster_id)
);

-- ============================================================================
-- SYSTEM TABLES
-- ============================================================================

-- Data Sync Log Table
CREATE TABLE sleeper.data_sync_log (
    sync_id SERIAL PRIMARY KEY,
    sync_type VARCHAR(50) NOT NULL,  -- 'leagues', 'rosters', 'users', 'players', 'matchups', 'transactions', 'drafts'
    entity_id VARCHAR(50),  -- The specific entity ID being synced (league_id, user_id, etc.)
    status VARCHAR(20) NOT NULL,  -- 'pending', 'in_progress', 'completed', 'failed'
    started_at TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP,
    records_processed INTEGER DEFAULT 0,
    error_message TEXT,
    metadata JSONB,  -- Additional sync details, API response info
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Sync Configuration Table
CREATE TABLE sleeper.sync_config (
    config_id SERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL UNIQUE,
    sync_frequency_seconds INTEGER DEFAULT 120,
    last_successful_sync TIMESTAMP,
    is_enabled BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 5,
    max_retries INTEGER DEFAULT 3,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Sync Queue Table
CREATE TABLE sleeper.sync_queue (
    queue_id SERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(50) NOT NULL,
    priority INTEGER DEFAULT 5,
    status VARCHAR(20) DEFAULT 'pending',
    attempts INTEGER DEFAULT 0,
    scheduled_at TIMESTAMP DEFAULT NOW(),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    error_message TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(entity_type, entity_id, status)
);

-- League Draft Association Table
CREATE TABLE sleeper.league_draft (
    league_id VARCHAR(50) REFERENCES sleeper.league(league_id),
    draft_id VARCHAR(50) REFERENCES sleeper.draft(draft_id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (league_id, draft_id)
);

-- Waiver Claim Table
CREATE TABLE sleeper.waiver_claim (
    claim_id SERIAL PRIMARY KEY,
    transaction_id VARCHAR(50) REFERENCES sleeper.transaction(transaction_id),
    league_id VARCHAR(50) NOT NULL,
    roster_id INTEGER NOT NULL,
    player_id VARCHAR(50) REFERENCES sleeper.player(player_id),
    bid_amount INTEGER,
    priority INTEGER,
    status VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    FOREIGN KEY (league_id, roster_id) REFERENCES sleeper.roster(league_id, roster_id)
);

-- Player Week Stat Table
CREATE TABLE sleeper.player_week_stat (
    player_id VARCHAR(50) REFERENCES sleeper.player(player_id),
    week INTEGER NOT NULL,
    season_id INTEGER REFERENCES sleeper.season(season_id),
    projected_points DECIMAL(6,2),
    actual_points DECIMAL(6,2),
    stats JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (player_id, week, season_id)
);

-- ============================================================================
-- COMMENTS
-- ============================================================================

-- Add comments to tables
COMMENT ON TABLE sleeper.user IS 'Sleeper platform users';
COMMENT ON TABLE sleeper.league IS 'Fantasy football leagues';
COMMENT ON TABLE sleeper.player IS 'NFL players';
COMMENT ON TABLE sleeper.roster IS 'Team rosters within leagues';
COMMENT ON TABLE sleeper.transaction IS 'All league transactions (trades, waivers, etc.)';
COMMENT ON TABLE sleeper.matchup IS 'Weekly head-to-head matchups';
COMMENT ON TABLE sleeper.draft IS 'League drafts';
COMMENT ON TABLE sleeper.data_sync_log IS 'Tracks data synchronization history from Sleeper API';
COMMENT ON TABLE sleeper.sync_config IS 'Configuration for automated sync processes';
COMMENT ON TABLE sleeper.sync_queue IS 'Queue for pending sync operations';
COMMENT ON TABLE sleeper.league_draft IS 'Association between leagues and their drafts';
COMMENT ON TABLE sleeper.waiver_claim IS 'Individual waiver claims within transactions';
COMMENT ON TABLE sleeper.player_week_stat IS 'Weekly player statistics and projections';

-- ============================================================================
-- SCHEMA PERMISSIONS AND SEARCH PATH
-- ============================================================================

-- Grant usage on schema to the database user
GRANT USAGE ON SCHEMA sleeper TO sleeper_user;
GRANT CREATE ON SCHEMA sleeper TO sleeper_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA sleeper TO sleeper_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA sleeper TO sleeper_user;

-- Set default search path for the database
ALTER DATABASE sleeper_db SET search_path TO sleeper, public;