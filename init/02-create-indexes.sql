-- Sleeper Fantasy Football Database Indexes
-- PostgreSQL 17
--
-- This script creates all indexes for optimal query performance

-- Set search path to our schema
SET search_path TO sleeper, public;

-- ============================================================================
-- USER INDEXES
-- ============================================================================

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email) WHERE email IS NOT NULL;

-- ============================================================================
-- LEAGUE INDEXES  
-- ============================================================================

CREATE INDEX idx_leagues_sport_season ON leagues(sport_id, season_id);
CREATE INDEX idx_leagues_status ON leagues(status);
CREATE INDEX idx_league_members_user ON league_members(user_id);

-- ============================================================================
-- PLAYER INDEXES
-- ============================================================================

CREATE INDEX idx_players_search_name ON players(search_full_name);
CREATE INDEX idx_players_team ON players(team_abbr);
CREATE INDEX idx_players_position ON players(position);
CREATE INDEX idx_players_status ON players(status);

-- ============================================================================
-- ROSTER INDEXES
-- ============================================================================

CREATE INDEX idx_rosters_league ON rosters(league_id);
CREATE INDEX idx_rosters_owner ON rosters(owner_user_id);
CREATE INDEX idx_roster_players_roster ON roster_players(roster_id);
CREATE INDEX idx_roster_players_player ON roster_players(player_id);

-- ============================================================================
-- MATCHUP INDEXES
-- ============================================================================

CREATE INDEX idx_matchups_league_week ON matchups(league_id, week);
CREATE INDEX idx_matchup_teams_matchup ON matchup_teams(matchup_id);
CREATE INDEX idx_matchup_teams_roster ON matchup_teams(roster_id);

-- ============================================================================
-- TRANSACTION INDEXES
-- ============================================================================

CREATE INDEX idx_transactions_league ON transactions(league_id);
CREATE INDEX idx_transactions_type_status ON transactions(type, status);
CREATE INDEX idx_transactions_week ON transactions(week);
CREATE INDEX idx_transaction_players_player ON transaction_players(player_id);

-- ============================================================================
-- DRAFT INDEXES
-- ============================================================================

CREATE INDEX idx_drafts_league ON drafts(league_id);
CREATE INDEX idx_draft_picks_draft ON draft_picks(draft_id);
CREATE INDEX idx_draft_picks_player ON draft_picks(player_id);

-- ============================================================================
-- TRENDING DATA INDEXES
-- ============================================================================

CREATE INDEX idx_player_trending_date ON player_trending(date DESC);
CREATE INDEX idx_player_trending_player ON player_trending(player_id);

-- ============================================================================
-- SYNC LOG INDEXES
-- ============================================================================

CREATE INDEX idx_sync_log_type_status ON data_sync_log(sync_type, status);
CREATE INDEX idx_sync_log_entity ON data_sync_log(entity_id) WHERE entity_id IS NOT NULL;