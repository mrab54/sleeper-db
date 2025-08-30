# Sleeper Fantasy Football Database Design

## Overview

This document outlines the normalized PostgreSQL database schema for storing Sleeper fantasy football data. The design follows database normalization principles to eliminate redundancy, ensure data integrity, and provide efficient querying capabilities.

**Schema**: All tables are created in the `sleeper` schema.
**Database**: `sleeper_db`

## Design Principles

1. **Normalization**: Tables are normalized to at least 3NF to minimize redundancy
2. **Natural Keys**: Use Sleeper's IDs as primary keys where they exist
3. **Referential Integrity**: All relationships enforced through foreign key constraints
4. **Temporal Data**: Track historical changes with timestamp fields
5. **Extensibility**: Use JSONB for flexible metadata storage where appropriate
6. **Performance**: Strategic indexing on foreign keys and commonly queried fields

## Core Entities

### 1. Users Table
Stores user account information.

```sql
CREATE TABLE sleeper.users (
    user_id VARCHAR(50) PRIMARY KEY,  -- From Sleeper API
    username VARCHAR(50) UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    avatar VARCHAR(100),  -- Avatar ID for CDN URL construction
    is_bot BOOLEAN DEFAULT FALSE,
    email VARCHAR(255),
    phone VARCHAR(20),
    real_name VARCHAR(100),
    verification_status VARCHAR(20),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    sleeper_created_at TIMESTAMP,  -- When account was created in Sleeper
    metadata JSONB  -- Flexible storage for additional user attributes
);
```

### 2. Sports Table
Reference table for supported sports.

```sql
CREATE TABLE sleeper.sports (
    sport_id VARCHAR(10) PRIMARY KEY,  -- 'nfl', future: 'nba', etc.
    sport_name VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### 3. Seasons Table
Tracks seasons across sports.

```sql
CREATE TABLE sleeper.seasons (
    season_id SERIAL PRIMARY KEY,
    sport_id VARCHAR(10) NOT NULL REFERENCES sleeper.sports(sport_id),
    year VARCHAR(4) NOT NULL,  -- '2024'
    season_type VARCHAR(10) NOT NULL,  -- 'regular', 'post', 'off'
    start_date DATE,
    end_date DATE,
    is_current BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(sport_id, year)
);
```

### 4. Sport State Table
Current state of each sport (week, season info).

```sql
CREATE TABLE sleeper.sport_states (
    state_id SERIAL PRIMARY KEY,
    sport_id VARCHAR(10) NOT NULL REFERENCES sleeper.sports(sport_id),
    season_id INTEGER REFERENCES sleeper.seasons(season_id),
    current_week INTEGER NOT NULL,
    season_type VARCHAR(10) NOT NULL,
    season VARCHAR(4) NOT NULL,
    display_week INTEGER,
    leg INTEGER,
    league_season VARCHAR(4),
    league_create_season VARCHAR(4),
    previous_season VARCHAR(4),
    season_start_date DATE,
    season_has_scores BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(sport_id, season)
);
```

### 5. Leagues Table
Core league information.

```sql
CREATE TABLE sleeper.leagues (
    league_id VARCHAR(50) PRIMARY KEY,  -- From Sleeper API
    season_id INTEGER NOT NULL REFERENCES sleeper.seasons(season_id),
    sport_id VARCHAR(10) NOT NULL REFERENCES sleeper.sports(sport_id),
    name VARCHAR(255) NOT NULL,
    avatar VARCHAR(100),  -- Avatar ID for CDN URL construction
    status VARCHAR(20) NOT NULL,  -- 'pre_draft', 'drafting', 'in_season', 'complete'
    season_type VARCHAR(20),
    total_rosters INTEGER NOT NULL,
    draft_id VARCHAR(50),  -- Reference to drafts table
    previous_league_id VARCHAR(50) REFERENCES sleeper.leagues(league_id),
    bracket_id VARCHAR(50),
    loser_bracket_id VARCHAR(50),
    shard INTEGER,
    company_id VARCHAR(50),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_transaction_id VARCHAR(50),
    last_message_time TIMESTAMP,
    display_order INTEGER,
    metadata JSONB  -- Custom league metadata
);
```

### 6. League Settings Table
Separated from leagues table for normalization.

```sql
CREATE TABLE sleeper.league_settings (
    league_id VARCHAR(50) PRIMARY KEY REFERENCES sleeper.leagues(league_id) ON DELETE CASCADE,
    max_keepers INTEGER DEFAULT 0,
    draft_rounds INTEGER,
    trade_deadline INTEGER,
    waiver_type VARCHAR,  -- 'traditional', 'faab'
    waiver_day_of_week INTEGER,  -- 0-6
    waiver_budget INTEGER DEFAULT 100,
    waiver_clear_days INTEGER,
    playoff_week_start INTEGER,
    playoff_teams INTEGER DEFAULT 6,
    daily_waivers BOOLEAN DEFAULT FALSE,
    reserve_slots INTEGER DEFAULT 0,
    reserve_allow_out BOOLEAN DEFAULT TRUE,
    reserve_allow_na BOOLEAN DEFAULT FALSE,
    reserve_allow_dnr BOOLEAN DEFAULT FALSE,
    reserve_allow_doubtful BOOLEAN DEFAULT TRUE,
    taxi_slots INTEGER DEFAULT 0,
    taxi_years INTEGER,
    taxi_allow_vets BOOLEAN DEFAULT FALSE,
    taxi_deadline INTEGER,
    pick_trading BOOLEAN DEFAULT TRUE,
    disable_trades BOOLEAN DEFAULT FALSE,
    trade_review_days INTEGER DEFAULT 1,
    commissioner_direct_invite BOOLEAN DEFAULT TRUE,
    capacity_override BOOLEAN DEFAULT FALSE,
    disable_counter BOOLEAN DEFAULT FALSE,
    type INTEGER DEFAULT 0,  -- League type
    best_ball BOOLEAN DEFAULT FALSE,
    last_report INTEGER,
    last_scored_leg INTEGER,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### 7. League Scoring Settings Table
Normalized scoring configuration.

```sql
CREATE TABLE sleeper.league_scoring_settings (
    league_id VARCHAR(50) PRIMARY KEY REFERENCES sleeper.leagues(league_id) ON DELETE CASCADE,
    pass_td DECIMAL(4,2) DEFAULT 6.0,
    pass_yd DECIMAL(4,2) DEFAULT 0.04,
    pass_int DECIMAL(4,2) DEFAULT -2.0,
    pass_2pt DECIMAL(4,2) DEFAULT 2.0,
    rush_td DECIMAL(4,2) DEFAULT 6.0,
    rush_yd DECIMAL(4,2) DEFAULT 0.1,
    rush_2pt DECIMAL(4,2) DEFAULT 2.0,
    rec_td DECIMAL(4,2) DEFAULT 6.0,
    rec_yd DECIMAL(4,2) DEFAULT 0.1,
    rec DECIMAL(4,2) DEFAULT 0.0,  -- PPR value
    rec_2pt DECIMAL(4,2) DEFAULT 2.0,
    fum_lost DECIMAL(4,2) DEFAULT -2.0,
    fum_rec_td DECIMAL(4,2) DEFAULT 6.0,
    fg_0_19 DECIMAL(4,2) DEFAULT 3.0,
    fg_20_29 DECIMAL(4,2) DEFAULT 3.0,
    fg_30_39 DECIMAL(4,2) DEFAULT 3.0,
    fg_40_49 DECIMAL(4,2) DEFAULT 4.0,
    fg_50_plus DECIMAL(4,2) DEFAULT 5.0,
    fg_miss DECIMAL(4,2) DEFAULT -1.0,
    xp_make DECIMAL(4,2) DEFAULT 1.0,
    xp_miss DECIMAL(4,2) DEFAULT -1.0,
    def_td DECIMAL(4,2) DEFAULT 6.0,
    def_sack DECIMAL(4,2) DEFAULT 1.0,
    def_int DECIMAL(4,2) DEFAULT 2.0,
    def_fum_rec DECIMAL(4,2) DEFAULT 2.0,
    def_safety DECIMAL(4,2) DEFAULT 2.0,
    def_blk DECIMAL(4,2) DEFAULT 2.0,
    def_points_allowed_0 DECIMAL(4,2) DEFAULT 10.0,
    def_points_allowed_1_6 DECIMAL(4,2) DEFAULT 7.0,
    def_points_allowed_7_13 DECIMAL(4,2) DEFAULT 4.0,
    def_points_allowed_14_20 DECIMAL(4,2) DEFAULT 1.0,
    def_points_allowed_21_27 DECIMAL(4,2) DEFAULT 0.0,
    def_points_allowed_28_34 DECIMAL(4,2) DEFAULT -1.0,
    def_points_allowed_35_plus DECIMAL(4,2) DEFAULT -4.0,
    bonus_pass_yd_300 DECIMAL(4,2) DEFAULT 0.0,
    bonus_pass_yd_400 DECIMAL(4,2) DEFAULT 0.0,
    bonus_rush_yd_100 DECIMAL(4,2) DEFAULT 0.0,
    bonus_rush_yd_200 DECIMAL(4,2) DEFAULT 0.0,
    bonus_rec_yd_100 DECIMAL(4,2) DEFAULT 0.0,
    bonus_rec_yd_200 DECIMAL(4,2) DEFAULT 0.0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    additional_scoring JSONB  -- For any non-standard scoring settings
);
```

### 8. League Roster Positions Table
Defines roster composition for each league.

```sql
CREATE TABLE sleeper.league_roster_positions (
    position_id SERIAL PRIMARY KEY,
    league_id VARCHAR(50) NOT NULL REFERENCES sleeper.leagues(league_id) ON DELETE CASCADE,
    position VARCHAR(20) NOT NULL,  -- 'QB', 'RB', 'WR', 'TE', 'FLEX', 'SUPER_FLEX', 'K', 'DEF', 'BN'
    count INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(league_id, position)
);
```

### 9. NFL Teams Table
Reference table for NFL teams.

```sql
CREATE TABLE sleeper.nfl_teams (
    team_abbr VARCHAR(3) PRIMARY KEY,  -- 'KC', 'BUF', etc.
    team_name VARCHAR(50) NOT NULL,
    conference VARCHAR(3),  -- 'AFC', 'NFC'
    division VARCHAR(10) NOT NULL,  -- 'East', 'West', 'North', 'South'
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### 10. Players Table
Master player information.

```sql
CREATE TABLE sleeper.players (
    player_id VARCHAR PRIMARY KEY,  -- From Sleeper API
    first_name VARCHAR,
    last_name VARCHAR,
    full_name VARCHAR,
    search_full_name VARCHAR,  -- Normalized for searching
    position VARCHAR,  -- Primary position
    team_abbr VARCHAR(3) REFERENCES nfl_teams(team_abbr),
    status VARCHAR,  -- 'Active', 'Inactive', 'Injured Reserve', 'Practice Squad'
    injury_status VARCHAR,  -- 'Questionable', 'Doubtful', 'Out', NULL
    injury_body_part VARCHAR,
    injury_notes TEXT,
    injury_start_date DATE,
    practice_participation VARCHAR,
    practice_description VARCHAR,
    is_active BOOLEAN DEFAULT TRUE,
    depth_chart_order INTEGER,
    depth_chart_position VARCHAR,
    jersey_number INTEGER,
    height INTEGER,  -- in inches
    weight INTEGER,  -- in pounds
    age INTEGER,
    years_exp INTEGER,
    birth_date DATE,
    birth_city VARCHAR,
    birth_state VARCHAR,
    birth_country VARCHAR,
    college VARCHAR,
    high_school VARCHAR,
    sport VARCHAR DEFAULT 'nfl',
    search_rank INTEGER,  -- For search optimization
    news_updated TIMESTAMP,
    hashtag VARCHAR,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    metadata JSONB,  -- Additional flexible attributes
    external_ids JSONB  -- Store all external IDs (ESPN, Yahoo, etc.)
);
```

### 11. Player Fantasy Positions Table
Many-to-many relationship for fantasy-eligible positions.

```sql
CREATE TABLE sleeper.player_fantasy_positions (
    player_id VARCHAR NOT NULL REFERENCES sleeper.players(player_id) ON DELETE CASCADE,
    position VARCHAR NOT NULL,
    PRIMARY KEY (player_id, position)
);
```

### 12. Rosters Table
Team rosters within leagues.

```sql
CREATE TABLE sleeper.rosters (
    roster_id SERIAL PRIMARY KEY,
    league_id VARCHAR NOT NULL REFERENCES sleeper.leagues(league_id) ON DELETE CASCADE,
    owner_user_id VARCHAR REFERENCES sleeper.users(user_id),
    roster_position INTEGER NOT NULL,  -- 1-based position in league
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    ties INTEGER DEFAULT 0,
    total_moves INTEGER DEFAULT 0,
    waiver_position INTEGER,
    waiver_budget_used INTEGER DEFAULT 0,
    fantasy_points_for DECIMAL(10,2) DEFAULT 0,
    fantasy_points_against DECIMAL(10,2) DEFAULT 0,
    points_for_decimal DECIMAL(10,2) DEFAULT 0,
    points_against_decimal DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    metadata JSONB,  -- Team name, avatar, custom settings
    UNIQUE(league_id, roster_position)
);
```

### 13. Roster Co-Owners Table
Many-to-many for roster co-ownership.

```sql
CREATE TABLE sleeper.roster_co_owners (
    roster_id INTEGER NOT NULL REFERENCES sleeper.rosters(roster_id) ON DELETE CASCADE,
    user_id VARCHAR NOT NULL REFERENCES sleeper.users(user_id),
    PRIMARY KEY (roster_id, user_id)
);
```

### 14. Roster Players Table
Current roster compositions (point-in-time).

```sql
CREATE TABLE sleeper.roster_players (
    roster_player_id SERIAL PRIMARY KEY,
    roster_id INTEGER NOT NULL REFERENCES sleeper.rosters(roster_id) ON DELETE CASCADE,
    player_id VARCHAR NOT NULL REFERENCES sleeper.players(player_id),
    acquisition_date TIMESTAMP NOT NULL DEFAULT NOW(),
    acquisition_type VARCHAR,  -- 'draft', 'trade', 'waiver', 'free_agent'
    status VARCHAR DEFAULT 'active',  -- 'active', 'reserve', 'taxi', 'inactive'
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(roster_id, player_id)
);
```

### 15. Weekly Lineups Table
Starting lineups for each week.

```sql
CREATE TABLE sleeper.weekly_lineups (
    lineup_id SERIAL PRIMARY KEY,
    roster_id INTEGER NOT NULL REFERENCES sleeper.rosters(roster_id) ON DELETE CASCADE,
    week INTEGER NOT NULL,
    season_id INTEGER NOT NULL REFERENCES sleeper.seasons(season_id),
    submitted_at TIMESTAMP,
    is_final BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(roster_id, week, season_id)
);
```

### 16. Lineup Players Table
Players in each weekly lineup.

```sql
CREATE TABLE sleeper.lineup_players (
    lineup_player_id SERIAL PRIMARY KEY,
    lineup_id INTEGER NOT NULL REFERENCES sleeper.weekly_lineups(lineup_id) ON DELETE CASCADE,
    player_id VARCHAR NOT NULL REFERENCES sleeper.players(player_id),
    roster_slot VARCHAR NOT NULL,  -- 'QB', 'RB1', 'RB2', 'WR1', 'FLEX', 'BN1', etc.
    slot_index INTEGER NOT NULL,  -- Order within position
    projected_points DECIMAL(6,2),
    actual_points DECIMAL(6,2),
    is_starter BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### 17. Matchups Table
Weekly head-to-head matchups.

```sql
CREATE TABLE sleeper.matchups (
    matchup_id SERIAL PRIMARY KEY,
    league_id VARCHAR NOT NULL REFERENCES sleeper.leagues(league_id) ON DELETE CASCADE,
    week INTEGER NOT NULL,
    season_id INTEGER NOT NULL REFERENCES sleeper.seasons(season_id),
    matchup_number INTEGER NOT NULL,  -- Groups matchups together
    is_playoff BOOLEAN DEFAULT FALSE,
    is_consolation BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(league_id, week, season_id, matchup_number)
);
```

### 18. Matchup Teams Table
Teams participating in matchups.

```sql
CREATE TABLE sleeper.matchup_teams (
    matchup_team_id SERIAL PRIMARY KEY,
    matchup_id INTEGER NOT NULL REFERENCES sleeper.matchups(matchup_id) ON DELETE CASCADE,
    roster_id INTEGER NOT NULL REFERENCES sleeper.rosters(roster_id),
    points DECIMAL(8,2) DEFAULT 0,
    custom_points DECIMAL(8,2),
    is_winner BOOLEAN,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### 19. Matchup Player Stats Table
Individual player performance in matchups.

```sql
CREATE TABLE sleeper.matchup_player_stats (
    stat_id SERIAL PRIMARY KEY,
    matchup_team_id INTEGER NOT NULL REFERENCES sleeper.matchup_teams(matchup_team_id) ON DELETE CASCADE,
    player_id VARCHAR NOT NULL REFERENCES sleeper.players(player_id),
    points DECIMAL(6,2) NOT NULL,
    projected_points DECIMAL(6,2),
    is_starter BOOLEAN DEFAULT TRUE,
    slot_position VARCHAR,  -- Position they were started in
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### 20. Playoff Brackets Table
Playoff bracket structure.

```sql
CREATE TABLE sleeper.playoff_brackets (
    bracket_id SERIAL PRIMARY KEY,
    league_id VARCHAR NOT NULL REFERENCES sleeper.leagues(league_id) ON DELETE CASCADE,
    bracket_type VARCHAR NOT NULL,  -- 'winners', 'losers', 'toilet'
    season_id INTEGER NOT NULL REFERENCES sleeper.seasons(season_id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(league_id, bracket_type, season_id)
);
```

### 21. Playoff Matchups Table
Playoff bracket matchups.

```sql
CREATE TABLE sleeper.playoff_matchups (
    playoff_matchup_id SERIAL PRIMARY KEY,
    bracket_id INTEGER NOT NULL REFERENCES sleeper.playoff_brackets(bracket_id) ON DELETE CASCADE,
    round INTEGER NOT NULL,
    matchup_number INTEGER NOT NULL,
    team1_roster_id INTEGER REFERENCES sleeper.rosters(roster_id),
    team2_roster_id INTEGER REFERENCES sleeper.rosters(roster_id),
    winner_roster_id INTEGER REFERENCES sleeper.rosters(roster_id),
    team1_seed INTEGER,
    team2_seed INTEGER,
    team1_from_matchup INTEGER REFERENCES sleeper.playoff_matchups(playoff_matchup_id),
    team1_from_result VARCHAR,  -- 'W' or 'L'
    team2_from_matchup INTEGER REFERENCES sleeper.playoff_matchups(playoff_matchup_id),
    team2_from_result VARCHAR,  -- 'W' or 'L'
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### 22. Transactions Table
All league transactions.

```sql
CREATE TABLE sleeper.transactions (
    transaction_id VARCHAR PRIMARY KEY,  -- From Sleeper API
    league_id VARCHAR NOT NULL REFERENCES sleeper.leagues(league_id) ON DELETE CASCADE,
    type VARCHAR NOT NULL,  -- 'trade', 'waiver', 'free_agent', 'commissioner'
    status VARCHAR NOT NULL,  -- 'complete', 'pending', 'failed'
    week INTEGER NOT NULL,
    season_id INTEGER NOT NULL REFERENCES sleeper.seasons(season_id),
    status_updated_at TIMESTAMP,
    creator_user_id VARCHAR REFERENCES sleeper.users(user_id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMP,
    metadata JSONB  -- Additional transaction details
);
```

### 23. Transaction Roster Involvement Table
Which rosters are involved in transactions.

```sql
CREATE TABLE sleeper.transaction_rosters (
    transaction_id VARCHAR NOT NULL REFERENCES sleeper.transactions(transaction_id) ON DELETE CASCADE,
    roster_id INTEGER NOT NULL REFERENCES sleeper.rosters(roster_id),
    is_consenter BOOLEAN DEFAULT FALSE,  -- Needs to approve
    has_consented BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (transaction_id, roster_id)
);
```

### 24. Transaction Players Table
Player adds/drops in transactions.

```sql
CREATE TABLE sleeper.transaction_players (
    transaction_player_id SERIAL PRIMARY KEY,
    transaction_id VARCHAR NOT NULL REFERENCES sleeper.transactions(transaction_id) ON DELETE CASCADE,
    player_id VARCHAR NOT NULL REFERENCES sleeper.players(player_id),
    action VARCHAR NOT NULL,  -- 'add' or 'drop'
    roster_id INTEGER NOT NULL REFERENCES sleeper.rosters(roster_id),
    waiver_bid INTEGER,  -- FAAB amount if applicable
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### 25. Transaction Draft Picks Table
Draft picks involved in trades.

```sql
CREATE TABLE sleeper.transaction_draft_picks (
    transaction_pick_id SERIAL PRIMARY KEY,
    transaction_id VARCHAR NOT NULL REFERENCES sleeper.transactions(transaction_id) ON DELETE CASCADE,
    season VARCHAR NOT NULL,
    round INTEGER NOT NULL,
    from_roster_id INTEGER NOT NULL REFERENCES sleeper.rosters(roster_id),
    to_roster_id INTEGER NOT NULL REFERENCES sleeper.rosters(roster_id),
    original_owner_roster_id INTEGER REFERENCES sleeper.rosters(roster_id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### 26. Drafts Table
Draft information.

```sql
CREATE TABLE sleeper.drafts (
    draft_id VARCHAR PRIMARY KEY,  -- From Sleeper API
    league_id VARCHAR NOT NULL REFERENCES sleeper.leagues(league_id),
    sport_id VARCHAR NOT NULL REFERENCES sleeper.sports(sport_id),
    season_id INTEGER NOT NULL REFERENCES sleeper.seasons(season_id),
    type VARCHAR NOT NULL,  -- 'snake', 'linear', 'auction'
    status VARCHAR NOT NULL,  -- 'pre_draft', 'drafting', 'paused', 'complete'
    start_time TIMESTAMP,
    rounds INTEGER NOT NULL,
    picks_per_round INTEGER NOT NULL,
    reversal_round INTEGER DEFAULT 0,
    pick_timer INTEGER,  -- Seconds per pick
    nomination_timer INTEGER,  -- For auction drafts
    enforce_position_limits BOOLEAN DEFAULT FALSE,
    cpu_autopick BOOLEAN DEFAULT TRUE,
    autostart BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP,
    metadata JSONB  -- Additional draft settings
);
```

### 27. Draft Slots Table
Maps draft positions to rosters.

```sql
CREATE TABLE sleeper.draft_slots (
    draft_id VARCHAR NOT NULL REFERENCES sleeper.drafts(draft_id) ON DELETE CASCADE,
    slot INTEGER NOT NULL,
    roster_id INTEGER REFERENCES sleeper.rosters(roster_id),
    user_id VARCHAR REFERENCES sleeper.users(user_id),
    is_keeper_slot BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (draft_id, slot)
);
```

### 28. Draft Picks Table
Individual draft selections.

```sql
CREATE TABLE sleeper.draft_picks (
    pick_id SERIAL PRIMARY KEY,
    draft_id VARCHAR NOT NULL REFERENCES sleeper.drafts(draft_id) ON DELETE CASCADE,
    round INTEGER NOT NULL,
    pick_in_round INTEGER NOT NULL,
    overall_pick INTEGER NOT NULL,
    slot INTEGER NOT NULL,
    roster_id INTEGER REFERENCES sleeper.rosters(roster_id),
    player_id VARCHAR REFERENCES sleeper.players(player_id),
    picked_by_user_id VARCHAR REFERENCES sleeper.users(user_id),
    pick_time TIMESTAMP,
    is_keeper BOOLEAN DEFAULT FALSE,
    auction_amount INTEGER,  -- For auction drafts
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    metadata JSONB,  -- Player info at time of pick
    UNIQUE(draft_id, overall_pick)
);
```

### 29. Traded Draft Picks Table
Tracks future draft pick trades.

```sql
CREATE TABLE sleeper.traded_draft_picks (
    traded_pick_id SERIAL PRIMARY KEY,
    league_id VARCHAR NOT NULL REFERENCES sleeper.leagues(league_id) ON DELETE CASCADE,
    season VARCHAR NOT NULL,
    round INTEGER NOT NULL,
    original_owner_roster_id INTEGER NOT NULL REFERENCES sleeper.rosters(roster_id),
    current_owner_roster_id INTEGER NOT NULL REFERENCES sleeper.rosters(roster_id),
    previous_owner_roster_id INTEGER REFERENCES sleeper.rosters(roster_id),
    trade_transaction_id VARCHAR REFERENCES sleeper.transactions(transaction_id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### 30. Player Trending Table
Tracks trending player adds/drops.

```sql
CREATE TABLE sleeper.player_trending (
    trending_id SERIAL PRIMARY KEY,
    player_id VARCHAR NOT NULL REFERENCES sleeper.players(player_id),
    sport_id VARCHAR NOT NULL REFERENCES sleeper.sports(sport_id),
    trend_type VARCHAR NOT NULL,  -- 'add' or 'drop'
    count INTEGER NOT NULL,
    date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(player_id, sport_id, trend_type, date)
);
```

### 31. League Members Table
User membership in leagues.

```sql
CREATE TABLE sleeper.league_members (
    league_id VARCHAR NOT NULL REFERENCES sleeper.leagues(league_id) ON DELETE CASCADE,
    user_id VARCHAR NOT NULL REFERENCES sleeper.users(user_id),
    roster_id INTEGER REFERENCES sleeper.rosters(roster_id),
    is_owner BOOLEAN DEFAULT FALSE,
    is_commissioner BOOLEAN DEFAULT FALSE,
    join_date TIMESTAMP NOT NULL DEFAULT NOW(),
    leave_date TIMESTAMP,
    display_name VARCHAR,
    team_name VARCHAR,
    avatar VARCHAR,  -- Avatar ID for CDN URL construction
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    metadata JSONB,  -- User-specific league settings
    PRIMARY KEY (league_id, user_id)
);
```

### 32. Data Sync Log Table
Track API synchronization history.

```sql
CREATE TABLE sleeper.data_sync_log (
    sync_id SERIAL PRIMARY KEY,
    sync_type VARCHAR NOT NULL,  -- 'leagues', 'rosters', 'players', 'matchups', etc.
    entity_id VARCHAR,  -- League ID, user ID, etc.
    status VARCHAR NOT NULL,  -- 'started', 'completed', 'failed'
    started_at TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP,
    records_processed INTEGER DEFAULT 0,
    error_message TEXT,
    metadata JSONB  -- Additional sync details
);
```

## Indexes

### Performance Indexes
```sql
-- User lookups
CREATE INDEX idx_users_username ON sleeper.users(username);
CREATE INDEX idx_users_email ON sleeper.users(email) WHERE email IS NOT NULL;

-- League queries
CREATE INDEX idx_leagues_sport_season ON sleeper.leagues(sport_id, season_id);
CREATE INDEX idx_leagues_status ON sleeper.leagues(status);
CREATE INDEX idx_league_members_user ON sleeper.league_members(user_id);

-- Player searches
CREATE INDEX idx_players_search_name ON sleeper.players(search_full_name);
CREATE INDEX idx_players_team ON sleeper.players(team_abbr);
CREATE INDEX idx_players_position ON sleeper.players(position);
CREATE INDEX idx_players_status ON sleeper.players(status);

-- Roster queries
CREATE INDEX idx_rosters_league ON sleeper.rosters(league_id);
CREATE INDEX idx_rosters_owner ON sleeper.rosters(owner_user_id);
CREATE INDEX idx_roster_players_roster ON sleeper.roster_players(roster_id);
CREATE INDEX idx_roster_players_player ON sleeper.roster_players(player_id);

-- Matchup queries
CREATE INDEX idx_matchups_league_week ON sleeper.matchups(league_id, week);
CREATE INDEX idx_matchup_teams_matchup ON sleeper.matchup_teams(matchup_id);
CREATE INDEX idx_matchup_teams_roster ON sleeper.matchup_teams(roster_id);

-- Transaction queries
CREATE INDEX idx_transactions_league ON sleeper.transactions(league_id);
CREATE INDEX idx_transactions_type_status ON sleeper.transactions(type, status);
CREATE INDEX idx_transactions_week ON sleeper.transactions(week);
CREATE INDEX idx_transaction_players_player ON sleeper.transaction_players(player_id);

-- Draft queries
CREATE INDEX idx_drafts_league ON sleeper.drafts(league_id);
CREATE INDEX idx_draft_picks_draft ON sleeper.draft_picks(draft_id);
CREATE INDEX idx_draft_picks_player ON sleeper.draft_picks(player_id);

-- Trending data
CREATE INDEX idx_player_trending_date ON sleeper.player_trending(date DESC);
CREATE INDEX idx_player_trending_player ON sleeper.player_trending(player_id);
```

## Views

### 1. Current Rosters View
```sql
CREATE VIEW current_rosters AS
SELECT 
    r.roster_id,
    r.league_id,
    r.owner_user_id,
    u.display_name as owner_name,
    r.wins,
    r.losses,
    r.ties,
    r.fantasy_points_for,
    r.fantasy_points_against,
    r.waiver_position,
    r.waiver_budget_used,
    l.name as league_name,
    l.status as league_status
FROM sleeper.rosters r
LEFT JOIN sleeper.users u ON r.owner_user_id = u.user_id
LEFT JOIN sleeper.leagues l ON r.league_id = l.league_id;
```

### 2. Player Stats Summary View
```sql
CREATE VIEW player_stats_summary AS
SELECT 
    p.player_id,
    p.full_name,
    p.position,
    p.team_abbr,
    COUNT(DISTINCT rp.roster_id) as rostered_count,
    AVG(mps.points) as avg_points,
    SUM(tp.action = 'add') as total_adds,
    SUM(tp.action = 'drop') as total_drops
FROM sleeper.players p
LEFT JOIN sleeper.roster_players rp ON p.player_id = rp.player_id
LEFT JOIN sleeper.matchup_player_stats mps ON p.player_id = mps.player_id
LEFT JOIN sleeper.transaction_players tp ON p.player_id = tp.player_id
GROUP BY p.player_id, p.full_name, p.position, p.team_abbr;
```

### 3. League Standings View
```sql
CREATE VIEW league_standings AS
SELECT 
    r.league_id,
    r.roster_id,
    r.roster_position,
    u.display_name as owner_name,
    r.wins,
    r.losses,
    r.ties,
    r.fantasy_points_for,
    r.fantasy_points_against,
    r.fantasy_points_for - r.fantasy_points_against as point_differential,
    RANK() OVER (
        PARTITION BY r.league_id 
        ORDER BY r.wins DESC, r.fantasy_points_for DESC
    ) as rank
FROM sleeper.rosters r
LEFT JOIN sleeper.users u ON r.owner_user_id = u.user_id;
```

## Data Integrity Constraints

### Business Rules
1. **Roster Size**: Ensure roster player count doesn't exceed league settings
2. **Lineup Validity**: Starting lineups must follow position requirements
3. **Transaction Timing**: No transactions after trade deadline
4. **Waiver Priority**: Enforce waiver order/budget constraints
5. **Draft Order**: Ensure picks follow draft type rules (snake/linear)

## Migration Strategy

### Initial Data Load
1. **Players**: Load first (independent entity)
2. **Users**: Load from league/roster endpoints
3. **Leagues**: Load with settings and scoring
4. **Rosters**: Load with current players
5. **Matchups**: Historical data by week
6. **Transactions**: Historical transaction data
7. **Drafts**: If available for leagues

### Incremental Updates
1. Use `data_sync_log` to track last successful sync
2. Implement delta detection for changed data
3. Update only modified records
4. Use database transactions for consistency

## Performance Considerations

### Partitioning Strategy
Consider partitioning large tables:
- `matchup_player_stats` by season
- `transactions` by season
- `data_sync_log` by month

### Materialized Views
For expensive aggregations:
- Season-long player statistics
- Historical league standings
- Player ownership percentages

### Connection Pooling
- Use PgBouncer or similar for connection management
- Configure appropriate pool sizes based on load

## Security Considerations

1. **Row-Level Security**: Implement RLS for multi-tenant access
2. **Column Encryption**: Encrypt PII fields (email, phone)
3. **Audit Logging**: Track all data modifications
4. **API Keys**: Store securely if Sleeper adds authentication
5. **Rate Limiting**: Implement at application level

## Future Enhancements

1. **Historical Stats**: Add tables for weekly NFL game stats
2. **Projections**: Store and track projection accuracy
3. **Dynasty Features**: Multi-year rookie drafts, contracts
4. **Analytics**: Advanced metrics and trend analysis
5. **Notifications**: Event-driven updates for transactions
6. **Multi-Sport**: Extend schema for NBA, MLB when available

## Conclusion

This normalized database design provides:
- **Data Integrity**: Through proper constraints and relationships
- **Performance**: Via strategic indexing and views
- **Flexibility**: JSONB fields for evolving requirements
- **Scalability**: Partitioning ready for large datasets
- **Maintainability**: Clear structure and naming conventions

The schema balances normalization with practical query performance, making it suitable for both transactional operations and analytical queries.