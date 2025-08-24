# Sleeper API Webhook & Real-time Capabilities Analysis

Generated: 2025-08-24

## Executive Summary

**Sleeper API does not support webhooks, WebSockets, or any push-based real-time notifications.** The API is designed as a read-only REST API that requires polling for data updates. This analysis documents the findings and recommends alternative strategies for achieving near real-time data synchronization.

## Key Findings

### 1. No Webhook Support
- ❌ No webhook endpoints available
- ❌ No event-driven notifications
- ❌ No push mechanisms for data changes
- ✅ Pure REST API with polling-based access

### 2. No WebSocket Support
- ❌ No WebSocket endpoints for real-time streaming
- ❌ No Server-Sent Events (SSE)
- ❌ No long-polling support
- ✅ Standard HTTP request/response only

### 3. API Characteristics
- **Authentication**: None required (completely open)
- **Rate Limiting**: Soft limit of 1000 requests/minute
- **Access Model**: Read-only
- **Data Format**: JSON responses
- **Availability**: High (no reported outages)

## Alternative Strategies for Real-time Data

### Strategy 1: Aggressive Polling (Recommended)

Given Sleeper's generous rate limits, we can implement aggressive polling during critical periods:

```python
class AdaptivePoller:
    """Adaptive polling based on game state and time"""
    
    def get_polling_interval(self) -> int:
        """Returns polling interval in seconds"""
        current_time = datetime.now()
        day = current_time.strftime('%A')
        hour = current_time.hour
        
        # During active games
        if self.is_game_active():
            return 60  # 1 minute during games
        
        # During waiver processing
        if day == 'Wednesday' and 3 <= hour < 6:
            return 300  # 5 minutes during waivers
        
        # Regular season hours
        if self.is_season_active():
            return 1800  # 30 minutes default
        
        # Off-season
        return 7200  # 2 hours off-season
```

### Strategy 2: Event Simulation Layer

Create an event simulation layer that converts polling results into events:

```python
class EventSimulator:
    """Simulates webhook events from polling data"""
    
    def __init__(self):
        self.previous_state = {}
        self.event_handlers = {}
    
    async def poll_and_emit(self, endpoint: str):
        """Poll endpoint and emit events for changes"""
        current_data = await self.fetch_data(endpoint)
        
        if endpoint not in self.previous_state:
            self.previous_state[endpoint] = current_data
            await self.emit_event('initial_sync', current_data)
            return
        
        changes = self.detect_changes(
            self.previous_state[endpoint], 
            current_data
        )
        
        for change in changes:
            await self.emit_event(change.type, change.data)
        
        self.previous_state[endpoint] = current_data
    
    def detect_changes(self, old_data, new_data):
        """Detect specific changes between states"""
        changes = []
        
        # Example: Detect roster changes
        if 'rosters' in old_data:
            for old_roster, new_roster in zip(old_data['rosters'], new_data['rosters']):
                if old_roster['players'] != new_roster['players']:
                    changes.append(Change(
                        type='roster_update',
                        data={'roster_id': new_roster['roster_id'], 
                              'changes': self.diff_players(old_roster, new_roster)}
                    ))
        
        return changes
```

### Strategy 3: Hasura Scheduled Events as Webhook Replacement

Use Hasura's scheduled events to simulate webhook behavior:

```yaml
# Hasura Scheduled Event Configuration
type: create_scheduled_event
args:
  name: sync_live_scores
  webhook: http://sync-service:8000/sync/live-scores
  schedule_type: cron
  cron_schedule: "*/1 * * * *"  # Every minute during games
  payload:
    action: "sync_live_scores"
    league_id: "1199102384316362752"
  retry_conf:
    num_retries: 3
    retry_interval_seconds: 10
```

### Strategy 4: GraphQL Subscriptions for Client Updates

While we can't get real-time from Sleeper, we can provide real-time to our clients:

```graphql
# Hasura Subscription
subscription LiveScores($league_id: String!) {
  matchups(
    where: {
      league_id: {_eq: $league_id},
      week: {_eq: current_week}
    }
  ) {
    roster_id
    points
    updated_at
  }
}
```

## Polling Optimization Techniques

### 1. Intelligent Cache Invalidation

```python
class CacheStrategy:
    def __init__(self):
        self.cache_rules = {
            'players': {'ttl': 86400, 'invalidate_on': ['week_change']},
            'league_settings': {'ttl': 3600, 'invalidate_on': ['setting_change']},
            'rosters': {'ttl': 300, 'invalidate_on': ['transaction']},
            'live_scores': {'ttl': 60, 'invalidate_on': ['always']}
        }
    
    def should_refetch(self, entity_type: str, last_fetch: datetime) -> bool:
        """Determine if cache should be invalidated"""
        rule = self.cache_rules.get(entity_type)
        if not rule:
            return True
        
        age = (datetime.now() - last_fetch).seconds
        return age > rule['ttl']
```

### 2. Batch Request Optimization

```python
async def batch_fetch_all_weeks(league_id: str):
    """Fetch all weeks in parallel to minimize total time"""
    async with httpx.AsyncClient() as client:
        tasks = []
        for week in range(1, 19):
            task = client.get(f"{BASE_URL}/league/{league_id}/matchups/{week}")
            tasks.append(task)
        
        responses = await asyncio.gather(*tasks)
        return [r.json() for r in responses if r.status_code == 200]
```

### 3. Delta Sync Implementation

```python
class DeltaSync:
    """Only sync what has changed"""
    
    def __init__(self):
        self.checksums = {}
    
    def compute_checksum(self, data: dict) -> str:
        """Compute checksum for data"""
        return hashlib.sha256(
            json.dumps(data, sort_keys=True).encode()
        ).hexdigest()
    
    async def sync_if_changed(self, endpoint: str, processor):
        """Only process if data has changed"""
        data = await self.fetch(endpoint)
        checksum = self.compute_checksum(data)
        
        if self.checksums.get(endpoint) != checksum:
            await processor(data)
            self.checksums[endpoint] = checksum
            return True
        return False
```

## Implementation Recommendations

### 1. Architecture Decision
**Use Polling-Based Architecture** with the following components:
- Adaptive polling intervals based on game state
- Event simulation layer for webhook-like behavior
- Hasura scheduled events for orchestration
- GraphQL subscriptions for client real-time updates

### 2. Polling Schedule

| Period | Interval | Justification |
|--------|----------|---------------|
| Game Time | 1 minute | Near real-time scoring |
| Game Day (non-game) | 15 minutes | Roster/transaction updates |
| Weekday (active season) | 30 minutes | Regular updates |
| Waiver Processing | 5 minutes | Catch waiver claims |
| Off-season | 2 hours | Minimal activity |

### 3. Performance Targets
- **Data Freshness**: ≤ 1 minute during games
- **API Calls**: < 500/minute (50% of limit)
- **Cache Hit Rate**: > 80% for static data
- **Sync Duration**: < 30 seconds for full sync

## Risk Mitigation

### 1. Rate Limit Protection
```python
class RateLimiter:
    def __init__(self, max_per_minute=500):
        self.max_per_minute = max_per_minute
        self.calls = deque()
    
    async def acquire(self):
        """Wait if necessary to respect rate limit"""
        now = time.time()
        # Remove calls older than 1 minute
        while self.calls and self.calls[0] < now - 60:
            self.calls.popleft()
        
        if len(self.calls) >= self.max_per_minute:
            sleep_time = 60 - (now - self.calls[0])
            await asyncio.sleep(sleep_time)
        
        self.calls.append(now)
```

### 2. Failover Strategy
- Primary: Direct API polling
- Secondary: Cached data with staleness indicator
- Tertiary: Historical data with warning

### 3. Monitoring
```yaml
alerts:
  - name: high_polling_latency
    condition: avg(polling_duration) > 5s
    severity: warning
  
  - name: missed_poll_window
    condition: time_since_last_poll > expected_interval * 2
    severity: critical
  
  - name: approaching_rate_limit
    condition: api_calls_per_minute > 800
    severity: warning
```

## Conclusion

While Sleeper API's lack of webhook support requires a polling-based architecture, their generous rate limits and reliable API make it feasible to achieve near real-time data synchronization. The recommended approach combines:

1. **Adaptive polling** for optimal resource usage
2. **Event simulation** for webhook-like programming model
3. **Intelligent caching** to minimize API calls
4. **Hasura integration** for scheduling and client real-time features

This architecture provides a robust solution that balances data freshness with API efficiency, while maintaining the flexibility to adapt if Sleeper adds webhook support in the future.