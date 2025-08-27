-- Missing tables required by sync service

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

-- League users association
CREATE TABLE IF NOT EXISTS sleeper.league_users (
    league_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(50) NOT NULL,
    is_owner BOOLEAN DEFAULT FALSE,
    is_commissioner BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (league_id, user_id),
    FOREIGN KEY (league_id) REFERENCES sleeper.leagues(league_id),
    FOREIGN KEY (user_id) REFERENCES sleeper.users(user_id)
);

-- Transaction adds (players added in transactions)
CREATE TABLE IF NOT EXISTS sleeper.transaction_adds (
    transaction_id VARCHAR(50) NOT NULL,
    player_id VARCHAR(50) NOT NULL,
    roster_id INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (transaction_id, player_id),
    FOREIGN KEY (transaction_id) REFERENCES sleeper.transactions(transaction_id),
    FOREIGN KEY (player_id) REFERENCES sleeper.players(player_id)
);

-- Transaction drops (players dropped in transactions)
CREATE TABLE IF NOT EXISTS sleeper.transaction_drops (
    transaction_id VARCHAR(50) NOT NULL,
    player_id VARCHAR(50) NOT NULL,
    roster_id INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (transaction_id, player_id),
    FOREIGN KEY (transaction_id) REFERENCES sleeper.transactions(transaction_id),
    FOREIGN KEY (player_id) REFERENCES sleeper.players(player_id)
);

-- Trending players
CREATE TABLE IF NOT EXISTS sleeper.trending_players (
    player_id VARCHAR(50) NOT NULL,
    trend_type VARCHAR(10) NOT NULL, -- 'add' or 'drop'
    count INT NOT NULL,
    lookback_hours INT,
    trend_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (player_id, trend_type, trend_date),
    FOREIGN KEY (player_id) REFERENCES sleeper.players(player_id)
);

-- Create sport_state as an alias/view to sport_states for compatibility
CREATE OR REPLACE VIEW sleeper.sport_state AS SELECT * FROM sleeper.sport_states;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sync_state_entity_type ON sleeper.sync_state(entity_type);
CREATE INDEX IF NOT EXISTS idx_sync_state_last_synced ON sleeper.sync_state(last_synced_at);
CREATE INDEX IF NOT EXISTS idx_league_users_user_id ON sleeper.league_users(user_id);
CREATE INDEX IF NOT EXISTS idx_transaction_adds_player ON sleeper.transaction_adds(player_id);
CREATE INDEX IF NOT EXISTS idx_transaction_drops_player ON sleeper.transaction_drops(player_id);
CREATE INDEX IF NOT EXISTS idx_trending_players_date ON sleeper.trending_players(trend_date);