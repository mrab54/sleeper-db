-- ============================================================================
-- Table Partitioning Setup
-- ============================================================================

\c sleeper_db
SET search_path TO sleeper, public;

-- ============================================================================
-- Partition player_stats by season
-- ============================================================================

-- Drop existing table if needed (be careful in production!)
-- DROP TABLE IF EXISTS player_stats CASCADE;

-- Create partitioned player_stats table
CREATE TABLE IF NOT EXISTS player_stats_partitioned (
    id BIGSERIAL,
    player_id VARCHAR(50) NOT NULL,
    season VARCHAR(4) NOT NULL,
    week INTEGER NOT NULL,
    stats JSONB DEFAULT '{}',
    points DECIMAL(6,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id, season)
) PARTITION BY LIST (season);

-- Create partitions for recent seasons
CREATE TABLE player_stats_2023 PARTITION OF player_stats_partitioned FOR VALUES IN ('2023');
CREATE TABLE player_stats_2024 PARTITION OF player_stats_partitioned FOR VALUES IN ('2024');
CREATE TABLE player_stats_2025 PARTITION OF player_stats_partitioned FOR VALUES IN ('2025');

-- Create indexes on partitions
CREATE INDEX idx_player_stats_2023_player ON player_stats_2023(player_id);
CREATE INDEX idx_player_stats_2023_week ON player_stats_2023(week);
CREATE INDEX idx_player_stats_2023_points ON player_stats_2023(points DESC);

CREATE INDEX idx_player_stats_2024_player ON player_stats_2024(player_id);
CREATE INDEX idx_player_stats_2024_week ON player_stats_2024(week);
CREATE INDEX idx_player_stats_2024_points ON player_stats_2024(points DESC);

CREATE INDEX idx_player_stats_2025_player ON player_stats_2025(player_id);
CREATE INDEX idx_player_stats_2025_week ON player_stats_2025(week);
CREATE INDEX idx_player_stats_2025_points ON player_stats_2025(points DESC);

-- ============================================================================
-- Partition matchup_players by league and week
-- ============================================================================

-- Create partitioned matchup_players table
CREATE TABLE IF NOT EXISTS matchup_players_partitioned (
    id BIGSERIAL,
    matchup_id BIGINT NOT NULL,
    player_id VARCHAR(50) NOT NULL,
    points DECIMAL(6,2),
    is_starter BOOLEAN DEFAULT FALSE,
    slot_position VARCHAR(10),
    stats JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    week INTEGER NOT NULL,  -- Denormalized for partitioning
    PRIMARY KEY (id, week)
) PARTITION BY RANGE (week);

-- Create partitions for weeks (assuming 18 week season)
CREATE TABLE matchup_players_weeks_1_6 PARTITION OF matchup_players_partitioned 
    FOR VALUES FROM (1) TO (7);
CREATE TABLE matchup_players_weeks_7_12 PARTITION OF matchup_players_partitioned 
    FOR VALUES FROM (7) TO (13);
CREATE TABLE matchup_players_weeks_13_18 PARTITION OF matchup_players_partitioned 
    FOR VALUES FROM (13) TO (19);
CREATE TABLE matchup_players_playoffs PARTITION OF matchup_players_partitioned 
    FOR VALUES FROM (19) TO (23);

-- Create indexes on partitions
CREATE INDEX idx_mp_w1_6_matchup ON matchup_players_weeks_1_6(matchup_id);
CREATE INDEX idx_mp_w1_6_player ON matchup_players_weeks_1_6(player_id);

CREATE INDEX idx_mp_w7_12_matchup ON matchup_players_weeks_7_12(matchup_id);
CREATE INDEX idx_mp_w7_12_player ON matchup_players_weeks_7_12(player_id);

CREATE INDEX idx_mp_w13_18_matchup ON matchup_players_weeks_13_18(matchup_id);
CREATE INDEX idx_mp_w13_18_player ON matchup_players_weeks_13_18(player_id);

CREATE INDEX idx_mp_playoffs_matchup ON matchup_players_playoffs(matchup_id);
CREATE INDEX idx_mp_playoffs_player ON matchup_players_playoffs(player_id);

-- ============================================================================
-- Partition sync_log by month (already in schema, enhancing)
-- ============================================================================

-- Create additional partitions for future months
CREATE TABLE IF NOT EXISTS sync_log_y2025m02 PARTITION OF sync_log
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE IF NOT EXISTS sync_log_y2025m03 PARTITION OF sync_log
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE IF NOT EXISTS sync_log_y2025m04 PARTITION OF sync_log
    FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE IF NOT EXISTS sync_log_y2025m05 PARTITION OF sync_log
    FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE IF NOT EXISTS sync_log_y2025m06 PARTITION OF sync_log
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE IF NOT EXISTS sync_log_y2025m07 PARTITION OF sync_log
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE IF NOT EXISTS sync_log_y2025m08 PARTITION OF sync_log
    FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE IF NOT EXISTS sync_log_y2025m09 PARTITION OF sync_log
    FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE IF NOT EXISTS sync_log_y2025m10 PARTITION OF sync_log
    FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE IF NOT EXISTS sync_log_y2025m11 PARTITION OF sync_log
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE IF NOT EXISTS sync_log_y2025m12 PARTITION OF sync_log
    FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');

-- ============================================================================
-- Partition transactions by league and created date
-- ============================================================================

CREATE TABLE IF NOT EXISTS transactions_partitioned (
    transaction_id VARCHAR(255),
    league_id VARCHAR(255) NOT NULL,
    type transaction_type NOT NULL,
    status transaction_status NOT NULL,
    week INTEGER,
    transaction_created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    creator_user_id VARCHAR(50),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (transaction_id, transaction_created_at)
) PARTITION BY RANGE (transaction_created_at);

-- Create yearly partitions
CREATE TABLE transactions_2023 PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE transactions_2024 PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE transactions_2025 PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

-- Create indexes on partitions
CREATE INDEX idx_trans_2023_league ON transactions_2023(league_id);
CREATE INDEX idx_trans_2023_type ON transactions_2023(type);
CREATE INDEX idx_trans_2023_week ON transactions_2023(week);

CREATE INDEX idx_trans_2024_league ON transactions_2024(league_id);
CREATE INDEX idx_trans_2024_type ON transactions_2024(type);
CREATE INDEX idx_trans_2024_week ON transactions_2024(week);

CREATE INDEX idx_trans_2025_league ON transactions_2025(league_id);
CREATE INDEX idx_trans_2025_type ON transactions_2025(type);
CREATE INDEX idx_trans_2025_week ON transactions_2025(week);

-- ============================================================================
-- Automated partition management function
-- ============================================================================

CREATE OR REPLACE FUNCTION create_monthly_partition(
    p_table_name TEXT,
    p_date DATE
) RETURNS VOID AS $$
DECLARE
    v_partition_name TEXT;
    v_start_date DATE;
    v_end_date DATE;
BEGIN
    -- Generate partition name
    v_partition_name := p_table_name || '_y' || 
                       TO_CHAR(p_date, 'YYYY') || 'm' || 
                       TO_CHAR(p_date, 'MM');
    
    -- Calculate date range
    v_start_date := DATE_TRUNC('month', p_date);
    v_end_date := v_start_date + INTERVAL '1 month';
    
    -- Check if partition exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_class 
        WHERE relname = v_partition_name
    ) THEN
        -- Create partition
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
            v_partition_name, p_table_name, v_start_date, v_end_date
        );
        
        RAISE NOTICE 'Created partition % for % to %', 
                     v_partition_name, v_start_date, v_end_date;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to create partitions for next N months
CREATE OR REPLACE FUNCTION ensure_future_partitions(
    p_table_name TEXT,
    p_months_ahead INTEGER DEFAULT 3
) RETURNS VOID AS $$
DECLARE
    v_date DATE;
BEGIN
    FOR i IN 0..p_months_ahead LOOP
        v_date := CURRENT_DATE + (i || ' months')::INTERVAL;
        PERFORM create_monthly_partition(p_table_name, v_date);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Schedule partition creation (would need pg_cron extension or external scheduler)
-- CREATE EXTENSION IF NOT EXISTS pg_cron;
-- SELECT cron.schedule('create-partitions', '0 0 1 * *', 
--     $$SELECT ensure_future_partitions('sync_log', 3)$$);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA sleeper TO sleeper_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA sleeper TO sleeper_user;