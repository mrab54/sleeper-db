-- Additional tables for sync service

-- Sync state tracking
CREATE TABLE IF NOT EXISTS sleeper.sync_state (
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(255) NOT NULL,
    last_synced_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    sync_version INT DEFAULT 1,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (entity_type, entity_id)
);

-- Sport state (current season/week info)
CREATE TABLE IF NOT EXISTS sleeper.sport_state (
    sport VARCHAR(10) NOT NULL PRIMARY KEY,
    week INT NOT NULL,
    season_type VARCHAR(20) NOT NULL,
    season VARCHAR(4) NOT NULL,
    display_week INT,
    leg INT,
    league_season VARCHAR(4),
    league_create_season VARCHAR(4),
    previous_season VARCHAR(4),
    season_start_date VARCHAR(20),
    season_has_scores BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for sync_state
CREATE INDEX IF NOT EXISTS idx_sync_state_entity_type ON sleeper.sync_state(entity_type);
CREATE INDEX IF NOT EXISTS idx_sync_state_last_synced ON sleeper.sync_state(last_synced_at);

-- Comments
COMMENT ON TABLE sleeper.sync_state IS 'Tracks synchronization state for various entities';
COMMENT ON TABLE sleeper.sport_state IS 'Current state of the sport (season, week, etc)';