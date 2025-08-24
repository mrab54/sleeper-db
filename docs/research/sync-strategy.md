# Sleeper API Data Update Patterns & Sync Strategy

Generated: 2025-08-24
League ID: 1199102384316362752

## Executive Summary

Based on comprehensive API testing and analysis of Sleeper's data update patterns, this document outlines the optimal synchronization strategy for maintaining an up-to-date normalized database.

## Key Findings from API Analysis

### Rate Limiting
- **No explicit rate limits detected** - All 18 test API calls succeeded without 429 errors
- **Average response time**: 107ms (excellent performance)
- **Max response time**: 424ms (still very responsive)
- **Recommendation**: Conservative approach with 10 requests/second max to be respectful

### Data Volume Analysis

| Entity | Count | Update Frequency | Priority |
|--------|-------|-----------------|----------|
| League Settings | 1 | Rarely (season start/settings change) | Low |
| Users | 12 | Rarely (display name/avatar) | Low |
| Rosters | 12 | Frequently (during waivers/trades) | High |
| Matchups/Week | 12 | Real-time during games | Critical |
| Transactions/Week | 0-208 | Burst during waivers | High |
| Players | ~5000 | Weekly (injuries/status) | Medium |
| Draft Picks | 36 | Once (post-draft) | Low |

## Update Pattern Analysis

### 1. Game Day Patterns (Critical Updates)

**Sunday Game Windows:**
- Early Games: 1:00 PM - 4:00 PM EST
- Late Games: 4:25 PM - 7:30 PM EST
- Sunday Night: 8:20 PM - 11:30 PM EST

**Other Game Windows:**
- Monday Night: 8:15 PM - 11:30 PM EST
- Thursday Night: 8:15 PM - 11:30 PM EST

**Update Requirements During Games:**
```yaml
during_games:
  matchup_sync:
    frequency: 5_minutes
    endpoints:
      - /league/{id}/matchups/{week}
    data_changes:
      - points (live scoring)
      - players_points (individual scores)
      - custom_points (if applicable)
  
  roster_sync:
    frequency: 30_minutes  # For injury/inactive updates
    endpoints:
      - /league/{id}/rosters
```

### 2. Waiver Period Patterns

**Standard Waiver Timeline:**
- Tuesday 11:59 PM: Waiver period begins
- Wednesday 3:00 AM - 6:00 AM: Waivers process (varies by league)
- Wednesday 6:00 AM: Free agency opens

**Update Requirements During Waivers:**
```yaml
waiver_period:
  pre_waivers:
    tuesday_11pm:
      - snapshot_rosters  # Capture pre-waiver state
      - check_waiver_claims
  
  processing:
    wednesday_3am_to_6am:
      frequency: 10_minutes
      endpoints:
        - /league/{id}/transactions/{week}
        - /league/{id}/rosters
      expected_changes:
        - new transactions (type: waiver)
        - roster.players arrays updated
        - waiver_budget_used incremented
  
  post_waivers:
    wednesday_6am:
      - full_roster_sync
      - transaction_reconciliation
      - send_notifications
```

### 3. Trade Patterns

**Trade Activity Peaks:**
- Tuesday evenings (pre-waiver)
- Saturday afternoons (pre-Sunday games)
- Trade deadline week (high volume)

**Update Requirements:**
```yaml
trade_monitoring:
  frequency: 15_minutes  # During active hours
  endpoints:
    - /league/{id}/transactions/{week}
  detection:
    - type: "trade"
    - status: "complete"
  cascade_updates:
    - affected_rosters
    - traded_picks (if dynasty)
```

### 4. Off-Season Patterns

**Off-Season Events:**
- Draft: One-time event, heavy activity
- Keeper declarations: Specific deadline
- League renewal: Settings may change

```yaml
off_season:
  draft_day:
    frequency: 1_minute
    endpoints:
      - /draft/{id}/picks
      - /league/{id}/rosters
  
  regular_sync:
    frequency: daily
    time: 3:00_AM
```

## Optimized Sync Strategy

### Sync Tiers

#### Tier 1: Critical (Real-time)
**Frequency**: 5 minutes during games
**Scope**: Active matchups only
```python
CRITICAL_SYNC = {
    "active_hours": {
        "sunday": [(13, 0), (23, 30)],    # 1 PM - 11:30 PM
        "monday": [(20, 15), (23, 30)],   # 8:15 PM - 11:30 PM
        "thursday": [(20, 15), (23, 30)]  # 8:15 PM - 11:30 PM
    },
    "endpoints": [
        "/league/{league_id}/matchups/{current_week}"
    ],
    "frequency_minutes": 5
}
```

#### Tier 2: High Priority
**Frequency**: 30 minutes (active season), 2 hours (off-season)
**Scope**: Rosters and recent transactions
```python
HIGH_PRIORITY_SYNC = {
    "season": {
        "frequency_minutes": 30,
        "endpoints": [
            "/league/{league_id}/rosters",
            "/league/{league_id}/transactions/{current_week}"
        ]
    },
    "off_season": {
        "frequency_minutes": 120,
        "endpoints": [
            "/league/{league_id}/rosters"
        ]
    }
}
```

#### Tier 3: Regular
**Frequency**: Daily at 3 AM
**Scope**: Full league data
```python
REGULAR_SYNC = {
    "schedule": "0 3 * * *",  # Cron: 3 AM daily
    "endpoints": [
        "/league/{league_id}",
        "/league/{league_id}/users",
        "/league/{league_id}/rosters",
        "/league/{league_id}/matchups/{all_weeks}",
        "/league/{league_id}/transactions/{all_weeks}",
        "/league/{league_id}/traded_picks"
    ]
}
```

#### Tier 4: Weekly
**Frequency**: Tuesday at 2 AM
**Scope**: Player metadata
```python
WEEKLY_SYNC = {
    "schedule": "0 2 * * 2",  # Cron: Tuesday 2 AM
    "endpoints": [
        "/players/nfl",  # Full player database
        "/state/nfl"     # League state/week
    ]
}
```

### Smart Sync Optimizations

#### 1. Change Detection
```python
class ChangeDetector:
    def __init__(self):
        self.checksums = {}
    
    def has_changed(self, endpoint: str, data: dict) -> bool:
        """Detect if data has changed using checksums"""
        new_checksum = hashlib.md5(
            json.dumps(data, sort_keys=True).encode()
        ).hexdigest()
        
        if endpoint not in self.checksums:
            self.checksums[endpoint] = new_checksum
            return True
        
        changed = self.checksums[endpoint] != new_checksum
        if changed:
            self.checksums[endpoint] = new_checksum
        return changed
```

#### 2. Incremental Updates
```python
class IncrementalSync:
    def sync_transactions(self, league_id: str, week: int):
        """Only fetch new transactions since last sync"""
        last_sync = self.get_last_sync_time(league_id, week)
        transactions = self.api.get_transactions(league_id, week)
        
        new_transactions = [
            t for t in transactions 
            if t['created'] > last_sync
        ]
        
        if new_transactions:
            self.process_transactions(new_transactions)
            self.update_last_sync_time(league_id, week)
```

#### 3. Batch Processing
```python
class BatchProcessor:
    async def sync_all_weeks(self, league_id: str):
        """Fetch all weeks in parallel"""
        tasks = []
        for week in range(1, 19):  # Regular season + playoffs
            task = self.fetch_week_data(league_id, week)
            tasks.append(task)
        
        results = await asyncio.gather(*tasks)
        return self.process_batch_results(results)
```

### Conflict Resolution Strategy

#### 1. Last Write Wins (LWW)
For most entities, use timestamp-based conflict resolution:
```sql
UPDATE rosters 
SET players = $1, updated_at = NOW()
WHERE league_id = $2 AND roster_id = $3
AND updated_at < $4;  -- Only update if our data is newer
```

#### 2. Merge Strategy for Arrays
For player arrays, use set-based merging:
```python
def merge_roster_players(db_players: list, api_players: list) -> list:
    """Merge player lists, preserving adds and removes"""
    # Use API as source of truth for active rosters
    return api_players  # During season, API is authoritative
```

#### 3. Transaction Ordering
Maintain transaction order using created timestamp:
```sql
INSERT INTO transactions (transaction_id, created, ...)
VALUES ($1, $2, ...)
ON CONFLICT (transaction_id) DO NOTHING;  -- Transactions are immutable
```

## Performance Optimization

### 1. Connection Pooling
```python
HTTP_POOL_CONFIG = {
    "max_connections": 20,
    "max_keepalive_connections": 10,
    "keepalive_expiry": 30,  # seconds
    "timeout": httpx.Timeout(10.0, connect=5.0)
}
```

### 2. Caching Strategy
```python
CACHE_CONFIG = {
    "players": {
        "ttl": 86400,  # 24 hours
        "strategy": "write-through"
    },
    "league_settings": {
        "ttl": 3600,  # 1 hour
        "strategy": "write-through"
    },
    "live_scores": {
        "ttl": 60,  # 1 minute
        "strategy": "write-aside"
    }
}
```

### 3. Database Optimization
```sql
-- Partial indexes for active data
CREATE INDEX idx_matchups_current_week 
ON matchups(league_id, week) 
WHERE week = (SELECT week FROM nfl_state);

-- Cluster frequently accessed tables
CLUSTER rosters USING idx_rosters_league;
```

## Monitoring & Alerting

### Key Metrics to Track
```yaml
metrics:
  sync_lag:
    description: Time since last successful sync
    threshold: 15_minutes
    alert: warning
  
  api_errors:
    description: Count of API errors in last hour
    threshold: 10
    alert: critical
  
  data_staleness:
    description: Age of newest data point
    threshold: 30_minutes
    alert: warning
  
  sync_duration:
    description: Time to complete full sync
    threshold: 60_seconds
    alert: warning
```

### Health Checks
```python
class SyncHealthCheck:
    async def check_sync_health(self) -> dict:
        return {
            "last_successful_sync": self.get_last_sync_time(),
            "pending_syncs": self.get_pending_sync_count(),
            "error_rate": self.calculate_error_rate(),
            "api_latency": self.measure_api_latency(),
            "data_freshness": self.check_data_freshness()
        }
```

## Special Considerations

### 1. NFL Schedule Variations
- **Bye Weeks**: No games for specific teams (weeks 5-14)
- **International Games**: Earlier start times (9:30 AM EST)
- **Flex Scheduling**: Sunday night games may change (weeks 11-17)
- **Playoffs**: Different matchup structure

### 2. League-Specific Settings
```python
LEAGUE_SPECIFIC_SYNC = {
    "waiver_type": {
        "FAAB": {"sync_budget": True},
        "Rolling": {"sync_priority": True}
    },
    "scoring_type": {
        "PPR": {"decimal_precision": 2},
        "Standard": {"decimal_precision": 0}
    }
}
```

### 3. Error Recovery
```python
class SyncErrorRecovery:
    def __init__(self):
        self.retry_config = {
            "max_retries": 3,
            "backoff_factor": 2,
            "max_backoff": 60
        }
    
    async def sync_with_retry(self, sync_func, *args):
        for attempt in range(self.retry_config["max_retries"]):
            try:
                return await sync_func(*args)
            except Exception as e:
                wait_time = min(
                    self.retry_config["backoff_factor"] ** attempt,
                    self.retry_config["max_backoff"]
                )
                await asyncio.sleep(wait_time)
        
        # Failed after retries - log to dead letter queue
        await self.dead_letter_queue.add(sync_func.__name__, args)
```

## Implementation Priorities

### Phase 1: Core Sync (Week 1)
1. Implement Tier 3 (Daily full sync)
2. Basic change detection
3. Error handling

### Phase 2: Real-time (Week 2)
1. Implement Tier 1 (Game-time sync)
2. WebSocket consideration for future
3. Performance optimization

### Phase 3: Intelligence (Week 3)
1. Smart sync with change detection
2. Incremental updates
3. Advanced caching

### Phase 4: Monitoring (Week 4)
1. Metrics collection
2. Health checks
3. Alerting system

## Conclusion

The sync strategy prioritizes:
1. **Data Freshness**: Real-time updates during critical periods
2. **Efficiency**: Smart change detection and incremental updates
3. **Reliability**: Comprehensive error handling and recovery
4. **Scalability**: Designed to handle multiple leagues in future

The absence of rate limiting from Sleeper API allows for aggressive syncing during game times while being respectful during off-peak hours.