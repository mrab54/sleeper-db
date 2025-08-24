# Sleeper Fantasy Football Database Project

## Project Overview
This project provides a normalized PostgreSQL database for Sleeper fantasy football league data with a Hasura GraphQL interface. It fetches and stores data from the Sleeper API in a normalized structure, maintaining up-to-date league information through scheduled jobs.

**Primary League ID**: `1199102384316362752`

## Architecture Components
- **PostgreSQL**: Normalized data storage
- **Hasura**: GraphQL API layer
- **Docker**: Container orchestration
- **Scheduled Jobs**: Data synchronization via Hasura scheduled events

## Database Schema Design

### Core Tables

#### users
```sql
CREATE TABLE users (
    user_id VARCHAR(255) PRIMARY KEY,
    username VARCHAR(255) UNIQUE,
    display_name VARCHAR(255),
    avatar VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

#### leagues
```sql
CREATE TABLE leagues (
    league_id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255),
    season VARCHAR(10),
    sport VARCHAR(50),
    status VARCHAR(50), -- pre_draft, drafting, in_season, complete
    total_rosters INTEGER,
    draft_id VARCHAR(255),
    previous_league_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

#### league_settings
```sql
CREATE TABLE league_settings (
    league_id VARCHAR(255) PRIMARY KEY REFERENCES leagues(league_id),
    playoff_week_start INTEGER,
    leg INTEGER,
    max_keepers INTEGER,
    draft_rounds INTEGER,
    trade_deadline INTEGER,
    waiver_type INTEGER,
    waiver_day_of_week INTEGER,
    waiver_budget INTEGER,
    reserve_slots INTEGER,
    taxi_slots INTEGER,
    settings_json JSONB, -- Store full settings for reference
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

#### league_scoring_settings
```sql
CREATE TABLE league_scoring_settings (
    league_id VARCHAR(255) PRIMARY KEY REFERENCES leagues(league_id),
    pass_td DECIMAL(5,2),
    pass_yd DECIMAL(5,2),
    pass_int DECIMAL(5,2),
    rush_td DECIMAL(5,2),
    rush_yd DECIMAL(5,2),
    rec_td DECIMAL(5,2),
    rec_yd DECIMAL(5,2),
    rec DECIMAL(5,2),
    scoring_json JSONB, -- Store full scoring settings
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

#### rosters
```sql
CREATE TABLE rosters (
    id SERIAL PRIMARY KEY,
    roster_id INTEGER NOT NULL,
    league_id VARCHAR(255) REFERENCES leagues(league_id),
    owner_id VARCHAR(255) REFERENCES users(user_id),
    co_owner_ids VARCHAR(255)[],
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    ties INTEGER DEFAULT 0,
    points_for DECIMAL(10,2) DEFAULT 0,
    points_against DECIMAL(10,2) DEFAULT 0,
    waiver_position INTEGER,
    waiver_budget_used INTEGER DEFAULT 0,
    total_moves INTEGER DEFAULT 0,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(league_id, roster_id)
);
CREATE INDEX idx_rosters_league ON rosters(league_id);
CREATE INDEX idx_rosters_owner ON rosters(owner_id);
```

#### players
```sql
CREATE TABLE players (
    player_id VARCHAR(50) PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name VARCHAR(200),
    position VARCHAR(10),
    team VARCHAR(10),
    status VARCHAR(50), -- Active, Injured Reserve, etc
    injury_status VARCHAR(50),
    years_exp INTEGER,
    age INTEGER,
    height VARCHAR(10),
    weight INTEGER,
    college VARCHAR(100),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_players_position ON players(position);
CREATE INDEX idx_players_team ON players(team);
```

#### roster_players
```sql
CREATE TABLE roster_players (
    id SERIAL PRIMARY KEY,
    roster_id INTEGER,
    league_id VARCHAR(255),
    player_id VARCHAR(50) REFERENCES players(player_id),
    is_starter BOOLEAN DEFAULT FALSE,
    slot_position VARCHAR(20), -- QB, RB, WR, TE, FLEX, BENCH, IR
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (league_id, roster_id) REFERENCES rosters(league_id, roster_id),
    UNIQUE(roster_id, league_id, player_id)
);
CREATE INDEX idx_roster_players_roster ON roster_players(roster_id, league_id);
```

#### matchups
```sql
CREATE TABLE matchups (
    id SERIAL PRIMARY KEY,
    league_id VARCHAR(255) REFERENCES leagues(league_id),
    week INTEGER,
    matchup_id INTEGER,
    roster_id INTEGER,
    points DECIMAL(10,2),
    custom_points DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (league_id, roster_id) REFERENCES rosters(league_id, roster_id),
    UNIQUE(league_id, week, roster_id)
);
CREATE INDEX idx_matchups_league_week ON matchups(league_id, week);
```

#### matchup_players
```sql
CREATE TABLE matchup_players (
    id SERIAL PRIMARY KEY,
    matchup_id INTEGER REFERENCES matchups(id),
    player_id VARCHAR(50) REFERENCES players(player_id),
    is_starter BOOLEAN,
    points DECIMAL(10,2),
    projected_points DECIMAL(10,2),
    stats JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_matchup_players_matchup ON matchup_players(matchup_id);
```

#### transactions
```sql
CREATE TABLE transactions (
    transaction_id VARCHAR(255) PRIMARY KEY,
    league_id VARCHAR(255) REFERENCES leagues(league_id),
    type VARCHAR(50), -- trade, free_agent, waiver
    status VARCHAR(50), -- complete, pending, failed
    creator_user_id VARCHAR(255) REFERENCES users(user_id),
    created BIGINT, -- Unix timestamp from API
    consenter_ids VARCHAR(255)[],
    waiver_budget JSONB,
    settings JSONB,
    leg INTEGER,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_transactions_league ON transactions(league_id);
CREATE INDEX idx_transactions_type ON transactions(type);
```

#### transaction_details
```sql
CREATE TABLE transaction_details (
    id SERIAL PRIMARY KEY,
    transaction_id VARCHAR(255) REFERENCES transactions(transaction_id),
    roster_id INTEGER,
    action VARCHAR(20), -- add, drop
    player_id VARCHAR(50) REFERENCES players(player_id),
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_transaction_details_transaction ON transaction_details(transaction_id);
```

#### drafts
```sql
CREATE TABLE drafts (
    draft_id VARCHAR(255) PRIMARY KEY,
    league_id VARCHAR(255) REFERENCES leagues(league_id),
    type VARCHAR(50), -- snake, auction, linear
    status VARCHAR(50), -- pre_draft, drafting, paused, complete
    sport VARCHAR(50),
    season VARCHAR(10),
    start_time BIGINT,
    season_type VARCHAR(50),
    slot_to_roster_id JSONB,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

#### draft_picks
```sql
CREATE TABLE draft_picks (
    pick_no SERIAL PRIMARY KEY,
    draft_id VARCHAR(255) REFERENCES drafts(draft_id),
    round INTEGER,
    draft_slot INTEGER,
    player_id VARCHAR(50) REFERENCES players(player_id),
    picked_by VARCHAR(255) REFERENCES users(user_id),
    roster_id VARCHAR(255),
    is_keeper BOOLEAN DEFAULT FALSE,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_draft_picks_draft ON draft_picks(draft_id);
```

#### traded_picks
```sql
CREATE TABLE traded_picks (
    id SERIAL PRIMARY KEY,
    league_id VARCHAR(255) REFERENCES leagues(league_id),
    season VARCHAR(10),
    round INTEGER,
    roster_id INTEGER,
    previous_owner_id INTEGER,
    owner_id INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_traded_picks_league ON traded_picks(league_id);
```

#### player_stats
```sql
CREATE TABLE player_stats (
    id SERIAL PRIMARY KEY,
    player_id VARCHAR(50) REFERENCES players(player_id),
    season VARCHAR(10),
    week INTEGER,
    game_id VARCHAR(50),
    team VARCHAR(10),
    opponent VARCHAR(10),
    stats JSONB, -- Comprehensive stats object
    fantasy_points_ppr DECIMAL(10,2),
    fantasy_points_standard DECIMAL(10,2),
    fantasy_points_half_ppr DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(player_id, season, week)
);
CREATE INDEX idx_player_stats_player_season ON player_stats(player_id, season);
```

#### sync_log
```sql
CREATE TABLE sync_log (
    id SERIAL PRIMARY KEY,
    entity_type VARCHAR(50), -- league, roster, matchup, transaction, etc
    entity_id VARCHAR(255),
    action VARCHAR(50), -- fetch, update, error
    status VARCHAR(50), -- success, failed
    details JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_sync_log_entity ON sync_log(entity_type, entity_id);
CREATE INDEX idx_sync_log_created ON sync_log(created_at);
```

## Data Synchronization Strategy

### Fetch Frequencies
- **Real-time (Every 5 minutes during games)**: Active matchups, player stats
- **Hourly**: Rosters, transactions during season
- **Daily**: League settings, users, inactive leagues
- **Weekly**: Player metadata, draft data (post-draft)
- **On-demand**: Historical data, specific league refresh

### API Integration Functions

#### PostgreSQL Functions for Data Upsert
```sql
-- Upsert user function
CREATE OR REPLACE FUNCTION upsert_user(
    p_user_id VARCHAR,
    p_username VARCHAR,
    p_display_name VARCHAR,
    p_avatar VARCHAR
) RETURNS void AS $$
BEGIN
    INSERT INTO users (user_id, username, display_name, avatar)
    VALUES (p_user_id, p_username, p_display_name, p_avatar)
    ON CONFLICT (user_id) DO UPDATE SET
        username = EXCLUDED.username,
        display_name = EXCLUDED.display_name,
        avatar = EXCLUDED.avatar,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Upsert league function
CREATE OR REPLACE FUNCTION upsert_league(
    p_league_id VARCHAR,
    p_name VARCHAR,
    p_season VARCHAR,
    p_sport VARCHAR,
    p_status VARCHAR,
    p_total_rosters INTEGER,
    p_draft_id VARCHAR,
    p_previous_league_id VARCHAR
) RETURNS void AS $$
BEGIN
    INSERT INTO leagues (
        league_id, name, season, sport, status, 
        total_rosters, draft_id, previous_league_id
    ) VALUES (
        p_league_id, p_name, p_season, p_sport, p_status,
        p_total_rosters, p_draft_id, p_previous_league_id
    )
    ON CONFLICT (league_id) DO UPDATE SET
        name = EXCLUDED.name,
        status = EXCLUDED.status,
        total_rosters = EXCLUDED.total_rosters,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;
```

## Hasura Configuration

### Environment Variables
```env
# Database
POSTGRES_DB=sleeper_db
POSTGRES_USER=sleeper_user
POSTGRES_PASSWORD=<secure_password>
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# Hasura
HASURA_GRAPHQL_DATABASE_URL=postgres://sleeper_user:<secure_password>@postgres:5432/sleeper_db
HASURA_GRAPHQL_ENABLE_CONSOLE=true
HASURA_GRAPHQL_DEV_MODE=true
HASURA_GRAPHQL_ADMIN_SECRET=<admin_secret>
HASURA_GRAPHQL_UNAUTHORIZED_ROLE=anonymous

# Sleeper API
SLEEPER_API_BASE_URL=https://api.sleeper.app/v1
PRIMARY_LEAGUE_ID=1199102384316362752
```

### Hasura Scheduled Events

#### 1. Sync Active League Data (Every 5 minutes during season)
```json
{
  "name": "sync_active_leagues",
  "webhook": "{{HASURA_ACTION_BASE_URL}}/sync-leagues",
  "schedule_at": "*/5 * * * *",
  "payload": {
    "league_ids": ["1199102384316362752"],
    "sync_type": "active"
  }
}
```

#### 2. Sync Transactions (Hourly)
```json
{
  "name": "sync_transactions",
  "webhook": "{{HASURA_ACTION_BASE_URL}}/sync-transactions",
  "schedule_at": "0 * * * *",
  "payload": {
    "league_ids": ["1199102384316362752"]
  }
}
```

#### 3. Full League Sync (Daily at 3 AM)
```json
{
  "name": "full_league_sync",
  "webhook": "{{HASURA_ACTION_BASE_URL}}/sync-full",
  "schedule_at": "0 3 * * *",
  "payload": {
    "league_ids": ["1199102384316362752"],
    "include_historical": true
  }
}
```

### Hasura Actions

#### Fetch League Data Action
```graphql
type Mutation {
  fetchLeagueData(league_id: String!): FetchLeagueDataOutput
}

type FetchLeagueDataOutput {
  success: Boolean!
  message: String
  data_fetched: LeagueDataSummary
}

type LeagueDataSummary {
  users_count: Int
  rosters_count: Int
  transactions_count: Int
  last_sync: String
}
```

## Docker Compose Configuration

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    restart: always
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  hasura:
    image: hasura/graphql-engine:v2.36.0
    restart: always
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "8080:8080"
    environment:
      HASURA_GRAPHQL_DATABASE_URL: ${HASURA_GRAPHQL_DATABASE_URL}
      HASURA_GRAPHQL_ENABLE_CONSOLE: ${HASURA_GRAPHQL_ENABLE_CONSOLE}
      HASURA_GRAPHQL_DEV_MODE: ${HASURA_GRAPHQL_DEV_MODE}
      HASURA_GRAPHQL_ADMIN_SECRET: ${HASURA_GRAPHQL_ADMIN_SECRET}
      HASURA_GRAPHQL_UNAUTHORIZED_ROLE: ${HASURA_GRAPHQL_UNAUTHORIZED_ROLE}
      HASURA_GRAPHQL_ENABLE_TELEMETRY: "false"
    volumes:
      - ./hasura/metadata:/hasura-metadata
      - ./hasura/migrations:/hasura-migrations

  sync-service:
    build: ./sync-service
    restart: always
    depends_on:
      - postgres
      - hasura
    environment:
      DATABASE_URL: ${HASURA_GRAPHQL_DATABASE_URL}
      SLEEPER_API_BASE_URL: ${SLEEPER_API_BASE_URL}
      PRIMARY_LEAGUE_ID: ${PRIMARY_LEAGUE_ID}
      HASURA_ADMIN_SECRET: ${HASURA_GRAPHQL_ADMIN_SECRET}
      HASURA_ENDPOINT: http://hasura:8080
    volumes:
      - ./sync-service:/app

volumes:
  postgres_data:
```

## Sync Service Implementation

### Python Sync Service Structure
```
sync-service/
├── Dockerfile
├── requirements.txt
├── src/
│   ├── __init__.py
│   ├── main.py
│   ├── api/
│   │   ├── __init__.py
│   │   ├── sleeper_client.py
│   │   └── endpoints.py
│   ├── database/
│   │   ├── __init__.py
│   │   ├── connection.py
│   │   └── models.py
│   ├── sync/
│   │   ├── __init__.py
│   │   ├── leagues.py
│   │   ├── rosters.py
│   │   ├── matchups.py
│   │   ├── transactions.py
│   │   └── players.py
│   └── utils/
│       ├── __init__.py
│       └── logger.py
```

### Key Sync Functions

#### League Sync
```python
async def sync_league(league_id: str):
    """
    Syncs all league data including:
    - League details and settings
    - Users in the league
    - Rosters and roster players
    - Current week matchups
    - Recent transactions
    """
    # 1. Fetch and upsert league details
    # 2. Fetch and upsert league users
    # 3. Fetch and upsert rosters
    # 4. Fetch and upsert current matchups
    # 5. Log sync operation
```

#### Player Data Sync
```python
async def sync_players():
    """
    Fetches the latest player data from Sleeper
    This should be run less frequently (weekly)
    as player metadata doesn't change often
    """
    # Fetch from https://api.sleeper.app/v1/players/nfl
    # Upsert into players table
```

## GraphQL Query Examples

### Get League Standings
```graphql
query GetLeagueStandings($league_id: String!) {
  rosters(
    where: {league_id: {_eq: $league_id}}
    order_by: [
      {wins: desc},
      {points_for: desc}
    ]
  ) {
    roster_id
    owner {
      display_name
      username
    }
    wins
    losses
    ties
    points_for
    points_against
  }
}
```

### Get Matchup Details
```graphql
query GetMatchupDetails($league_id: String!, $week: Int!) {
  matchups(
    where: {
      league_id: {_eq: $league_id},
      week: {_eq: $week}
    }
  ) {
    matchup_id
    roster {
      owner {
        display_name
      }
    }
    points
    matchup_players {
      player {
        full_name
        position
      }
      is_starter
      points
    }
  }
}
```

### Get Recent Transactions
```graphql
query GetRecentTransactions($league_id: String!, $limit: Int = 10) {
  transactions(
    where: {league_id: {_eq: $league_id}}
    order_by: {created: desc}
    limit: $limit
  ) {
    transaction_id
    type
    status
    creator {
      display_name
    }
    transaction_details {
      action
      player {
        full_name
        position
      }
    }
  }
}
```

## Setup Instructions

1. **Clone the repository**
```bash
git clone <repository-url>
cd sleeper-db
```

2. **Create environment file**
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. **Initialize database**
```bash
# Place SQL schema in init-scripts/01-schema.sql
docker-compose up -d postgres
# Wait for postgres to be ready
docker-compose exec postgres psql -U sleeper_user -d sleeper_db -f /docker-entrypoint-initdb.d/01-schema.sql
```

4. **Start Hasura**
```bash
docker-compose up -d hasura
# Access console at http://localhost:8080
```

5. **Configure Hasura**
   - Track all tables
   - Set up relationships
   - Create scheduled events
   - Configure actions

6. **Deploy sync service**
```bash
docker-compose up -d sync-service
```

7. **Initial data load**
```bash
# Trigger initial sync via Hasura console or API
curl -X POST http://localhost:8080/v1/graphql \
  -H "x-hasura-admin-secret: <admin_secret>" \
  -d '{"query": "mutation { fetchLeagueData(league_id: \"1199102384316362752\") { success message } }"}'
```

## Monitoring & Maintenance

### Health Checks
- PostgreSQL: Check connection and query performance
- Hasura: Monitor GraphQL query performance
- Sync Service: Check sync_log table for failures

### Backup Strategy
```bash
# Daily backup
pg_dump -U sleeper_user -h localhost sleeper_db > backup_$(date +%Y%m%d).sql

# Restore
psql -U sleeper_user -h localhost sleeper_db < backup_20240101.sql
```

### Performance Optimization
- Add indexes based on query patterns
- Use materialized views for complex aggregations
- Implement caching for frequently accessed data
- Monitor and optimize slow queries

## API Rate Limiting Considerations
- Sleeper API has no official rate limits but be respectful
- Implement exponential backoff for retries
- Cache responses where appropriate
- Batch API calls when possible

## Future Enhancements
1. **Analytics Dashboard**: Build a frontend to visualize league trends
2. **Predictions Engine**: Use historical data for performance predictions
3. **Multi-League Support**: Expand to track multiple leagues
4. **Real-time Updates**: WebSocket integration for live scoring
5. **Mobile App**: React Native app for mobile access
6. **Export Features**: Generate reports and exports
7. **Custom Scoring**: Support for custom scoring systems
8. **Trade Analyzer**: Evaluate trade fairness based on historical data

## Security Considerations
- Store sensitive credentials in environment variables
- Use HTTPS for all external communications
- Implement API authentication for sync endpoints
- Regular security updates for Docker images
- Audit logging for data changes
- Backup encryption for sensitive league data

## Troubleshooting

### Common Issues
1. **Sync failures**: Check sync_log table and API connectivity
2. **Missing data**: Verify API endpoints and data mappings
3. **Performance issues**: Review indexes and query optimization
4. **Hasura errors**: Check metadata consistency

### Debug Commands
```bash
# View sync logs
docker-compose logs -f sync-service

# Check database connections
docker-compose exec postgres pg_isready

# Hasura console
docker-compose exec hasura hasura-cli console

# Manual sync trigger
docker-compose exec sync-service python -m src.sync.leagues --league-id 1199102384316362752
```

## Development Workflow

### Local Development
```bash
# Start services
docker-compose up -d

# Watch logs
docker-compose logs -f

# Run tests
docker-compose exec sync-service pytest

# Apply migrations
hasura migrate apply
```

### Adding New Features
1. Update database schema
2. Create Hasura migration
3. Update sync service
4. Add GraphQL queries/mutations
5. Test end-to-end
6. Deploy with Docker

## Contact & Support
For issues or questions about this project, please create an issue in the repository or contact the maintainers.