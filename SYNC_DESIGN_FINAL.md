# Sleeper Data Sync Service - Final Design

## Overview

The sync service is the **single source of truth writer** for the database. It fetches data from the Sleeper API and updates PostgreSQL. No other service writes to the database. The sync runs on a schedule (via Hasura's cron triggers) or on-demand.

## Core Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────┐
│  Sleeper API    │────▶│ Sync Service │────▶│ PostgreSQL  │
└─────────────────┘     └──────────────┘     └─────────────┘
                              ▲                      │
                              │                      │
                    ┌─────────┴─────────┐           │
                    │  Hasura Scheduler │           │
                    └───────────────────┘           │
                                                     ▼
                                            ┌─────────────┐
                                            │   Hasura    │
                                            │  (GraphQL)  │
                                            └─────────────┘
```

## Design Principles

1. **Single Writer**: Only the sync service writes to the database
2. **Idempotent**: All operations are safely repeatable
3. **Intelligent Fetching**: Minimize API calls through smart caching and change detection
4. **Dependency Aware**: Sync entities in correct order
5. **Efficient Updates**: Only update changed data to minimize database load

## Intelligent Data Fetching Strategy

### 1. Change Detection Logic

```go
type SyncState struct {
    EntityType        string    `db:"entity_type"`         // 'league', 'roster', etc.
    EntityID          string    `db:"entity_id"`          
    LastSyncAt        time.Time `db:"last_sync_at"`
    LastKnownVersion  string    `db:"last_known_version"` // For detecting changes
    Checksum          string    `db:"checksum"`           // Hash of last known state
    NextSyncAfter     time.Time `db:"next_sync_after"`    // Intelligent scheduling
}

// Determine what needs syncing
func (s *SyncOrchestrator) DetermineSync(ctx context.Context, leagueID string) (*SyncPlan, error) {
    plan := &SyncPlan{}
    
    // Get league's last sync state
    state, err := s.db.GetSyncState(ctx, "league", leagueID)
    if err != nil || state == nil {
        // Never synced - need full sync
        plan.FullSync = true
        return plan, nil
    }
    
    // Fetch minimal league info to check for changes
    league, err := s.api.GetLeague(ctx, leagueID)
    if err != nil {
        return nil, err
    }
    
    // Smart change detection
    if league.Status != state.LastKnownStatus {
        plan.StatusChanged = true
        plan.RequiresRosterSync = true
    }
    
    if league.LastTransactionID != state.LastTransactionID {
        plan.HasNewTransactions = true
        plan.TransactionsSinceID = state.LastTransactionID
    }
    
    // Check if we're in-season and need frequent updates
    if league.Status == "in_season" {
        currentWeek := league.Settings.CurrentWeek
        
        // During games, sync more frequently
        if s.isDuringGames(currentWeek) {
            plan.SyncMatchups = true
            plan.SyncInterval = 5 * time.Minute
        } else {
            plan.SyncInterval = 1 * time.Hour
        }
    } else if league.Status == "complete" {
        // Completed leagues don't need frequent syncs
        plan.SyncInterval = 24 * time.Hour
    }
    
    return plan, nil
}
```

### 2. Dependency-Aware Sync Order

```go
type SyncOrchestrator struct {
    api      *sleeper.Client
    db       *database.DB
    logger   zerolog.Logger
    metrics  *Metrics
}

func (s *SyncOrchestrator) SyncLeague(ctx context.Context, leagueID string) error {
    // Step 1: Determine what needs syncing
    plan, err := s.DetermineSync(ctx, leagueID)
    if err != nil {
        return fmt.Errorf("determine sync: %w", err)
    }
    
    // Step 2: Execute sync in dependency order
    
    // Always sync league first (parent entity)
    league, err := s.syncLeagueData(ctx, leagueID)
    if err != nil {
        return fmt.Errorf("sync league: %w", err)
    }
    
    // Sync users (independent, can be parallel)
    eg, ctx := errgroup.WithContext(ctx)
    
    eg.Go(func() error {
        return s.syncLeagueUsers(ctx, leagueID)
    })
    
    // Only sync rosters if needed
    if plan.FullSync || plan.StatusChanged {
        eg.Go(func() error {
            return s.syncRosters(ctx, leagueID)
        })
    }
    
    if err := eg.Wait(); err != nil {
        return err
    }
    
    // Sync dependent entities (need rosters first)
    
    // Transactions (if new ones detected)
    if plan.HasNewTransactions {
        if err := s.syncIncrementalTransactions(ctx, leagueID, plan.TransactionsSinceID); err != nil {
            s.logger.Error().Err(err).Msg("sync transactions failed")
        }
    }
    
    // Matchups (if in-season)
    if league.Status == "in_season" && plan.SyncMatchups {
        if err := s.syncCurrentWeekMatchups(ctx, leagueID, league.Settings.CurrentWeek); err != nil {
            s.logger.Error().Err(err).Msg("sync matchups failed")
        }
    }
    
    // Update sync state for next run
    s.updateSyncState(ctx, leagueID, league, plan.SyncInterval)
    
    return nil
}
```

### 3. Efficient Database Updates

```go
// Use UPSERT with change detection to minimize writes
func (s *SyncOrchestrator) upsertLeague(ctx context.Context, league *sleeper.League) error {
    query := `
        INSERT INTO sleeper.leagues (
            league_id, season_id, sport_id, name, avatar, status,
            season_type, total_rosters, draft_id, previous_league_id,
            bracket_id, loser_bracket_id, last_transaction_id, metadata
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        ON CONFLICT (league_id) DO UPDATE SET
            name = EXCLUDED.name,
            avatar = EXCLUDED.avatar,
            status = EXCLUDED.status,
            last_transaction_id = EXCLUDED.last_transaction_id,
            metadata = EXCLUDED.metadata,
            updated_at = NOW()
        WHERE 
            -- Only update if something actually changed
            leagues.name IS DISTINCT FROM EXCLUDED.name OR
            leagues.avatar IS DISTINCT FROM EXCLUDED.avatar OR
            leagues.status IS DISTINCT FROM EXCLUDED.status OR
            leagues.last_transaction_id IS DISTINCT FROM EXCLUDED.last_transaction_id OR
            leagues.metadata IS DISTINCT FROM EXCLUDED.metadata
        RETURNING (xmax = 0) AS inserted, (xmax != 0) AS updated
    `
    
    var inserted, updated bool
    err := s.db.QueryRowContext(ctx, query,
        league.LeagueID, league.SeasonID, league.Sport, league.Name,
        league.Avatar, league.Status, league.SeasonType, league.TotalRosters,
        league.DraftID, league.PreviousLeagueID, league.BracketID,
        league.LoserBracketID, league.LastTransactionID, league.Metadata,
    ).Scan(&inserted, &updated)
    
    if inserted {
        s.metrics.RecordInsert("leagues")
    } else if updated {
        s.metrics.RecordUpdate("leagues")
    } else {
        s.metrics.RecordNoOp("leagues") // No changes
    }
    
    return err
}

// Batch upsert for efficiency
func (s *SyncOrchestrator) upsertRostersBatch(ctx context.Context, rosters []*sleeper.Roster) error {
    // Use COPY for initial bulk insert or pgx.Batch for upserts
    batch := &pgx.Batch{}
    
    upsertQuery := `
        INSERT INTO sleeper.rosters (
            league_id, roster_id, owner_user_id, roster_position,
            wins, losses, ties, fantasy_points_for, fantasy_points_against,
            waiver_position, waiver_budget_used, metadata
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        ON CONFLICT (league_id, roster_position) DO UPDATE SET
            owner_user_id = EXCLUDED.owner_user_id,
            wins = EXCLUDED.wins,
            losses = EXCLUDED.losses,
            ties = EXCLUDED.ties,
            fantasy_points_for = EXCLUDED.fantasy_points_for,
            fantasy_points_against = EXCLUDED.fantasy_points_against,
            waiver_position = EXCLUDED.waiver_position,
            waiver_budget_used = EXCLUDED.waiver_budget_used,
            metadata = EXCLUDED.metadata,
            updated_at = NOW()
        WHERE
            rosters.wins != EXCLUDED.wins OR
            rosters.losses != EXCLUDED.losses OR
            rosters.fantasy_points_for != EXCLUDED.fantasy_points_for
    `
    
    for _, roster := range rosters {
        batch.Queue(upsertQuery,
            roster.LeagueID, roster.RosterID, roster.OwnerID, roster.Position,
            roster.Settings.Wins, roster.Settings.Losses, roster.Settings.Ties,
            roster.Settings.PointsFor, roster.Settings.PointsAgainst,
            roster.Settings.WaiverPosition, roster.Settings.WaiverBudgetUsed,
            roster.Metadata,
        )
    }
    
    results := s.db.SendBatch(ctx, batch)
    defer results.Close()
    
    for i := 0; i < batch.Len(); i++ {
        if _, err := results.Exec(); err != nil {
            return fmt.Errorf("batch item %d: %w", i, err)
        }
    }
    
    return nil
}
```

### 4. Incremental Transaction Sync

```go
func (s *SyncOrchestrator) syncIncrementalTransactions(ctx context.Context, leagueID, sinceTransactionID string) error {
    // Get all weeks that might have new transactions
    weeks := s.getWeeksToCheck(ctx, leagueID)
    
    var allTransactions []*sleeper.Transaction
    
    for _, week := range weeks {
        transactions, err := s.api.GetTransactions(ctx, leagueID, week)
        if err != nil {
            return fmt.Errorf("fetch week %d: %w", week, err)
        }
        
        // Filter to only new transactions
        for _, tx := range transactions {
            if s.isTransactionNewer(tx.TransactionID, sinceTransactionID) {
                allTransactions = append(allTransactions, tx)
            }
        }
        
        // Stop if we've found our last known transaction
        if s.containsTransaction(transactions, sinceTransactionID) {
            break
        }
    }
    
    if len(allTransactions) == 0 {
        return nil // No new transactions
    }
    
    // Process in batches
    return s.upsertTransactionsBatch(ctx, allTransactions)
}
```

### 5. Smart Player Data Sync

```go
type PlayerSyncStrategy struct {
    db       *database.DB
    api      *sleeper.Client
    cache    *PlayerCache
}

func (p *PlayerSyncStrategy) SyncPlayers(ctx context.Context) error {
    // Players data is large (~5MB) and mostly static
    // Only sync if it's been >24 hours or we detect changes
    
    lastSync, err := p.db.GetLastPlayerSync(ctx)
    if err != nil {
        return err
    }
    
    // Check if we need full player sync
    if time.Since(lastSync) < 24*time.Hour {
        // Just sync trending players (changes frequently)
        return p.syncTrendingPlayers(ctx)
    }
    
    // Full player sync with efficient updates
    players, err := p.api.GetAllPlayers(ctx, "nfl")
    if err != nil {
        return fmt.Errorf("fetch players: %w", err)
    }
    
    // Use COPY for bulk insert with temp table
    return p.bulkUpsertPlayers(ctx, players)
}

func (p *PlayerSyncStrategy) bulkUpsertPlayers(ctx context.Context, players map[string]*sleeper.Player) error {
    // Create temp table
    _, err := p.db.Exec(ctx, `
        CREATE TEMP TABLE temp_players (LIKE sleeper.players INCLUDING ALL)
    `)
    if err != nil {
        return err
    }
    
    // Bulk copy into temp table
    copyCount, err := p.db.CopyFrom(
        ctx,
        pgx.Identifier{"temp_players"},
        []string{"player_id", "first_name", "last_name", "position", "team", /*...*/},
        pgx.CopyFromSlice(len(players), func(i int) ([]interface{}, error) {
            // Convert map to slice for COPY
            // ...
        }),
    )
    
    // Merge temp table with main table
    _, err = p.db.Exec(ctx, `
        INSERT INTO sleeper.players
        SELECT * FROM temp_players
        ON CONFLICT (player_id) DO UPDATE SET
            team = EXCLUDED.team,
            status = EXCLUDED.status,
            injury_status = EXCLUDED.injury_status,
            -- Only update fields that actually change
            updated_at = NOW()
        WHERE
            players.team IS DISTINCT FROM EXCLUDED.team OR
            players.status IS DISTINCT FROM EXCLUDED.status OR
            players.injury_status IS DISTINCT FROM EXCLUDED.injury_status
    `)
    
    return err
}
```

## Hasura Scheduler Integration

### 1. Cron Triggers Configuration

```yaml
# hasura/metadata/cron_triggers.yaml
cron_triggers:
  # Full daily sync at 3 AM
  - name: daily_full_sync
    webhook: http://sync-service:8080/sync/full
    schedule: "0 3 * * *"
    include_in_metadata: true
    payload:
      type: "full"
      entities: ["players", "leagues", "rosters", "transactions"]
    headers:
      - name: X-Hasura-Secret
        value_from_env: SYNC_WEBHOOK_SECRET
    retry_conf:
      num_retries: 3
      timeout_seconds: 3600  # 1 hour for full sync
      tolerance_seconds: 21600
      retry_interval_seconds: 60

  # Active leagues during season (every 15 minutes)
  - name: active_leagues_sync
    webhook: http://sync-service:8080/sync/active
    schedule: "*/15 * * * *"
    include_in_metadata: true
    payload:
      type: "incremental"
      entities: ["matchups", "transactions", "rosters"]
    retry_conf:
      num_retries: 2
      timeout_seconds: 300
      tolerance_seconds: 600
      retry_interval_seconds: 30

  # Player trending data (hourly)
  - name: trending_players_sync
    webhook: http://sync-service:8080/sync/trending
    schedule: "0 * * * *"
    include_in_metadata: true
    payload:
      type: "trending"
      hours: "24"
      limit: 100
```

### 2. Webhook Handler for Hasura Scheduler

```go
type SyncWebhookHandler struct {
    orchestrator *SyncOrchestrator
    logger       zerolog.Logger
}

func (h *SyncWebhookHandler) HandleScheduledSync(w http.ResponseWriter, r *http.Request) {
    // Verify webhook secret
    if r.Header.Get("X-Hasura-Secret") != os.Getenv("SYNC_WEBHOOK_SECRET") {
        w.WriteHeader(http.StatusUnauthorized)
        return
    }
    
    var payload struct {
        Type     string   `json:"type"`
        Entities []string `json:"entities"`
        Hours    string   `json:"hours,omitempty"`
        Limit    int      `json:"limit,omitempty"`
    }
    
    if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
        w.WriteHeader(http.StatusBadRequest)
        return
    }
    
    ctx := context.Background()
    
    switch payload.Type {
    case "full":
        go h.orchestrator.RunFullSync(ctx, payload.Entities)
    case "incremental":
        go h.orchestrator.RunIncrementalSync(ctx, payload.Entities)
    case "trending":
        go h.orchestrator.SyncTrendingPlayers(ctx, payload.Hours, payload.Limit)
    default:
        w.WriteHeader(http.StatusBadRequest)
        return
    }
    
    // Return immediately - sync runs in background
    w.WriteHeader(http.StatusAccepted)
    json.NewEncoder(w).Encode(map[string]string{
        "status": "accepted",
        "message": "Sync started",
    })
}
```

### 3. On-Demand Sync via Hasura Actions

```graphql
# Expose sync operations as GraphQL mutations
type Mutation {
  syncLeague(league_id: String!): SyncResult
  syncAllUserLeagues(user_id: String!, season: String!): BatchSyncResult
}

type SyncResult {
  success: Boolean!
  entities_synced: Int!
  duration_ms: Int!
  errors: [String!]
}
```

## Service Implementation

### Project Structure
```
sleeper-sync/
├── cmd/
│   └── sync/
│       └── main.go              # Entry point
├── internal/
│   ├── api/                     # Sleeper API client
│   │   ├── client.go            # HTTP client with rate limiting
│   │   ├── league.go            # League endpoints
│   │   ├── roster.go            # Roster endpoints
│   │   ├── transaction.go       # Transaction endpoints
│   │   └── player.go            # Player endpoints
│   ├── database/                # Database layer
│   │   ├── connection.go        # pgx connection pool
│   │   ├── league.go            # League operations
│   │   ├── roster.go            # Roster operations
│   │   └── batch.go             # Batch operations
│   ├── sync/                    # Sync orchestration
│   │   ├── orchestrator.go      # Main sync logic
│   │   ├── strategies.go        # Sync strategies
│   │   ├── state.go             # Sync state management
│   │   └── scheduler.go         # Scheduling logic
│   ├── webhook/                 # Webhook handlers
│   │   ├── server.go            # HTTP server
│   │   └── handlers.go          # Hasura webhooks
│   └── config/                  # Configuration
│       └── config.go
└── migrations/                  # Database migrations
```

### Key Libraries
```go
// go.mod
module github.com/yourusername/sleeper-sync

go 1.21

require (
    github.com/jackc/pgx/v5 v5.5.0           // PostgreSQL driver
    github.com/go-resty/resty/v2 v2.10.0    // HTTP client
    github.com/rs/zerolog v1.31.0           // Structured logging
    github.com/spf13/viper v1.17.0          // Configuration
    github.com/spf13/cobra v1.8.0           // CLI
    github.com/prometheus/client_golang v1.17.0  // Metrics
    golang.org/x/sync v0.5.0                // errgroup
    golang.org/x/time v0.4.0                // rate limiting
)
```

## Deployment

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o sync cmd/sync/main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata
COPY --from=builder /app/sync /usr/local/bin/
EXPOSE 8080
CMD ["sync", "server"]
```

```yaml
# docker-compose.yml
services:
  sync-service:
    build: ./sleeper-sync
    environment:
      DATABASE_URL: postgres://sleeper_user:password@postgres:5432/sleeper_db
      SLEEPER_API_URL: https://api.sleeper.app/v1
      SYNC_WEBHOOK_SECRET: ${SYNC_WEBHOOK_SECRET}
      LOG_LEVEL: info
    ports:
      - "8090:8080"  # Webhook server
      - "9090:9090"  # Metrics
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - sleeper-net
```

## Summary

This design focuses on:
1. **Intelligent fetching** - Only fetch what's needed based on detected changes
2. **Efficient updates** - Only update database rows that actually changed
3. **Scheduled execution** - Use Hasura's cron triggers for reliable scheduling
4. **Single responsibility** - Sync service is the only writer to the database
5. **Idempotent operations** - Safe to run multiple times without data corruption

The sync service is lean, focused, and efficient - it just fetches from Sleeper and updates PostgreSQL, with Hasura handling the scheduling and exposing the data via GraphQL.