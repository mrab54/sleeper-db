# Data Flow Diagrams & Architecture

Generated: 2025-08-24

## System Overview

```mermaid
graph TB
    subgraph "External Systems"
        SLEEPER[Sleeper API]
        CLIENTS[GraphQL Clients]
    end
    
    subgraph "Docker Container Network"
        subgraph "Sync Service"
            SCHEDULER[APScheduler]
            API_CLIENT[Sleeper API Client]
            TRANSFORMER[Data Transformer]
            DB_WRITER[Database Writer]
        end
        
        subgraph "Data Layer"
            POSTGRES[(PostgreSQL)]
            REDIS[(Redis Cache)]
        end
        
        subgraph "API Layer"
            HASURA[Hasura GraphQL]
            ACTIONS[Action Handlers]
            EVENTS[Scheduled Events]
        end
        
        subgraph "Monitoring"
            PROMETHEUS[Prometheus]
            GRAFANA[Grafana]
            LOKI[Loki Logs]
        end
    end
    
    SLEEPER -->|REST API| API_CLIENT
    EVENTS -->|Webhook| SCHEDULER
    SCHEDULER -->|Trigger| API_CLIENT
    API_CLIENT -->|Fetch Data| TRANSFORMER
    TRANSFORMER -->|Validate & Normalize| DB_WRITER
    DB_WRITER -->|Upsert| POSTGRES
    DB_WRITER -->|Cache| REDIS
    
    POSTGRES -->|Auto Schema| HASURA
    HASURA -->|GraphQL| CLIENTS
    CLIENTS -->|Mutations| ACTIONS
    ACTIONS -->|Trigger Sync| SCHEDULER
    
    SYNC_SERVICE -->|Metrics| PROMETHEUS
    PROMETHEUS -->|Visualize| GRAFANA
    SYNC_SERVICE -->|Logs| LOKI
```

## Detailed Data Flows

### 1. League Sync Flow

```mermaid
sequenceDiagram
    participant HE as Hasura Event
    participant SS as Sync Service
    participant SA as Sleeper API
    participant DT as Data Transformer
    participant PG as PostgreSQL
    participant RC as Redis Cache
    participant HS as Hasura
    participant GC as GraphQL Client
    
    HE->>SS: Scheduled Event (every 30 min)
    SS->>SS: Check last sync time
    
    alt Cache Valid
        SS->>RC: Get cached data
        RC-->>SS: Return cached response
    else Cache Invalid
        SS->>SA: GET /league/{league_id}
        SA-->>SS: League data
        SS->>SA: GET /league/{id}/users
        SA-->>SS: Users data
        SS->>SA: GET /league/{id}/rosters
        SA-->>SS: Rosters data
        
        SS->>DT: Transform to normalized structure
        DT->>DT: Validate data
        DT->>DT: Map relationships
        DT-->>SS: Normalized data
        
        SS->>PG: BEGIN TRANSACTION
        SS->>PG: CALL upsert_league()
        SS->>PG: CALL upsert_users()
        SS->>PG: CALL upsert_rosters()
        SS->>PG: INSERT sync_log
        SS->>PG: COMMIT
        
        SS->>RC: Cache response (TTL: 30 min)
    end
    
    PG-->>HS: Detect changes
    HS-->>GC: Push subscription update
```

### 2. Live Scoring Flow (Game Time)

```mermaid
sequenceDiagram
    participant HE as Hasura Event
    participant SS as Sync Service
    participant SA as Sleeper API
    participant PG as PostgreSQL
    participant HS as Hasura
    participant GC as GraphQL Client
    
    Note over HE,GC: Every 1 minute during games
    
    HE->>SS: High-frequency event
    SS->>SS: Check if game active
    
    alt Game Active
        SS->>SA: GET /league/{id}/matchups/{week}
        SA-->>SS: Current matchup data
        
        SS->>SS: Calculate point changes
        SS->>SS: Detect scoring updates
        
        SS->>PG: UPDATE matchups SET points = ?
        SS->>PG: UPDATE matchup_players SET points = ?
        
        PG-->>HS: Trigger update
        HS-->>GC: Real-time subscription update
        
        Note over GC: UI updates immediately
    else No Active Games
        SS->>SS: Skip update
        SS->>PG: Log skip event
    end
```

### 3. Transaction Processing Flow

```mermaid
sequenceDiagram
    participant HE as Hasura Event
    participant SS as Sync Service
    participant SA as Sleeper API
    participant PG as PostgreSQL
    participant NS as Notification Service
    
    Note over HE,NS: Waiver period: Wed 3-6 AM
    
    HE->>SS: Waiver check event
    SS->>SA: GET /league/{id}/transactions/{week}
    SA-->>SS: Transaction list
    
    SS->>SS: Filter new transactions
    
    loop For each new transaction
        SS->>PG: SELECT * FROM transactions WHERE id = ?
        PG-->>SS: Existing or null
        
        alt New Transaction
            SS->>PG: INSERT INTO transactions
            SS->>PG: INSERT INTO transaction_details
            
            alt Type = Trade
                SS->>PG: UPDATE rosters (both teams)
                SS->>PG: UPDATE roster_players
                SS->>NS: Send trade notification
            else Type = Waiver
                SS->>PG: UPDATE roster_players
                SS->>PG: UPDATE waiver_budget
                SS->>NS: Send waiver notification
            else Type = Free Agent
                SS->>PG: UPDATE roster_players
            end
        end
    end
    
    SS->>PG: UPDATE sync_log
```

### 4. Player Data Sync Flow

```mermaid
flowchart LR
    subgraph "Weekly Player Sync"
        START[Tuesday 2 AM] --> FETCH[Fetch All Players]
        FETCH --> SIZE{Size Check}
        SIZE -->|< 10MB| PROCESS[Process All]
        SIZE -->|> 10MB| CHUNK[Process in Chunks]
        
        CHUNK --> BATCH[Batch of 1000]
        BATCH --> UPSERT[Upsert Players]
        UPSERT --> MORE{More Batches?}
        MORE -->|Yes| BATCH
        MORE -->|No| COMPLETE
        
        PROCESS --> UPSERT2[Upsert All]
        UPSERT2 --> COMPLETE[Update Metadata]
        COMPLETE --> CACHE[Cache for 24h]
    end
```

### 5. Error Handling & Recovery Flow

```mermaid
stateDiagram-v2
    [*] --> Syncing: Start Sync
    Syncing --> FetchData: Call API
    
    FetchData --> Success: 200 OK
    FetchData --> RateLimit: 429 Error
    FetchData --> ServerError: 5xx Error
    FetchData --> NetworkError: Connection Failed
    
    RateLimit --> Backoff: Wait exponentially
    Backoff --> Retry: After delay
    
    ServerError --> Retry: Immediate retry
    NetworkError --> Retry: After 5s
    
    Retry --> FetchData: Attempt < 3
    Retry --> Failed: Attempt >= 3
    
    Success --> Transform: Process data
    Transform --> Validate: Check integrity
    
    Validate --> Store: Valid data
    Validate --> Failed: Invalid data
    
    Store --> Commit: Database write
    Commit --> [*]: Complete
    
    Failed --> DeadLetter: Log to DLQ
    DeadLetter --> Alert: Notify admin
    Alert --> [*]: Manual intervention
```

## Data Transformation Pipeline

### 1. API Response to Database Model

```python
# Transformation Pipeline Example
class DataTransformer:
    """Transform Sleeper API responses to database models"""
    
    def transform_league(self, api_data: dict) -> dict:
        """
        Input (API):
        {
            "league_id": "123",
            "name": "My League",
            "settings": {
                "playoff_week_start": 15,
                "waiver_type": 2,
                ...
            },
            "scoring_settings": {
                "pass_td": 4.0,
                ...
            }
        }
        
        Output (Database):
        {
            "league": {
                "league_id": "123",
                "name": "My League",
                ...
            },
            "league_settings": {
                "league_id": "123",
                "playoff_week_start": 15,
                ...
            },
            "league_scoring_settings": {
                "league_id": "123",
                "pass_td": 4.0,
                ...
            }
        }
        """
        return {
            "league": self.extract_league_core(api_data),
            "league_settings": self.extract_league_settings(api_data),
            "league_scoring_settings": self.extract_scoring_settings(api_data)
        }
```

### 2. Relationship Mapping

```mermaid
graph TD
    subgraph "API Structure"
        API_LEAGUE[League Object]
        API_ROSTERS[Rosters Array]
        API_USERS[Users Array]
        API_PLAYERS[Players Array in Roster]
    end
    
    subgraph "Database Structure"
        DB_LEAGUE[leagues table]
        DB_USERS[users table]
        DB_ROSTERS[rosters table]
        DB_PLAYERS[players table]
        DB_ROSTER_PLAYERS[roster_players junction]
    end
    
    API_LEAGUE -->|Extract core| DB_LEAGUE
    API_USERS -->|Normalize| DB_USERS
    API_ROSTERS -->|Extract & Link| DB_ROSTERS
    API_PLAYERS -->|Deduplicate| DB_PLAYERS
    API_ROSTERS -->|Create relationships| DB_ROSTER_PLAYERS
    
    DB_ROSTERS -->|owner_id FK| DB_USERS
    DB_ROSTER_PLAYERS -->|player_id FK| DB_PLAYERS
    DB_ROSTER_PLAYERS -->|roster_id FK| DB_ROSTERS
```

## Caching Strategy

### Cache Layers

```mermaid
graph TB
    subgraph "Cache Hierarchy"
        L1[L1: Application Memory<br/>TTL: 1 min]
        L2[L2: Redis Cache<br/>TTL: 5-60 min]
        L3[L3: PostgreSQL<br/>Persistent]
    end
    
    REQUEST[API Request] --> L1
    L1 -->|Miss| L2
    L2 -->|Miss| L3
    L3 -->|Miss| FETCH[Fetch from Sleeper]
    
    FETCH --> STORE_L3[Store in DB]
    STORE_L3 --> STORE_L2[Store in Redis]
    STORE_L2 --> STORE_L1[Store in Memory]
    STORE_L1 --> RESPONSE[Return Response]
```

### Cache Invalidation Rules

| Data Type | L1 TTL | L2 TTL | Invalidation Trigger |
|-----------|--------|--------|---------------------|
| Live Scores | 1 min | 5 min | Every update |
| Rosters | 5 min | 30 min | Transaction |
| League Settings | 30 min | 24 hours | Manual change |
| Player Metadata | 1 hour | 24 hours | Weekly sync |
| Historical Data | 24 hours | 7 days | Never |

## Concurrency & Parallelization

### Parallel Fetch Strategy

```python
async def parallel_sync_all_weeks(league_id: str):
    """Fetch all weeks in parallel for efficiency"""
    
    async with httpx.AsyncClient() as client:
        # Create tasks for all weeks
        tasks = []
        for week in range(1, 19):  # Weeks 1-18
            task = fetch_week_data(client, league_id, week)
            tasks.append(task)
        
        # Execute in parallel with concurrency limit
        semaphore = asyncio.Semaphore(5)  # Max 5 concurrent
        
        async def bounded_fetch(task):
            async with semaphore:
                return await task
        
        results = await asyncio.gather(
            *[bounded_fetch(task) for task in tasks],
            return_exceptions=True
        )
        
        # Process results
        for week, result in enumerate(results, 1):
            if isinstance(result, Exception):
                log.error(f"Week {week} failed: {result}")
            else:
                await process_week_data(week, result)
```

## Database Write Optimization

### Batch Upsert Pattern

```sql
-- Efficient batch upsert using COPY
WITH new_rosters AS (
    SELECT * FROM (VALUES
        (1, '123', 'user1', 5, 2, 0),
        (2, '123', 'user2', 4, 3, 0),
        -- ... more rows
    ) AS t(roster_id, league_id, owner_id, wins, losses, ties)
)
INSERT INTO rosters (roster_id, league_id, owner_id, wins, losses, ties)
SELECT * FROM new_rosters
ON CONFLICT (league_id, roster_id) DO UPDATE SET
    owner_id = EXCLUDED.owner_id,
    wins = EXCLUDED.wins,
    losses = EXCLUDED.losses,
    ties = EXCLUDED.ties,
    updated_at = NOW();
```

## Monitoring & Observability Points

### Key Metrics Collection Points

```mermaid
graph LR
    subgraph "Sync Service Metrics"
        M1[API Call Duration]
        M2[Transform Duration]
        M3[DB Write Duration]
        M4[Total Sync Duration]
        M5[Error Rate]
        M6[Cache Hit Rate]
    end
    
    subgraph "Business Metrics"
        B1[Records Updated/Hour]
        B2[Active Leagues]
        B3[Sync Lag]
        B4[Data Freshness]
    end
    
    subgraph "System Metrics"
        S1[CPU Usage]
        S2[Memory Usage]
        S3[Network I/O]
        S4[Database Connections]
    end
    
    M1 --> PROMETHEUS[Prometheus]
    M2 --> PROMETHEUS
    M3 --> PROMETHEUS
    M4 --> PROMETHEUS
    M5 --> PROMETHEUS
    M6 --> PROMETHEUS
    
    B1 --> PROMETHEUS
    B2 --> PROMETHEUS
    B3 --> PROMETHEUS
    B4 --> PROMETHEUS
    
    S1 --> PROMETHEUS
    S2 --> PROMETHEUS
    S3 --> PROMETHEUS
    S4 --> PROMETHEUS
    
    PROMETHEUS --> GRAFANA[Grafana Dashboards]
```

## Security & Data Privacy Flow

### API Key and Secret Management

```mermaid
sequenceDiagram
    participant ENV as Environment
    participant SS as Sync Service
    participant HS as Hasura
    participant PG as PostgreSQL
    
    Note over ENV: Secrets injected at runtime
    
    ENV->>SS: DATABASE_URL (encrypted)
    ENV->>SS: HASURA_ADMIN_SECRET
    ENV->>HS: HASURA_ADMIN_SECRET
    
    SS->>PG: Connect with credentials
    PG-->>SS: Establish secure connection
    
    HS->>PG: Connect with credentials
    PG-->>HS: Establish secure connection
    
    Note over SS,PG: All connections use SSL/TLS
```

## Conclusion

These data flow diagrams illustrate:

1. **Clear separation of concerns** - Each component has a specific responsibility
2. **Resilient error handling** - Multiple retry strategies and fallback mechanisms
3. **Efficient data processing** - Parallel fetching, batch writes, smart caching
4. **Real-time capabilities** - Live scoring updates pushed to clients
5. **Comprehensive monitoring** - Metrics collected at every critical point
6. **Scalable architecture** - Can handle increased load through horizontal scaling

The architecture is designed to be maintainable, observable, and performant while handling the complexities of syncing data from an external API to a normalized database structure.