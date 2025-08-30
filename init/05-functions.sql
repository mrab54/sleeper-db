-- Sleeper Fantasy Football Database Functions
-- PostgreSQL 17
--
-- This script creates timestamp triggers and essential helper functions for data syncing

-- Set search path to our schema
SET search_path TO sleeper, public;

-- ============================================================================
-- UPDATE TIMESTAMP FUNCTION
-- ============================================================================
-- Automatically updates the updated_at column whenever a row is modified
-- This helps track when data was last synced from the Sleeper API

CREATE OR REPLACE FUNCTION sleeper.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- UPDATE TIMESTAMP TRIGGERS
-- ============================================================================

-- Users
CREATE TRIGGER update_user_updated_at BEFORE UPDATE ON sleeper.user
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Leagues
CREATE TRIGGER update_league_updated_at BEFORE UPDATE ON sleeper.league
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- League Settings
CREATE TRIGGER update_league_setting_updated_at BEFORE UPDATE ON sleeper.league_setting
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- League Scoring Settings
CREATE TRIGGER update_league_scoring_setting_updated_at BEFORE UPDATE ON sleeper.league_scoring_setting
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Players
CREATE TRIGGER update_player_updated_at BEFORE UPDATE ON sleeper.player
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Rosters
CREATE TRIGGER update_roster_updated_at BEFORE UPDATE ON sleeper.roster
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Seasons
CREATE TRIGGER update_season_updated_at BEFORE UPDATE ON sleeper.season
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Sport States
CREATE TRIGGER update_sport_state_updated_at BEFORE UPDATE ON sleeper.sport_state
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- NFL Teams
CREATE TRIGGER update_nfl_team_updated_at BEFORE UPDATE ON sleeper.nfl_team
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Weekly Lineups
CREATE TRIGGER update_weekly_lineup_updated_at BEFORE UPDATE ON sleeper.weekly_lineup
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Matchup Teams
CREATE TRIGGER update_matchup_team_updated_at BEFORE UPDATE ON sleeper.matchup_team
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Matchups
CREATE TRIGGER update_matchup_updated_at BEFORE UPDATE ON sleeper.matchup
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Playoff Matchups
CREATE TRIGGER update_playoff_matchup_updated_at BEFORE UPDATE ON sleeper.playoff_matchup
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Drafts
CREATE TRIGGER update_draft_updated_at BEFORE UPDATE ON sleeper.draft
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Traded Draft Picks
CREATE TRIGGER update_traded_draft_pick_updated_at BEFORE UPDATE ON sleeper.traded_draft_pick
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- League Members
CREATE TRIGGER update_league_member_updated_at BEFORE UPDATE ON sleeper.league_member
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Data Sync Log
CREATE TRIGGER update_data_sync_log_updated_at BEFORE UPDATE ON sleeper.data_sync_log
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Sync Config
CREATE TRIGGER update_sync_config_updated_at BEFORE UPDATE ON sleeper.sync_config
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Waiver Claims
CREATE TRIGGER update_waiver_claim_updated_at BEFORE UPDATE ON sleeper.waiver_claim
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- Player Week Stats
CREATE TRIGGER update_player_week_stat_updated_at BEFORE UPDATE ON sleeper.player_week_stat
    FOR EACH ROW EXECUTE FUNCTION sleeper.update_updated_at_column();

-- ============================================================================
-- HELPER FUNCTIONS FOR DATA SYNCING
-- ============================================================================

-- Get current season for a sport (useful during sync operations)
CREATE OR REPLACE FUNCTION sleeper.get_current_season(p_sport_id VARCHAR)
RETURNS INTEGER AS $$
DECLARE
    v_season_id INTEGER;
BEGIN
    SELECT season_id INTO v_season_id
    FROM sleeper.season
    WHERE sport_id = p_sport_id
    AND is_current = true
    LIMIT 1;
    
    RETURN v_season_id;
END;
$$ LANGUAGE plpgsql;