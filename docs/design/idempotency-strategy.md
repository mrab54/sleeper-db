# Idempotency Strategy Design

Generated: 2025-08-24

## Executive Summary

This document outlines the comprehensive idempotency strategy for the Sleeper database sync service. All sync operations are designed to be safely repeatable without causing data corruption, duplicates, or inconsistencies. This ensures system reliability during retries, failures, and concurrent operations.

## Core Principles

1. **Every sync operation must be idempotent** - Running the same sync multiple times produces the same result
2. **Use database constraints as safety net** - UNIQUE constraints prevent duplicates
3. **Leverage UPSERT patterns** - INSERT ... ON CONFLICT for all write operations
4. **Immutable data preferred** - Transactions and historical data are never modified
5. **Checksums for change detection** - Only process data that has actually changed
6. **Transaction boundaries** - Atomic operations to maintain consistency

## Idempotency Patterns by Entity Type

### 1. League Data (Mostly Static)

```python
class LeagueIdempotentSync:
    """League data rarely changes - optimize for minimal writes"""
    
    async def sync_league(self, league_id: str) -> SyncResult:
        # Generate deterministic request ID
        request_id = f"league_{league_id}_{datetime.now().strftime('%Y%m%d%H')}"
        
        # Check if already processed
        if await self.is_already_processed(request_id):
            return SyncResult(status="skipped", message="Already processed")
        
        # Fetch and checksum
        league_data = await self.api.get_league(league_id)
        checksum = self.calculate_checksum(league_data)
        
        # Compare with stored checksum
        stored_checksum = await self.db.get_checksum("league", league_id)
        if checksum == stored_checksum:
            await self.mark_processed(request_id)
            return SyncResult(status="unchanged", records_updated=0)
        
        # Perform idempotent upsert
        async with self.db.transaction() as tx:
            await tx.execute("""
                INSERT INTO leagues (league_id, name, season, status, metadata)
                VALUES ($1, $2, $3, $4, $5)
                ON CONFLICT (league_id) DO UPDATE SET
                    name = EXCLUDED.name,
                    season = EXCLUDED.season,
                    status = EXCLUDED.status,
                    metadata = EXCLUDED.metadata,
                    updated_at = NOW()
                WHERE leagues.updated_at < NOW() - INTERVAL '1 minute'
            """, league_data)
            
            # Store new checksum
            await tx.execute("""
                INSERT INTO api_cache (cache_key, checksum, endpoint)
                VALUES ($1, $2, $3)
                ON CONFLICT (cache_key) DO UPDATE SET
                    checksum = EXCLUDED.checksum,
                    accessed_at = NOW()
            """, f"league_{league_id}", checksum, f"/league/{league_id}")
            
            # Mark request as processed
            await self.mark_processed(request_id, tx)
        
        return SyncResult(status="updated", records_updated=1)
```

### 2. Roster Data (Frequently Changing)

```python
class RosterIdempotentSync:
    """Rosters change frequently - use version tracking"""
    
    async def sync_rosters(self, league_id: str) -> SyncResult:
        rosters = await self.api.get_rosters(league_id)
        updated_count = 0
        
        async with self.db.transaction() as tx:
            for roster in rosters:
                # Create roster fingerprint
                fingerprint = self.create_roster_fingerprint(roster)
                
                # Check if fingerprint exists
                existing = await tx.fetchrow("""
                    SELECT fingerprint, roster_id 
                    FROM roster_versions 
                    WHERE league_id = $1 AND roster_id = $2
                    ORDER BY created_at DESC 
                    LIMIT 1
                """, league_id, roster['roster_id'])
                
                if not existing or existing['fingerprint'] != fingerprint:
                    # Roster has changed - update
                    await tx.execute("""
                        INSERT INTO rosters (
                            league_id, roster_id, owner_id, 
                            wins, losses, ties, points_for, players
                        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                        ON CONFLICT (league_id, roster_id) DO UPDATE SET
                            owner_id = EXCLUDED.owner_id,
                            wins = EXCLUDED.wins,
                            losses = EXCLUDED.losses,
                            ties = EXCLUDED.ties,
                            points_for = EXCLUDED.points_for,
                            players = EXCLUDED.players,
                            updated_at = NOW()
                    """, league_id, roster['roster_id'], roster['owner_id'],
                        roster['settings']['wins'], roster['settings']['losses'],
                        roster['settings']['ties'], roster['settings']['fpts'],
                        Json(roster['players']))
                    
                    # Store version
                    await tx.execute("""
                        INSERT INTO roster_versions (
                            league_id, roster_id, fingerprint, data
                        ) VALUES ($1, $2, $3, $4)
                    """, league_id, roster['roster_id'], fingerprint, Json(roster))
                    
                    updated_count += 1
                    
                # Update roster players idempotently
                await self.sync_roster_players(tx, league_id, roster)
        
        return SyncResult(status="success", records_updated=updated_count)
    
    def create_roster_fingerprint(self, roster: dict) -> str:
        """Create deterministic fingerprint of roster state"""
        # Sort players for consistent hashing
        players = sorted(roster.get('players', []))
        fingerprint_data = {
            'owner_id': roster.get('owner_id'),
            'players': players,
            'wins': roster.get('settings', {}).get('wins', 0),
            'losses': roster.get('settings', {}).get('losses', 0)
        }
        return hashlib.sha256(
            json.dumps(fingerprint_data, sort_keys=True).encode()
        ).hexdigest()
```

### 3. Transaction Data (Immutable)

```python
class TransactionIdempotentSync:
    """Transactions are immutable - only insert if not exists"""
    
    async def sync_transactions(self, league_id: str, week: int) -> SyncResult:
        transactions = await self.api.get_transactions(league_id, week)
        inserted_count = 0
        
        async with self.db.transaction() as tx:
            for trans in transactions:
                # Transactions have unique IDs - simple idempotency
                result = await tx.fetchval("""
                    INSERT INTO transactions (
                        transaction_id, league_id, type, status,
                        creator_user_id, created, roster_ids
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7)
                    ON CONFLICT (transaction_id) DO NOTHING
                    RETURNING transaction_id
                """, trans['transaction_id'], league_id, trans['type'],
                    trans['status'], trans['creator'], trans['created'],
                    trans.get('roster_ids', []))
                
                if result:  # New transaction inserted
                    inserted_count += 1
                    
                    # Insert transaction details (also idempotent)
                    for add in trans.get('adds', {}).items():
                        await tx.execute("""
                            INSERT INTO transaction_details (
                                transaction_id, roster_id, action, player_id
                            ) VALUES ($1, $2, 'add', $3)
                            ON CONFLICT DO NOTHING
                        """, trans['transaction_id'], trans['roster_ids'][0], add[0])
                    
                    for drop in trans.get('drops', {}).items():
                        await tx.execute("""
                            INSERT INTO transaction_details (
                                transaction_id, roster_id, action, player_id
                            ) VALUES ($1, $2, 'drop', $3)
                            ON CONFLICT DO NOTHING
                        """, trans['transaction_id'], trans['roster_ids'][0], drop[0])
        
        return SyncResult(status="success", records_inserted=inserted_count)
```

### 4. Live Scoring (Time-Sensitive)

```python
class LiveScoringIdempotentSync:
    """Live scores need special handling for concurrent updates"""
    
    async def sync_live_scores(self, league_id: str, week: int) -> SyncResult:
        matchups = await self.api.get_matchups(league_id, week)
        
        async with self.db.transaction() as tx:
            # Lock the matchups for this week to prevent concurrent updates
            await tx.execute("""
                SELECT * FROM matchups 
                WHERE league_id = $1 AND week = $2 
                FOR UPDATE
            """, league_id, week)
            
            for matchup in matchups:
                # Use optimistic locking with timestamp
                result = await tx.fetchrow("""
                    UPDATE matchups SET
                        points = $3,
                        updated_at = NOW()
                    WHERE league_id = $1 
                        AND week = $2 
                        AND roster_id = $4
                        AND (points != $3 OR updated_at < NOW() - INTERVAL '30 seconds')
                    RETURNING id, points
                """, league_id, week, matchup['points'], matchup['roster_id'])
                
                if result:
                    # Score changed - update player points
                    await self.update_player_points(tx, result['id'], matchup)
        
        return SyncResult(status="success")
    
    async def update_player_points(self, tx, matchup_id: int, matchup_data: dict):
        """Update player points with conflict resolution"""
        players_points = matchup_data.get('players_points', {})
        
        for player_id, points in players_points.items():
            await tx.execute("""
                INSERT INTO matchup_players (matchup_id, player_id, points)
                VALUES ($1, $2, $3)
                ON CONFLICT (matchup_id, player_id) DO UPDATE SET
                    points = GREATEST(
                        EXCLUDED.points, 
                        matchup_players.points
                    ),  -- Take higher score (stat corrections)
                    updated_at = NOW()
            """, matchup_id, player_id, points)
```

## Concurrency Control Strategies

### 1. Optimistic Locking

```sql
-- Use version numbers for high-contention entities
UPDATE rosters SET
    wins = $1,
    losses = $2,
    version = version + 1,
    updated_at = NOW()
WHERE league_id = $3 
    AND roster_id = $4 
    AND version = $5  -- Expected version
RETURNING version;
```

### 2. Advisory Locks

```python
async def sync_with_advisory_lock(self, league_id: str):
    """Use PostgreSQL advisory locks for league-level operations"""
    lock_id = hash(league_id) % 2147483647  # Convert to int for pg_advisory_lock
    
    async with self.db.transaction() as tx:
        # Acquire advisory lock
        await tx.execute("SELECT pg_advisory_xact_lock($1)", lock_id)
        
        # Perform sync operations
        await self.sync_league_data(tx, league_id)
        
        # Lock automatically released at transaction end
```

### 3. Distributed Locking with Redis

```python
class DistributedLock:
    """Redis-based distributed lock for multi-instance deployments"""
    
    async def acquire_lock(self, key: str, ttl: int = 60) -> bool:
        """Acquire lock with automatic expiration"""
        lock_key = f"lock:{key}"
        lock_value = str(uuid.uuid4())
        
        # SET NX EX - atomic operation
        acquired = await self.redis.set(
            lock_key, 
            lock_value,
            nx=True,  # Only set if not exists
            ex=ttl    # Expire after TTL seconds
        )
        
        if acquired:
            self.lock_values[key] = lock_value
            return True
        return False
    
    async def release_lock(self, key: str):
        """Safely release lock only if we own it"""
        lock_key = f"lock:{key}"
        lock_value = self.lock_values.get(key)
        
        if lock_value:
            # Lua script for atomic check-and-delete
            lua_script = """
                if redis.call("get", KEYS[1]) == ARGV[1] then
                    return redis.call("del", KEYS[1])
                else
                    return 0
                end
            """
            await self.redis.eval(lua_script, 1, lock_key, lock_value)
```

## Handling Edge Cases

### 1. Partial Failures

```python
class PartialFailureHandler:
    """Handle partial sync failures gracefully"""
    
    async def sync_with_checkpoints(self, league_id: str):
        checkpoint = await self.get_checkpoint(league_id)
        
        steps = [
            ('league', self.sync_league),
            ('users', self.sync_users),
            ('rosters', self.sync_rosters),
            ('matchups', self.sync_matchups),
            ('transactions', self.sync_transactions)
        ]
        
        for step_name, step_func in steps:
            if checkpoint and step_name in checkpoint['completed']:
                continue  # Skip already completed steps
            
            try:
                await step_func(league_id)
                await self.save_checkpoint(league_id, step_name)
            except Exception as e:
                # Log error but continue with other steps
                await self.log_partial_failure(league_id, step_name, e)
                # Decide whether to continue or abort
                if self.is_critical_step(step_name):
                    raise
```

### 2. Duplicate Detection

```python
class DuplicateDetector:
    """Detect and handle duplicate sync requests"""
    
    def __init__(self):
        self.recent_requests = TTLCache(maxsize=1000, ttl=300)  # 5 min cache
    
    async def is_duplicate_request(self, request_id: str) -> bool:
        """Check if request was recently processed"""
        # Check memory cache first
        if request_id in self.recent_requests:
            return True
        
        # Check database for recent processing
        result = await self.db.fetchval("""
            SELECT EXISTS(
                SELECT 1 FROM sync_log 
                WHERE entity_id = $1 
                    AND created_at > NOW() - INTERVAL '5 minutes'
                    AND status = 'success'
            )
        """, request_id)
        
        if result:
            self.recent_requests[request_id] = True
            return True
        
        return False
```

### 3. Data Consistency Validation

```python
class ConsistencyValidator:
    """Validate data consistency after sync operations"""
    
    async def validate_roster_consistency(self, league_id: str):
        """Ensure roster data is consistent"""
        
        # Check player counts
        invalid_rosters = await self.db.fetch("""
            SELECT r.roster_id, 
                   COUNT(rp.player_id) as player_count,
                   array_length(r.players, 1) as expected_count
            FROM rosters r
            LEFT JOIN roster_players rp ON 
                r.league_id = rp.league_id AND 
                r.roster_id = rp.roster_id
            WHERE r.league_id = $1
            GROUP BY r.roster_id, r.players
            HAVING COUNT(rp.player_id) != array_length(r.players, 1)
        """, league_id)
        
        if invalid_rosters:
            # Trigger re-sync for invalid rosters
            for roster in invalid_rosters:
                await self.queue_resync('roster', roster['roster_id'])
        
        # Check for orphaned players
        await self.db.execute("""
            DELETE FROM roster_players rp
            WHERE NOT EXISTS (
                SELECT 1 FROM rosters r 
                WHERE r.league_id = rp.league_id 
                    AND r.roster_id = rp.roster_id
            )
        """)
```

## Testing Idempotency

### Test Scenarios

```python
import pytest
from unittest.mock import Mock, patch

class TestIdempotency:
    
    @pytest.mark.asyncio
    async def test_double_sync_produces_same_result(self):
        """Running sync twice should produce identical database state"""
        league_id = "test_league"
        
        # First sync
        result1 = await sync_league(league_id)
        state1 = await get_database_state(league_id)
        
        # Second sync (immediate)
        result2 = await sync_league(league_id)
        state2 = await get_database_state(league_id)
        
        assert state1 == state2
        assert result2.records_updated == 0  # No changes
    
    @pytest.mark.asyncio
    async def test_concurrent_syncs_safe(self):
        """Concurrent syncs should not corrupt data"""
        league_id = "test_league"
        
        # Launch multiple concurrent syncs
        tasks = [
            sync_league(league_id) for _ in range(10)
        ]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Check no exceptions
        assert all(not isinstance(r, Exception) for r in results)
        
        # Verify data integrity
        state = await get_database_state(league_id)
        assert validate_data_integrity(state)
    
    @pytest.mark.asyncio
    async def test_partial_failure_recovery(self):
        """System should recover from partial failures"""
        league_id = "test_league"
        
        # Simulate failure mid-sync
        with patch('sync.sync_rosters', side_effect=Exception("Network error")):
            try:
                await sync_league(league_id)
            except:
                pass
        
        # Retry sync
        result = await sync_league(league_id)
        
        # Should complete successfully
        assert result.status == "success"
        
        # Verify complete data
        state = await get_database_state(league_id)
        assert state.rosters is not None
```

## Monitoring Idempotency

### Metrics to Track

```python
class IdempotencyMetrics:
    """Track idempotency-related metrics"""
    
    def __init__(self):
        self.duplicate_requests = Counter(
            'sync_duplicate_requests_total',
            'Number of duplicate sync requests detected'
        )
        
        self.unchanged_syncs = Counter(
            'sync_unchanged_total',
            'Number of syncs with no data changes'
        )
        
        self.conflict_resolutions = Counter(
            'sync_conflicts_resolved_total',
            'Number of data conflicts resolved'
        )
        
        self.lock_contentions = Histogram(
            'sync_lock_wait_seconds',
            'Time spent waiting for locks'
        )
```

### Alerting Rules

```yaml
# Prometheus alerting rules
groups:
  - name: idempotency
    rules:
      - alert: HighDuplicateRate
        expr: rate(sync_duplicate_requests_total[5m]) > 0.5
        annotations:
          summary: "High rate of duplicate sync requests"
          description: "More than 50% of requests are duplicates"
      
      - alert: LockContentionHigh
        expr: histogram_quantile(0.95, sync_lock_wait_seconds) > 5
        annotations:
          summary: "High lock contention detected"
          description: "95th percentile lock wait time exceeds 5 seconds"
```

## Best Practices Summary

1. **Always use UPSERT patterns** - Never use blind INSERT or UPDATE
2. **Leverage database constraints** - UNIQUE constraints as safety net
3. **Use checksums for change detection** - Avoid unnecessary writes
4. **Implement request deduplication** - Prevent duplicate processing
5. **Handle concurrent access** - Use appropriate locking strategies
6. **Make operations atomic** - Use database transactions
7. **Log all operations** - For debugging and auditing
8. **Test idempotency explicitly** - Include in test suite
9. **Monitor duplicate rates** - Detect issues early
10. **Document assumptions** - Clear contracts for each operation

## Conclusion

This idempotency strategy ensures that our sync service can safely handle:
- Network failures and retries
- Concurrent sync operations
- Partial failures and recovery
- Duplicate requests
- Data conflicts and race conditions

By following these patterns, the system maintains data integrity and consistency even under adverse conditions, providing a robust and reliable synchronization service.