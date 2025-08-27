-- Sleeper Fantasy Football Database Functions
-- PostgreSQL 17
--
-- This script creates helper functions and triggers

-- Set search path to our schema
SET search_path TO sleeper, public;

-- ============================================================================
-- UPDATE TIMESTAMP FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
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
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Leagues
CREATE TRIGGER update_leagues_updated_at BEFORE UPDATE ON leagues
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- League Settings
CREATE TRIGGER update_league_settings_updated_at BEFORE UPDATE ON league_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- League Scoring Settings
CREATE TRIGGER update_league_scoring_settings_updated_at BEFORE UPDATE ON league_scoring_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Players
CREATE TRIGGER update_players_updated_at BEFORE UPDATE ON players
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Rosters
CREATE TRIGGER update_rosters_updated_at BEFORE UPDATE ON rosters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Seasons
CREATE TRIGGER update_seasons_updated_at BEFORE UPDATE ON seasons
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Sport States
CREATE TRIGGER update_sport_states_updated_at BEFORE UPDATE ON sport_states
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- NFL Teams
CREATE TRIGGER update_nfl_teams_updated_at BEFORE UPDATE ON nfl_teams
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Weekly Lineups
CREATE TRIGGER update_weekly_lineups_updated_at BEFORE UPDATE ON weekly_lineups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Matchup Teams
CREATE TRIGGER update_matchup_teams_updated_at BEFORE UPDATE ON matchup_teams
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Matchups
CREATE TRIGGER update_matchups_updated_at BEFORE UPDATE ON matchups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Playoff Matchups
CREATE TRIGGER update_playoff_matchups_updated_at BEFORE UPDATE ON playoff_matchups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Drafts
CREATE TRIGGER update_drafts_updated_at BEFORE UPDATE ON drafts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Traded Draft Picks
CREATE TRIGGER update_traded_draft_picks_updated_at BEFORE UPDATE ON traded_draft_picks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- League Members
CREATE TRIGGER update_league_members_updated_at BEFORE UPDATE ON league_members
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROSTER RECORD UPDATE FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION update_roster_record(
    p_roster_id INTEGER,
    p_won BOOLEAN,
    p_points_for DECIMAL,
    p_points_against DECIMAL
)
RETURNS VOID AS $$
BEGIN
    UPDATE rosters
    SET 
        wins = wins + CASE WHEN p_won THEN 1 ELSE 0 END,
        losses = losses + CASE WHEN NOT p_won THEN 1 ELSE 0 END,
        fantasy_points_for = fantasy_points_for + p_points_for,
        fantasy_points_against = fantasy_points_against + p_points_against,
        updated_at = NOW()
    WHERE roster_id = p_roster_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- GET CURRENT SEASON FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION get_current_season(p_sport_id VARCHAR)
RETURNS INTEGER AS $$
DECLARE
    v_season_id INTEGER;
BEGIN
    SELECT season_id INTO v_season_id
    FROM seasons
    WHERE sport_id = p_sport_id
    AND is_current = true
    LIMIT 1;
    
    RETURN v_season_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CALCULATE WIN PERCENTAGE FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_win_percentage(
    p_wins INTEGER,
    p_losses INTEGER,
    p_ties INTEGER
)
RETURNS DECIMAL AS $$
BEGIN
    IF (p_wins + p_losses + p_ties) = 0 THEN
        RETURN 0;
    END IF;
    
    RETURN ROUND(
        (p_wins::numeric + (p_ties::numeric * 0.5)) / 
        (p_wins + p_losses + p_ties) * 100, 
        2
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- GET ROSTER RANK FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION get_roster_rank(p_roster_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
    v_rank INTEGER;
BEGIN
    WITH roster_ranks AS (
        SELECT 
            roster_id,
            RANK() OVER (
                PARTITION BY league_id 
                ORDER BY wins DESC, fantasy_points_for DESC
            ) as rank
        FROM rosters
        WHERE league_id = (
            SELECT league_id 
            FROM rosters 
            WHERE roster_id = p_roster_id
        )
    )
    SELECT rank INTO v_rank
    FROM roster_ranks
    WHERE roster_id = p_roster_id;
    
    RETURN v_rank;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SYNC LOG FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION log_sync_start(
    p_sync_type VARCHAR,
    p_entity_id VARCHAR DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_sync_id INTEGER;
BEGIN
    INSERT INTO data_sync_log (sync_type, entity_id, status, started_at)
    VALUES (p_sync_type, p_entity_id, 'started', NOW())
    RETURNING sync_id INTO v_sync_id;
    
    RETURN v_sync_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION log_sync_complete(
    p_sync_id INTEGER,
    p_records_processed INTEGER DEFAULT 0
)
RETURNS VOID AS $$
BEGIN
    UPDATE data_sync_log
    SET 
        status = 'completed',
        completed_at = NOW(),
        records_processed = p_records_processed
    WHERE sync_id = p_sync_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION log_sync_error(
    p_sync_id INTEGER,
    p_error_message TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE data_sync_log
    SET 
        status = 'failed',
        completed_at = NOW(),
        error_message = p_error_message
    WHERE sync_id = p_sync_id;
END;
$$ LANGUAGE plpgsql;