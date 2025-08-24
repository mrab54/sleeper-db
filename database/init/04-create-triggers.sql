-- ============================================================================
-- Database Triggers
-- ============================================================================

\c sleeper_db
SET search_path TO sleeper, public;

-- ============================================================================
-- Updated_at Triggers
-- ============================================================================

-- Users table
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Leagues table
CREATE TRIGGER update_leagues_updated_at 
    BEFORE UPDATE ON leagues
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- League settings table
CREATE TRIGGER update_league_settings_updated_at 
    BEFORE UPDATE ON league_settings
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- League scoring settings table
CREATE TRIGGER update_league_scoring_settings_updated_at 
    BEFORE UPDATE ON league_scoring_settings
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Rosters table
CREATE TRIGGER update_rosters_updated_at 
    BEFORE UPDATE ON rosters
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Players table
CREATE TRIGGER update_players_updated_at 
    BEFORE UPDATE ON players
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Transactions table
CREATE TRIGGER update_transactions_updated_at 
    BEFORE UPDATE ON transactions
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Drafts table
CREATE TRIGGER update_drafts_updated_at 
    BEFORE UPDATE ON drafts
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Matchups table
CREATE TRIGGER update_matchups_updated_at 
    BEFORE UPDATE ON matchups
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Playoff brackets table
CREATE TRIGGER update_playoff_brackets_updated_at 
    BEFORE UPDATE ON playoff_brackets
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- NFL state table
CREATE TRIGGER update_nfl_state_updated_at 
    BEFORE UPDATE ON nfl_state
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- Audit Triggers
-- ============================================================================

-- Create audit log table
CREATE TABLE IF NOT EXISTS audit_log (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation VARCHAR(10) NOT NULL,
    user_name VARCHAR(100) DEFAULT current_user,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    row_id VARCHAR(255),
    old_data JSONB,
    new_data JSONB
);

CREATE INDEX idx_audit_log_table ON audit_log(table_name);
CREATE INDEX idx_audit_log_operation ON audit_log(operation);
CREATE INDEX idx_audit_log_changed_at ON audit_log(changed_at DESC);
CREATE INDEX idx_audit_log_row_id ON audit_log(row_id);

-- Audit trigger function
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, operation, row_id, old_data)
        VALUES (TG_TABLE_NAME, TG_OP, OLD.id::TEXT, to_jsonb(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, operation, row_id, old_data, new_data)
        VALUES (TG_TABLE_NAME, TG_OP, NEW.id::TEXT, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, operation, row_id, new_data)
        VALUES (TG_TABLE_NAME, TG_OP, NEW.id::TEXT, to_jsonb(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit triggers to important tables
CREATE TRIGGER audit_transactions
    AFTER INSERT OR UPDATE OR DELETE ON transactions
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_rosters
    AFTER INSERT OR UPDATE OR DELETE ON rosters
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_roster_players
    AFTER INSERT OR UPDATE OR DELETE ON roster_players
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- ============================================================================
-- Business Logic Triggers
-- ============================================================================

-- Validate roster size
CREATE OR REPLACE FUNCTION validate_roster_size()
RETURNS TRIGGER AS $$
DECLARE
    v_roster_size INTEGER;
    v_max_roster_size INTEGER;
BEGIN
    -- Get current roster size
    SELECT COUNT(*) INTO v_roster_size
    FROM roster_players
    WHERE league_id = NEW.league_id AND roster_id = NEW.roster_id;
    
    -- Get max roster size from league settings
    SELECT (settings->>'roster_size')::INTEGER INTO v_max_roster_size
    FROM league_settings
    WHERE league_id = NEW.league_id;
    
    -- Default to 16 if not set
    v_max_roster_size := COALESCE(v_max_roster_size, 16);
    
    IF v_roster_size >= v_max_roster_size THEN
        RAISE EXCEPTION 'Roster size limit exceeded. Maximum allowed: %', v_max_roster_size;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_roster_size
    BEFORE INSERT ON roster_players
    FOR EACH ROW EXECUTE FUNCTION validate_roster_size();

-- Prevent duplicate starters in same slot
CREATE OR REPLACE FUNCTION prevent_duplicate_starters()
RETURNS TRIGGER AS $$
DECLARE
    v_existing_starter INTEGER;
BEGIN
    IF NEW.is_starter = TRUE AND NEW.slot_position IS NOT NULL THEN
        SELECT COUNT(*) INTO v_existing_starter
        FROM roster_players
        WHERE league_id = NEW.league_id 
            AND roster_id = NEW.roster_id
            AND slot_position = NEW.slot_position
            AND is_starter = TRUE
            AND player_id != NEW.player_id;
        
        IF v_existing_starter > 0 THEN
            RAISE EXCEPTION 'Slot position % already has a starter', NEW.slot_position;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_duplicate_starters_trigger
    BEFORE INSERT OR UPDATE ON roster_players
    FOR EACH ROW EXECUTE FUNCTION prevent_duplicate_starters();

-- Auto-update matchup points when player points change
CREATE OR REPLACE FUNCTION update_matchup_points()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the matchup total points
    UPDATE matchups
    SET points = (
        SELECT COALESCE(SUM(mp.points), 0)
        FROM matchup_players mp
        WHERE mp.matchup_id = NEW.matchup_id
    )
    WHERE id = NEW.matchup_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_matchup_points_trigger
    AFTER INSERT OR UPDATE OR DELETE ON matchup_players
    FOR EACH ROW EXECUTE FUNCTION update_matchup_points();

-- Validate transaction status changes
CREATE OR REPLACE FUNCTION validate_transaction_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Prevent changing from complete to pending
    IF OLD.status = 'complete' AND NEW.status = 'pending' THEN
        RAISE EXCEPTION 'Cannot change transaction status from complete to pending';
    END IF;
    
    -- Prevent changing from failed to complete
    IF OLD.status = 'failed' AND NEW.status = 'complete' THEN
        RAISE EXCEPTION 'Failed transactions cannot be marked as complete';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_transaction_status_trigger
    BEFORE UPDATE ON transactions
    FOR EACH ROW 
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION validate_transaction_status();

-- Grant permissions
GRANT SELECT, INSERT ON audit_log TO sleeper_user;
GRANT USAGE ON SEQUENCE audit_log_id_seq TO sleeper_user;