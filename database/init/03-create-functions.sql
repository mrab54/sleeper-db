-- ============================================================================
-- Database Functions
-- ============================================================================

\c sleeper_db
SET search_path TO sleeper, public;

-- ============================================================================
-- Utility Functions
-- ============================================================================

-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Generate short ID function (for readable IDs)
CREATE OR REPLACE FUNCTION generate_short_id(prefix TEXT DEFAULT '')
RETURNS TEXT AS $$
BEGIN
    RETURN prefix || substr(md5(random()::text || clock_timestamp()::text), 1, 8);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Upsert Functions
-- ============================================================================

-- Upsert user
CREATE OR REPLACE FUNCTION upsert_user(
    p_user_id VARCHAR,
    p_username VARCHAR,
    p_display_name VARCHAR,
    p_avatar VARCHAR DEFAULT NULL,
    p_is_bot BOOLEAN DEFAULT FALSE,
    p_metadata JSONB DEFAULT '{}'
) RETURNS users AS $$
DECLARE
    v_user users;
BEGIN
    INSERT INTO users (user_id, username, display_name, avatar, is_bot, metadata)
    VALUES (p_user_id, p_username, p_display_name, p_avatar, p_is_bot, p_metadata)
    ON CONFLICT (user_id) DO UPDATE SET
        username = EXCLUDED.username,
        display_name = EXCLUDED.display_name,
        avatar = EXCLUDED.avatar,
        is_bot = EXCLUDED.is_bot,
        metadata = users.metadata || EXCLUDED.metadata,
        updated_at = CURRENT_TIMESTAMP
    RETURNING * INTO v_user;
    
    RETURN v_user;
END;
$$ LANGUAGE plpgsql;

-- Upsert league
CREATE OR REPLACE FUNCTION upsert_league(
    p_league_id VARCHAR,
    p_name VARCHAR,
    p_season VARCHAR,
    p_season_type VARCHAR,
    p_status league_status,
    p_total_rosters INTEGER,
    p_draft_id VARCHAR DEFAULT NULL,
    p_previous_league_id VARCHAR DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'
) RETURNS leagues AS $$
DECLARE
    v_league leagues;
BEGIN
    INSERT INTO leagues (
        league_id, name, season, season_type, status, 
        total_rosters, draft_id, previous_league_id, metadata
    )
    VALUES (
        p_league_id, p_name, p_season, p_season_type, p_status,
        p_total_rosters, p_draft_id, p_previous_league_id, p_metadata
    )
    ON CONFLICT (league_id) DO UPDATE SET
        name = EXCLUDED.name,
        season = EXCLUDED.season,
        season_type = EXCLUDED.season_type,
        status = EXCLUDED.status,
        total_rosters = EXCLUDED.total_rosters,
        draft_id = EXCLUDED.draft_id,
        previous_league_id = EXCLUDED.previous_league_id,
        metadata = leagues.metadata || EXCLUDED.metadata,
        updated_at = CURRENT_TIMESTAMP
    RETURNING * INTO v_league;
    
    RETURN v_league;
END;
$$ LANGUAGE plpgsql;

-- Upsert roster
CREATE OR REPLACE FUNCTION upsert_roster(
    p_league_id VARCHAR,
    p_roster_id INTEGER,
    p_owner_id VARCHAR,
    p_is_active BOOLEAN DEFAULT TRUE
) RETURNS rosters AS $$
DECLARE
    v_roster rosters;
BEGIN
    INSERT INTO rosters (league_id, roster_id, owner_id, is_active)
    VALUES (p_league_id, p_roster_id, p_owner_id, p_is_active)
    ON CONFLICT (league_id, roster_id) DO UPDATE SET
        owner_id = EXCLUDED.owner_id,
        is_active = EXCLUDED.is_active,
        updated_at = CURRENT_TIMESTAMP
    RETURNING * INTO v_roster;
    
    RETURN v_roster;
END;
$$ LANGUAGE plpgsql;

-- Upsert player
CREATE OR REPLACE FUNCTION upsert_player(
    p_player_id VARCHAR,
    p_first_name VARCHAR,
    p_last_name VARCHAR,
    p_full_name VARCHAR,
    p_position VARCHAR,
    p_team VARCHAR DEFAULT NULL,
    p_status player_status DEFAULT 'active',
    p_metadata JSONB DEFAULT '{}'
) RETURNS players AS $$
DECLARE
    v_player players;
BEGIN
    INSERT INTO players (
        player_id, first_name, last_name, full_name,
        position, team, status, metadata
    )
    VALUES (
        p_player_id, p_first_name, p_last_name, p_full_name,
        p_position, p_team, p_status, p_metadata
    )
    ON CONFLICT (player_id) DO UPDATE SET
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        full_name = EXCLUDED.full_name,
        position = EXCLUDED.position,
        team = EXCLUDED.team,
        status = EXCLUDED.status,
        metadata = players.metadata || EXCLUDED.metadata,
        updated_at = CURRENT_TIMESTAMP
    RETURNING * INTO v_player;
    
    RETURN v_player;
END;
$$ LANGUAGE plpgsql;

-- Upsert transaction
CREATE OR REPLACE FUNCTION upsert_transaction(
    p_transaction_id VARCHAR,
    p_league_id VARCHAR,
    p_type transaction_type,
    p_status transaction_status,
    p_week INTEGER,
    p_created_at TIMESTAMP WITH TIME ZONE,
    p_creator_user_id VARCHAR DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'
) RETURNS transactions AS $$
DECLARE
    v_transaction transactions;
BEGIN
    INSERT INTO transactions (
        transaction_id, league_id, type, status, week,
        transaction_created_at, creator_user_id, metadata
    )
    VALUES (
        p_transaction_id, p_league_id, p_type, p_status, p_week,
        p_created_at, p_creator_user_id, p_metadata
    )
    ON CONFLICT (transaction_id) DO UPDATE SET
        status = EXCLUDED.status,
        metadata = transactions.metadata || EXCLUDED.metadata,
        updated_at = CURRENT_TIMESTAMP
    RETURNING * INTO v_transaction;
    
    RETURN v_transaction;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Analytics Functions
-- ============================================================================

-- Calculate fantasy points for a player in a week
CREATE OR REPLACE FUNCTION calculate_fantasy_points(
    p_stats JSONB,
    p_scoring_settings JSONB
) RETURNS DECIMAL AS $$
DECLARE
    v_points DECIMAL := 0;
    v_stat_key TEXT;
    v_stat_value DECIMAL;
    v_point_value DECIMAL;
BEGIN
    -- Iterate through each stat and calculate points
    FOR v_stat_key, v_stat_value IN 
        SELECT key, value::DECIMAL 
        FROM jsonb_each_text(p_stats)
        WHERE value ~ '^[0-9]+\.?[0-9]*$'
    LOOP
        -- Get point value for this stat from scoring settings
        v_point_value := COALESCE((p_scoring_settings->v_stat_key)::DECIMAL, 0);
        v_points := v_points + (v_stat_value * v_point_value);
    END LOOP;
    
    RETURN ROUND(v_points, 2);
END;
$$ LANGUAGE plpgsql;

-- Get roster composition for a given week
CREATE OR REPLACE FUNCTION get_roster_composition(
    p_league_id VARCHAR,
    p_roster_id INTEGER,
    p_week INTEGER
) RETURNS TABLE (
    position VARCHAR,
    player_count INTEGER,
    total_points DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.position,
        COUNT(*)::INTEGER as player_count,
        COALESCE(SUM(mp.points), 0) as total_points
    FROM roster_players rp
    JOIN players p ON rp.player_id = p.player_id
    LEFT JOIN matchups m ON m.league_id = rp.league_id 
        AND m.roster_id = rp.roster_id 
        AND m.week = p_week
    LEFT JOIN matchup_players mp ON mp.matchup_id = m.id 
        AND mp.player_id = rp.player_id
    WHERE rp.league_id = p_league_id 
        AND rp.roster_id = p_roster_id
    GROUP BY p.position
    ORDER BY total_points DESC;
END;
$$ LANGUAGE plpgsql;

-- Calculate win probability based on current scores
CREATE OR REPLACE FUNCTION calculate_win_probability(
    p_team_score DECIMAL,
    p_opponent_score DECIMAL,
    p_minutes_remaining INTEGER DEFAULT 0
) RETURNS DECIMAL AS $$
DECLARE
    v_score_diff DECIMAL;
    v_probability DECIMAL;
BEGIN
    -- Simple model based on score differential
    v_score_diff := p_team_score - p_opponent_score;
    
    IF p_minutes_remaining = 0 THEN
        -- Game is over
        RETURN CASE WHEN v_score_diff > 0 THEN 1.0 ELSE 0.0 END;
    END IF;
    
    -- Basic probability model (can be enhanced)
    v_probability := 0.5 + (v_score_diff / 100.0);
    
    -- Adjust for time remaining
    v_probability := v_probability + ((60 - p_minutes_remaining) / 120.0 * SIGN(v_score_diff));
    
    -- Clamp between 0 and 1
    RETURN GREATEST(0.0, LEAST(1.0, v_probability));
END;
$$ LANGUAGE plpgsql;

-- Get season statistics for a roster
CREATE OR REPLACE FUNCTION get_roster_season_stats(
    p_league_id VARCHAR,
    p_roster_id INTEGER
) RETURNS TABLE (
    total_wins INTEGER,
    total_losses INTEGER,
    total_ties INTEGER,
    total_points_for DECIMAL,
    total_points_against DECIMAL,
    avg_points_for DECIMAL,
    avg_points_against DECIMAL,
    win_percentage DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(CASE WHEN points > opponent_points THEN 1 END)::INTEGER as total_wins,
        COUNT(CASE WHEN points < opponent_points THEN 1 END)::INTEGER as total_losses,
        COUNT(CASE WHEN points = opponent_points THEN 1 END)::INTEGER as total_ties,
        SUM(points) as total_points_for,
        SUM(opponent_points) as total_points_against,
        ROUND(AVG(points), 2) as avg_points_for,
        ROUND(AVG(opponent_points), 2) as avg_points_against,
        ROUND(
            COUNT(CASE WHEN points > opponent_points THEN 1 END)::DECIMAL / 
            NULLIF(COUNT(*), 0) * 100, 2
        ) as win_percentage
    FROM matchups
    WHERE league_id = p_league_id 
        AND roster_id = p_roster_id
        AND points IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Calculate strength of schedule
CREATE OR REPLACE FUNCTION calculate_strength_of_schedule(
    p_league_id VARCHAR,
    p_roster_id INTEGER,
    p_through_week INTEGER DEFAULT NULL
) RETURNS DECIMAL AS $$
DECLARE
    v_avg_opponent_win_pct DECIMAL;
BEGIN
    -- Calculate average win percentage of all opponents faced
    SELECT AVG(opponent_win_pct) INTO v_avg_opponent_win_pct
    FROM (
        SELECT 
            m2.roster_id as opponent_id,
            COUNT(CASE WHEN m2.points > m2.opponent_points THEN 1 END)::DECIMAL / 
            NULLIF(COUNT(*), 0) as opponent_win_pct
        FROM matchups m1
        JOIN matchups m2 ON m1.league_id = m2.league_id 
            AND m1.matchup_id = m2.roster_id
            AND m1.week = m2.week
        WHERE m1.league_id = p_league_id 
            AND m1.roster_id = p_roster_id
            AND (p_through_week IS NULL OR m1.week <= p_through_week)
        GROUP BY m2.roster_id
    ) opponent_stats;
    
    RETURN COALESCE(ROUND(v_avg_opponent_win_pct * 100, 2), 50.00);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_strength_of_schedule IS 'Returns strength of schedule as a percentage (0-100)';

-- Grant execute permissions on all functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA sleeper TO sleeper_user;