-- Sleeper Fantasy Football Database Constraints - FIXED
-- PostgreSQL 17
--
-- This script adds check constraints and validation triggers for data integrity
-- CRITICAL FIXES: Removed dangerous constraints and improved validation logic

-- Set search path to our schema
SET search_path TO sleeper, public;

-- ============================================================================
-- CHECK CONSTRAINTS - ENHANCED
-- ============================================================================

-- Roster constraints - enhanced with more comprehensive checks
ALTER TABLE sleeper.roster 
    ADD CONSTRAINT chk_roster_wins_losses CHECK (wins >= 0 AND losses >= 0 AND ties >= 0),
    ADD CONSTRAINT chk_roster_fantasy_points CHECK (fantasy_points_for >= 0 AND fantasy_points_against >= 0),
    ADD CONSTRAINT chk_roster_moves CHECK (total_moves >= 0),
    ADD CONSTRAINT chk_roster_waiver_budget CHECK (waiver_budget_used >= 0),
    ADD CONSTRAINT chk_roster_position CHECK (roster_position > 0);

-- Matchup teams constraints - enhanced
ALTER TABLE sleeper.matchup_team
    ADD CONSTRAINT chk_matchup_team_points CHECK (points >= 0),
    ADD CONSTRAINT chk_matchup_custom_points CHECK (custom_points IS NULL OR custom_points >= 0);

-- Draft picks constraints - enhanced
ALTER TABLE sleeper.draft_pick
    ADD CONSTRAINT chk_draft_pick_rounds CHECK (round > 0 AND pick_in_round > 0 AND overall_pick > 0),
    ADD CONSTRAINT chk_draft_pick_slot CHECK (slot > 0),
    ADD CONSTRAINT chk_draft_pick_auction CHECK (auction_amount IS NULL OR auction_amount >= 0);

-- Draft constraints
ALTER TABLE sleeper.draft
    ADD CONSTRAINT chk_draft_rounds CHECK (rounds > 0 AND picks_per_round > 0),
    ADD CONSTRAINT chk_draft_timers CHECK (
        pick_timer IS NULL OR pick_timer > 0
        AND nomination_timer IS NULL OR nomination_timer > 0
    );

-- Transaction draft picks constraints
ALTER TABLE sleeper.transaction_draft_pick
    ADD CONSTRAINT chk_transaction_pick_round CHECK (round > 0),
    ADD CONSTRAINT chk_transaction_pick_season CHECK (season ~ '^\d{4}$');

-- Traded draft picks constraints  
ALTER TABLE sleeper.traded_draft_pick
    ADD CONSTRAINT chk_traded_pick_round CHECK (round > 0),
    ADD CONSTRAINT chk_traded_pick_season CHECK (season ~ '^\d{4}$');

-- Player constraints - enhanced
ALTER TABLE sleeper.player
    ADD CONSTRAINT chk_player_years_exp CHECK (years_exp IS NULL OR years_exp >= 0),
    ADD CONSTRAINT chk_player_height_weight CHECK (
        (height IS NULL OR height BETWEEN 60 AND 84)  -- 5'0" to 7'0"
        AND (weight IS NULL OR weight BETWEEN 150 AND 400)  -- reasonable NFL weight range
    ),
    ADD CONSTRAINT chk_player_jersey CHECK (jersey_number IS NULL OR jersey_number BETWEEN 0 AND 99),
    ADD CONSTRAINT chk_player_age CHECK (age IS NULL OR age BETWEEN 18 AND 50);

-- League constraints - enhanced
ALTER TABLE sleeper.league
    ADD CONSTRAINT chk_league_total_rosters CHECK (total_rosters BETWEEN 2 AND 32),
    ADD CONSTRAINT chk_league_status CHECK (status IN ('pre_draft', 'drafting', 'in_season', 'complete')),
    ADD CONSTRAINT chk_league_season_type CHECK (season_type IS NULL OR season_type IN ('regular', 'post', 'off'));

-- League settings constraints - comprehensive
ALTER TABLE sleeper.league_setting
    ADD CONSTRAINT chk_league_setting_playoff_teams CHECK (playoff_teams IS NULL OR playoff_teams BETWEEN 2 AND 16),
    ADD CONSTRAINT chk_league_setting_waiver_budget CHECK (waiver_budget IS NULL OR waiver_budget >= 0),
    ADD CONSTRAINT chk_league_setting_trade_deadline CHECK (
        trade_deadline IS NULL OR trade_deadline BETWEEN 1 AND 18
    ),
    ADD CONSTRAINT chk_league_setting_waiver_day CHECK (
        waiver_day_of_week IS NULL OR waiver_day_of_week BETWEEN 0 AND 6
    ),
    ADD CONSTRAINT chk_league_setting_slots CHECK (
        (reserve_slots IS NULL OR reserve_slots >= 0)
        AND (taxi_slots IS NULL OR taxi_slots >= 0)
        AND (max_keepers IS NULL OR max_keepers >= 0)
    ),
    ADD CONSTRAINT chk_league_setting_rounds CHECK (draft_rounds IS NULL OR draft_rounds > 0);

-- Season constraints
ALTER TABLE sleeper.season
    ADD CONSTRAINT chk_season_year CHECK (year ~ '^\d{4}$' AND year::INTEGER BETWEEN 1990 AND 2050),
    ADD CONSTRAINT chk_season_type CHECK (season_type IN ('regular', 'post', 'off')),
    ADD CONSTRAINT chk_season_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date);

-- Sport state constraints
ALTER TABLE sleeper.sport_state
    ADD CONSTRAINT chk_sport_state_week CHECK (current_week > 0),
    ADD CONSTRAINT chk_sport_state_season_format CHECK (
        season ~ '^\d{4}$' 
        AND (league_season IS NULL OR league_season ~ '^\d{4}$')
        AND (league_create_season IS NULL OR league_create_season ~ '^\d{4}$')
        AND (previous_season IS NULL OR previous_season ~ '^\d{4}$')
    );

-- Sync config constraints - enhanced
ALTER TABLE sleeper.sync_config
    ADD CONSTRAINT chk_sync_config_frequency CHECK (sync_frequency_seconds >= 30),  -- Reduced minimum
    ADD CONSTRAINT chk_sync_config_priority CHECK (priority BETWEEN 1 AND 10),
    ADD CONSTRAINT chk_sync_config_retries CHECK (max_retries BETWEEN 0 AND 10);

-- Sync queue constraints
ALTER TABLE sleeper.sync_queue
    ADD CONSTRAINT chk_sync_queue_priority CHECK (priority BETWEEN 1 AND 10),
    ADD CONSTRAINT chk_sync_queue_attempts CHECK (attempts >= 0),
    ADD CONSTRAINT chk_sync_queue_status CHECK (status IN ('pending', 'in_progress', 'completed', 'failed'));

-- Transaction constraints
ALTER TABLE sleeper.transaction
    ADD CONSTRAINT chk_transaction_type CHECK (type IN ('trade', 'waiver', 'free_agent', 'commissioner')),
    ADD CONSTRAINT chk_transaction_status CHECK (status IN ('complete', 'pending', 'failed')),
    ADD CONSTRAINT chk_transaction_week CHECK (week > 0);

-- Waiver claim constraints
ALTER TABLE sleeper.waiver_claim
    ADD CONSTRAINT chk_waiver_claim_bid CHECK (bid_amount IS NULL OR bid_amount >= 0),
    ADD CONSTRAINT chk_waiver_claim_priority CHECK (priority IS NULL OR priority > 0),
    ADD CONSTRAINT chk_waiver_claim_status CHECK (
        status IS NULL OR status IN ('pending', 'successful', 'failed', 'outbid')
    );

-- ============================================================================
-- VALIDATION TRIGGERS - ENHANCED AND FIXED
-- ============================================================================

-- CRITICAL: Fixed roster player validation to handle league context properly
CREATE OR REPLACE FUNCTION sleeper.validate_roster_players()
RETURNS TRIGGER AS $$
BEGIN
    -- Only validate if status is active
    IF NEW.status = 'active' THEN
        -- Check if player is already on another ACTIVE roster in same league
        IF EXISTS (
            SELECT 1 
            FROM sleeper.roster_player rp
            WHERE rp.player_id = NEW.player_id
            AND rp.league_id = NEW.league_id
            AND rp.roster_id != NEW.roster_id
            AND rp.status = 'active'
            AND rp.roster_player_id != COALESCE(NEW.roster_player_id, -1)
        ) THEN
            RAISE EXCEPTION 'Player % is already on another active roster in league %', 
                NEW.player_id, NEW.league_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_roster_players
BEFORE INSERT OR UPDATE ON sleeper.roster_player
FOR EACH ROW EXECUTE FUNCTION sleeper.validate_roster_players();

-- Enhanced matchup team validation
CREATE OR REPLACE FUNCTION sleeper.validate_matchup_teams()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if roster already exists in this matchup
    IF EXISTS (
        SELECT 1
        FROM sleeper.matchup_team mt
        WHERE mt.matchup_id = NEW.matchup_id
        AND mt.roster_id = NEW.roster_id
        AND mt.matchup_team_id != COALESCE(NEW.matchup_team_id, -1)
    ) THEN
        RAISE EXCEPTION 'Roster % already exists in matchup %', 
            NEW.roster_id, NEW.matchup_id;
    END IF;
    
    -- Validate that roster belongs to the same league as matchup
    IF NOT EXISTS (
        SELECT 1
        FROM sleeper.matchup m
        JOIN sleeper.roster r ON m.league_id = r.league_id
        WHERE m.matchup_id = NEW.matchup_id
        AND r.league_id = NEW.league_id
        AND r.roster_id = NEW.roster_id
    ) THEN
        RAISE EXCEPTION 'Roster % does not belong to league % for matchup %', 
            NEW.roster_id, NEW.league_id, NEW.matchup_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_matchup_teams
BEFORE INSERT OR UPDATE ON sleeper.matchup_team
FOR EACH ROW EXECUTE FUNCTION sleeper.validate_matchup_teams();

-- Enhanced transaction date validation
CREATE OR REPLACE FUNCTION sleeper.validate_transaction_dates()
RETURNS TRIGGER AS $$
BEGIN
    -- Validate processed_at vs created_at
    IF NEW.processed_at IS NOT NULL AND NEW.processed_at < NEW.created_at THEN
        RAISE EXCEPTION 'Transaction processed_at (%) cannot be before created_at (%)', 
            NEW.processed_at, NEW.created_at;
    END IF;
    
    -- Validate status_updated_at vs created_at  
    IF NEW.status_updated_at IS NOT NULL AND NEW.status_updated_at < NEW.created_at THEN
        RAISE EXCEPTION 'Transaction status_updated_at (%) cannot be before created_at (%)', 
            NEW.status_updated_at, NEW.created_at;
    END IF;
    
    -- Auto-set processed_at when status changes to complete
    IF NEW.status = 'complete' AND OLD.status != 'complete' AND NEW.processed_at IS NULL THEN
        NEW.processed_at := NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_transaction_dates
BEFORE INSERT OR UPDATE ON sleeper.transaction
FOR EACH ROW EXECUTE FUNCTION sleeper.validate_transaction_dates();

-- Enhanced sync log validation
CREATE OR REPLACE FUNCTION sleeper.validate_sync_log_dates()
RETURNS TRIGGER AS $$
BEGIN
    -- Validate completed_at vs started_at
    IF NEW.completed_at IS NOT NULL AND NEW.completed_at < NEW.started_at THEN
        RAISE EXCEPTION 'Sync completed_at (%) cannot be before started_at (%)', 
            NEW.completed_at, NEW.started_at;
    END IF;
    
    -- Auto-set completed_at when status changes to completed or failed
    IF NEW.status IN ('completed', 'failed') AND NEW.completed_at IS NULL THEN
        NEW.completed_at := NOW();
    END IF;
    
    -- Validate records_processed for completed syncs
    IF NEW.status = 'completed' AND NEW.records_processed < 0 THEN
        NEW.records_processed := 0;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_sync_log_dates
BEFORE INSERT OR UPDATE ON sleeper.data_sync_log
FOR EACH ROW EXECUTE FUNCTION sleeper.validate_sync_log_dates();

-- Enhanced league season validation
CREATE OR REPLACE FUNCTION sleeper.validate_league_season()
RETURNS TRIGGER AS $$
DECLARE
    v_sport_id VARCHAR(10);
    v_season_year VARCHAR(4);
BEGIN
    -- Get sport_id and year from season
    SELECT sport_id, year INTO v_sport_id, v_season_year
    FROM sleeper.season
    WHERE season_id = NEW.season_id;
    
    -- Check if sport_id matches
    IF v_sport_id != NEW.sport_id THEN
        RAISE EXCEPTION 'League sport_id (%) does not match season sport_id (%) for season year %', 
            NEW.sport_id, v_sport_id, v_season_year;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_league_season
BEFORE INSERT OR UPDATE ON sleeper.league
FOR EACH ROW EXECUTE FUNCTION sleeper.validate_league_season();

-- Enhanced draft pick validation
CREATE OR REPLACE FUNCTION sleeper.validate_draft_picks()
RETURNS TRIGGER AS $$
DECLARE
    v_draft_picks_per_round INTEGER;
    v_draft_rounds INTEGER;
    v_expected_overall INTEGER;
BEGIN
    -- Get draft configuration
    SELECT picks_per_round, rounds INTO v_draft_picks_per_round, v_draft_rounds
    FROM sleeper.draft
    WHERE draft_id = NEW.draft_id;
    
    -- Calculate expected overall pick number
    v_expected_overall := (NEW.round - 1) * v_draft_picks_per_round + NEW.pick_in_round;
    
    -- Validate overall pick calculation
    IF NEW.overall_pick != v_expected_overall THEN
        RAISE EXCEPTION 'Overall pick % does not match calculated value % (round %, pick %)', 
            NEW.overall_pick, v_expected_overall, NEW.round, NEW.pick_in_round;
    END IF;
    
    -- Check for duplicate overall picks
    IF EXISTS (
        SELECT 1
        FROM sleeper.draft_pick dp
        WHERE dp.draft_id = NEW.draft_id
        AND dp.overall_pick = NEW.overall_pick
        AND dp.pick_id != COALESCE(NEW.pick_id, -1)
    ) THEN
        RAISE EXCEPTION 'Overall pick % already exists in draft %', 
            NEW.overall_pick, NEW.draft_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_draft_picks
BEFORE INSERT OR UPDATE ON sleeper.draft_pick
FOR EACH ROW EXECUTE FUNCTION sleeper.validate_draft_picks();

-- ============================================================================
-- ADDITIONAL INTEGRITY FUNCTIONS - ENHANCED
-- ============================================================================

-- Enhanced username normalization
CREATE OR REPLACE FUNCTION sleeper.normalize_username()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.username IS NOT NULL THEN
        -- Normalize to lowercase and trim whitespace
        NEW.username := LOWER(TRIM(NEW.username));
        
        -- Validate username format (alphanumeric, underscore, hyphen only)
        IF NEW.username !~ '^[a-z0-9_-]+$' THEN
            RAISE EXCEPTION 'Username can only contain lowercase letters, numbers, underscores, and hyphens';
        END IF;
        
        -- Validate length
        IF LENGTH(NEW.username) < 3 OR LENGTH(NEW.username) > 50 THEN
            RAISE EXCEPTION 'Username must be between 3 and 50 characters';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_normalize_username
BEFORE INSERT OR UPDATE ON sleeper.user
FOR EACH ROW EXECUTE FUNCTION sleeper.normalize_username();

-- Enhanced player search name generation
CREATE OR REPLACE FUNCTION sleeper.update_player_search_name()
RETURNS TRIGGER AS $$
BEGIN
    -- Generate search_full_name with better normalization
    IF NEW.full_name IS NOT NULL THEN
        NEW.search_full_name := LOWER(TRIM(NEW.full_name));
    ELSIF NEW.first_name IS NOT NULL OR NEW.last_name IS NOT NULL THEN
        NEW.search_full_name := LOWER(TRIM(COALESCE(NEW.first_name, '') || ' ' || COALESCE(NEW.last_name, '')));
    END IF;
    
    -- Remove extra whitespace
    NEW.search_full_name := REGEXP_REPLACE(NEW.search_full_name, '\s+', ' ', 'g');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_player_search_name
BEFORE INSERT OR UPDATE ON sleeper.player
FOR EACH ROW EXECUTE FUNCTION sleeper.update_player_search_name();

-- ============================================================================
-- SYNC-SPECIFIC VALIDATION FUNCTIONS
-- ============================================================================

-- Validate sync queue scheduling
CREATE OR REPLACE FUNCTION sleeper.validate_sync_queue()
RETURNS TRIGGER AS $$
BEGIN
    -- Don't allow scheduling in the past (with 5 minute buffer)
    IF NEW.scheduled_at < NOW() - INTERVAL '5 minutes' THEN
        NEW.scheduled_at := NOW();
    END IF;
    
    -- Reset attempts when rescheduling
    IF TG_OP = 'UPDATE' AND NEW.scheduled_at != OLD.scheduled_at THEN
        NEW.attempts := 0;
        NEW.error_message := NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_sync_queue
BEFORE INSERT OR UPDATE ON sleeper.sync_queue
FOR EACH ROW EXECUTE FUNCTION sleeper.validate_sync_queue();

-- ============================================================================
-- PERFORMANCE AND MAINTENANCE FUNCTIONS
-- ============================================================================

-- Function to clean up old sync logs
CREATE OR REPLACE FUNCTION sleeper.cleanup_old_sync_logs(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM sleeper.data_sync_log
    WHERE started_at < NOW() - (days_to_keep || ' days')::INTERVAL
    AND status IN ('completed', 'failed');
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to validate data consistency across related tables
CREATE OR REPLACE FUNCTION sleeper.validate_data_consistency()
RETURNS TABLE(issue_type TEXT, issue_description TEXT, affected_count BIGINT) AS $$
BEGIN
    -- Check for rosters without owners in active leagues
    RETURN QUERY
    SELECT 
        'orphaned_rosters'::TEXT as issue_type,
        'Rosters without owners in active leagues'::TEXT as issue_description,
        COUNT(*) as affected_count
    FROM sleeper.roster r
    JOIN sleeper.league l ON r.league_id = l.league_id
    WHERE r.owner_user_id IS NULL
    AND l.status = 'in_season';
    
    -- Check for players on multiple active rosters in same league
    RETURN QUERY
    SELECT 
        'duplicate_roster_players'::TEXT as issue_type,
        'Players on multiple active rosters in same league'::TEXT as issue_description,
        COUNT(*) as affected_count
    FROM (
        SELECT rp.player_id, rp.league_id
        FROM sleeper.roster_player rp
        WHERE rp.status = 'active'
        GROUP BY rp.player_id, rp.league_id
        HAVING COUNT(*) > 1
    ) duplicates;
    
    -- Check for matchups with incorrect team counts
    RETURN QUERY
    SELECT 
        'invalid_matchups'::TEXT as issue_type,
        'Matchups without exactly 2 teams'::TEXT as issue_description,
        COUNT(*) as affected_count
    FROM (
        SELECT m.matchup_id
        FROM sleeper.matchup m
        LEFT JOIN sleeper.matchup_team mt ON m.matchup_id = mt.matchup_id
        GROUP BY m.matchup_id
        HAVING COUNT(mt.matchup_team_id) != 2
    ) invalid_matchups;
    
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENTS FOR MAINTENANCE
-- ============================================================================

COMMENT ON FUNCTION sleeper.validate_roster_players IS 'Prevents players from being on multiple active rosters in same league';
COMMENT ON FUNCTION sleeper.validate_matchup_teams IS 'Ensures matchup integrity and league consistency';
COMMENT ON FUNCTION sleeper.cleanup_old_sync_logs IS 'Maintenance function to clean up old sync log entries';
COMMENT ON FUNCTION sleeper.validate_data_consistency IS 'Returns data consistency issues for monitoring';