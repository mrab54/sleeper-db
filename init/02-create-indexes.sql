-- Sleeper Fantasy Football Database Indexes - OPTIMIZED
-- PostgreSQL 17
--
-- This script creates all indexes for optimal query performance
-- CRITICAL FIXES: Added missing FK indexes and composite indexes for sync operations

-- Set search path to our schema
SET search_path TO sleeper, public;

-- ============================================================================
-- CRITICAL: FOREIGN KEY INDEXES (Missing from original - MAJOR PERFORMANCE ISSUE)
-- ============================================================================

-- These are ESSENTIAL for performance - every FK should have an index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_league_season_id ON sleeper.league(season_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_league_sport_id ON sleeper.league(sport_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_season_sport_id ON sleeper.season(sport_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sport_state_sport_id ON sleeper.sport_state(sport_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sport_state_season_id ON sleeper.sport_state(season_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_player_team_abbr ON sleeper.player(team_abbr);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_roster_co_owner_user_id ON sleeper.roster_co_owner(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_roster_player_player_id ON sleeper.roster_player(player_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_weekly_lineup_season_id ON sleeper.weekly_lineup(season_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_lineup_player_lineup_id ON sleeper.lineup_player(lineup_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_lineup_player_player_id ON sleeper.lineup_player(player_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_matchup_league_id ON sleeper.matchup(league_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_matchup_season_id ON sleeper.matchup(season_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_matchup_team_matchup_id ON sleeper.matchup_team(matchup_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_matchup_player_stat_matchup_team_id ON sleeper.matchup_player_stat(matchup_team_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_matchup_player_stat_player_id ON sleeper.matchup_player_stat(player_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_playoff_bracket_league_id ON sleeper.playoff_bracket(league_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_playoff_bracket_season_id ON sleeper.playoff_bracket(season_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_playoff_matchup_bracket_id ON sleeper.playoff_matchup(bracket_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transaction_league_id ON sleeper.transaction(league_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transaction_season_id ON sleeper.transaction(season_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transaction_creator_user_id ON sleeper.transaction(creator_user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transaction_roster_transaction_id ON sleeper.transaction_roster(transaction_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transaction_player_transaction_id ON sleeper.transaction_player(transaction_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transaction_player_player_id ON sleeper.transaction_player(player_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transaction_draft_pick_transaction_id ON sleeper.transaction_draft_pick(transaction_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_draft_league_id ON sleeper.draft(league_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_draft_sport_id ON sleeper.draft(sport_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_draft_season_id ON sleeper.draft(season_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_draft_slot_draft_id ON sleeper.draft_slot(draft_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_draft_slot_user_id ON sleeper.draft_slot(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_draft_pick_draft_id ON sleeper.draft_pick(draft_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_draft_pick_player_id ON sleeper.draft_pick(player_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_draft_pick_picked_by_user_id ON sleeper.draft_pick(picked_by_user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_traded_draft_pick_league_id ON sleeper.traded_draft_pick(league_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_traded_draft_pick_trade_transaction_id ON sleeper.traded_draft_pick(trade_transaction_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_player_trending_player_id ON sleeper.player_trending(player_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_player_trending_sport_id ON sleeper.player_trending(sport_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_league_member_league_id ON sleeper.league_member(league_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_league_member_user_id ON sleeper.league_member(user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_waiver_claim_transaction_id ON sleeper.waiver_claim(transaction_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_waiver_claim_player_id ON sleeper.waiver_claim(player_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_player_week_stat_player_id ON sleeper.player_week_stat(player_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_player_week_stat_season_id ON sleeper.player_week_stat(season_id);

-- ============================================================================
-- COMPOSITE INDEXES FOR SYNC OPERATIONS - CRITICAL FOR PERFORMANCE
-- ============================================================================

-- League sync patterns
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_league_status_season ON sleeper.league(status, season_id) WHERE status IN ('in_season', 'drafting');
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_league_last_synced ON sleeper.league(last_synced_at) WHERE last_synced_at IS NOT NULL;

-- Roster sync patterns (MOST CRITICAL - used constantly)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_roster_league_owner ON sleeper.roster(league_id, owner_user_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_roster_league_position ON sleeper.roster(league_id, roster_position);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_roster_last_synced ON sleeper.roster(league_id, last_synced_at);

-- Player roster sync patterns
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_roster_player_league_status ON sleeper.roster_player(league_id, status) WHERE status = 'active';
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_roster_player_league_player ON sleeper.roster_player(league_id, player_id);

-- Transaction sync patterns
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transaction_league_week_type ON sleeper.transaction(league_id, week, type);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transaction_league_created ON sleeper.transaction(league_id, created_at DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transaction_status_created ON sleeper.transaction(status, created_at DESC) WHERE status = 'complete';

-- Matchup sync patterns
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_matchup_league_week_season ON sleeper.matchup(league_id, week, season_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_matchup_team_league_roster ON sleeper.matchup_team(league_id, roster_id);

-- Player sync patterns
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_player_team_position ON sleeper.player(team_abbr, position) WHERE status = 'Active';
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_player_last_synced ON sleeper.player(last_synced_at) WHERE last_synced_at IS NOT NULL;

-- ============================================================================
-- SEARCH AND QUERY OPTIMIZATION INDEXES
-- ============================================================================

-- User search indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_username_lower ON sleeper.user(LOWER(username)) WHERE username IS NOT NULL;
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_display_name_gin ON sleeper.user USING GIN(to_tsvector('english', display_name));

-- Player search indexes (CRITICAL for player lookups)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_player_search_name_gin ON sleeper.player USING GIN(to_tsvector('english', search_full_name));
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_player_full_name_trgm ON sleeper.player USING GIN(full_name gin_trgm_ops);

-- League search
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_league_name_gin ON sleeper.league USING GIN(to_tsvector('english', name));

-- ============================================================================
-- TIME-SERIES AND ANALYTICAL INDEXES
-- ============================================================================

-- BRIN indexes for time-series data (space efficient for large datasets)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transaction_created_brin ON sleeper.transaction USING BRIN(created_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sync_log_started_brin ON sleeper.data_sync_log USING BRIN(started_at);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_matchup_created_brin ON sleeper.matchup USING BRIN(created_at);

-- Analytics indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_roster_points_analysis ON sleeper.roster(league_id, fantasy_points_for DESC);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_matchup_week_analysis ON sleeper.matchup_team(matchup_id, points DESC);

-- ============================================================================
-- PARTIAL INDEXES FOR ACTIVE/CURRENT DATA
-- ============================================================================

-- Active leagues only
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_league_active_status ON sleeper.league(league_id, season_id) WHERE status = 'in_season';

-- Recent sync operations only (index all, filter in queries)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sync_log_recent ON sleeper.data_sync_log(entity_id, sync_type, started_at DESC);

-- Pending sync queue items only
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sync_queue_pending ON sleeper.sync_queue(priority, scheduled_at) 
    WHERE status = 'pending';

-- Active roster players only
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_roster_player_active ON sleeper.roster_player(league_id, roster_id, player_id) 
    WHERE status = 'active';

-- Current season data only
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_season_current ON sleeper.season(sport_id, year) WHERE is_current = TRUE;

-- Active transactions only
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transaction_complete ON sleeper.transaction(league_id, week, created_at DESC) 
    WHERE status = 'complete';

-- ============================================================================
-- JSONB INDEXES FOR METADATA QUERIES
-- ============================================================================

-- Player metadata indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_player_metadata_gin ON sleeper.player USING GIN(metadata);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_player_external_ids_gin ON sleeper.player USING GIN(external_ids);

-- League metadata indexes  
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_league_metadata_gin ON sleeper.league USING GIN(metadata);

-- Transaction metadata indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_transaction_metadata_gin ON sleeper.transaction USING GIN(metadata);

-- ============================================================================
-- COVERING INDEXES (Include columns to avoid table lookups)
-- ============================================================================

-- Roster details covering index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_roster_league_covering ON sleeper.roster(league_id) 
    INCLUDE (roster_id, owner_user_id, wins, losses, fantasy_points_for);

-- Player basic info covering index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_player_position_covering ON sleeper.player(position) 
    INCLUDE (full_name, team_abbr, status);

-- ============================================================================
-- UNIQUE CONSTRAINT INDEXES (Handle conflicts efficiently)
-- ============================================================================

-- Ensure unique constraints have optimal indexes
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_roster_league_position_unique 
    ON sleeper.roster(league_id, roster_position);

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_matchup_unique 
    ON sleeper.matchup(league_id, week, season_id, matchup_number);

CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_transaction_player_unique 
    ON sleeper.roster_player(league_id, roster_id, player_id);

-- ============================================================================
-- COMMENTS FOR MAINTENANCE
-- ============================================================================

COMMENT ON INDEX idx_roster_league_owner IS 'Critical for roster sync operations - queries rosters by league and owner';
COMMENT ON INDEX idx_transaction_league_week_type IS 'Optimizes transaction history queries by league/week/type';
COMMENT ON INDEX idx_matchup_league_week_season IS 'Primary index for matchup data retrieval';
COMMENT ON INDEX idx_player_search_name_gin IS 'Full-text search index for player names';
COMMENT ON INDEX idx_roster_player_active IS 'Partial index for active roster compositions only';