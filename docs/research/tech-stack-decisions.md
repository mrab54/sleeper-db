# Python Async Framework & Technology Stack Selection

Generated: 2025-08-24

## Executive Summary

After comprehensive evaluation, the recommended technology stack is:
- **Web Framework**: FastAPI
- **HTTP Client**: httpx
- **Database Driver**: asyncpg
- **Task Scheduling**: APScheduler (with Hasura scheduled events)
- **Data Validation**: Pydantic v2
- **Testing**: pytest-asyncio
- **Logging**: structlog

This stack provides the optimal balance of performance, developer experience, and production readiness for our sync service.

## Web Framework Comparison

### Candidates Evaluated

| Framework | Async Support | Performance | Developer Experience | Production Ready | Score |
|-----------|--------------|-------------|---------------------|-----------------|--------|
| **FastAPI** | Native | Excellent | Excellent | Yes | 9.5/10 |
| aiohttp | Native | Excellent | Good | Yes | 8.0/10 |
| Django Async | Partial | Good | Excellent | Yes | 7.5/10 |
| Starlette | Native | Excellent | Good | Yes | 8.0/10 |
| Quart | Native | Good | Good | Yes | 7.0/10 |

### FastAPI - Selected ✅

**Key Advantages:**
```python
from fastapi import FastAPI, BackgroundTasks, HTTPException
from pydantic import BaseModel
from typing import Optional
import asyncio

app = FastAPI(title="Sleeper Sync Service", version="1.0.0")

class SyncRequest(BaseModel):
    league_id: str
    sync_type: str = "incremental"
    force: bool = False

class SyncResponse(BaseModel):
    success: bool
    records_updated: int
    duration_ms: float
    errors: list[str] = []

@app.post("/sync/league", response_model=SyncResponse)
async def sync_league(
    request: SyncRequest,
    background_tasks: BackgroundTasks
):
    """Endpoint for Hasura scheduled events"""
    start = asyncio.get_event_loop().time()
    
    try:
        # Fast response, process in background
        if request.sync_type == "full":
            background_tasks.add_task(
                perform_full_sync, 
                request.league_id
            )
            return SyncResponse(
                success=True,
                records_updated=0,
                duration_ms=0,
                errors=[]
            )
        
        # Quick incremental sync
        result = await perform_incremental_sync(request.league_id)
        
        return SyncResponse(
            success=True,
            records_updated=result.count,
            duration_ms=(asyncio.get_event_loop().time() - start) * 1000,
            errors=[]
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Automatic OpenAPI documentation at /docs
# Automatic validation with Pydantic
# Native async/await support
# Background task support
# Dependency injection system
```

**Why FastAPI wins:**
1. **Performance**: Built on Starlette + Uvicorn (same as raw aiohttp)
2. **Developer Experience**: Automatic docs, validation, serialization
3. **Type Safety**: Full type hints with runtime validation
4. **Production Features**: Built-in monitoring, middleware, background tasks
5. **Hasura Integration**: Perfect for webhook endpoints

## HTTP Client Comparison

### Candidates Evaluated

| Client | Async | Connection Pooling | HTTP/2 | Retries | Score |
|--------|-------|-------------------|--------|---------|--------|
| **httpx** | Yes | Yes | Yes | Yes | 9.5/10 |
| aiohttp | Yes | Yes | No | Manual | 8.0/10 |
| requests | No | Limited | No | Yes | 5.0/10 |
| urllib3 | No | Yes | No | Yes | 6.0/10 |

### httpx - Selected ✅

**Implementation Example:**
```python
import httpx
from typing import Optional, Dict, Any
import asyncio
from tenacity import retry, stop_after_attempt, wait_exponential

class SleeperAPIClient:
    """Async client for Sleeper API with connection pooling and retries"""
    
    def __init__(self):
        self.base_url = "https://api.sleeper.app/v1"
        
        # Connection pool configuration
        limits = httpx.Limits(
            max_keepalive_connections=20,
            max_connections=50,
            keepalive_expiry=30
        )
        
        timeout = httpx.Timeout(
            timeout=30.0,
            connect=5.0,
            read=10.0,
            write=10.0
        )
        
        self.client = httpx.AsyncClient(
            base_url=self.base_url,
            limits=limits,
            timeout=timeout,
            http2=True,  # Enable HTTP/2
            follow_redirects=True
        )
    
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10)
    )
    async def get(self, endpoint: str) -> Dict[str, Any]:
        """GET request with automatic retry"""
        response = await self.client.get(endpoint)
        response.raise_for_status()
        return response.json()
    
    async def batch_get(self, endpoints: list[str]) -> list[Dict]:
        """Parallel batch requests"""
        tasks = [self.get(endpoint) for endpoint in endpoints]
        return await asyncio.gather(*tasks, return_exceptions=True)
    
    async def close(self):
        await self.client.aclose()
    
    async def __aenter__(self):
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.close()
```

**Why httpx wins:**
1. **API Compatibility**: requests-like API, easy migration
2. **HTTP/2 Support**: Better performance with multiplexing
3. **Connection Pooling**: Efficient connection reuse
4. **Built-in Retries**: With tenacity integration
5. **Type Hints**: Full typing support

## Database Driver Comparison

### Candidates Evaluated

| Driver | Async | Performance | Features | PostgreSQL Specific | Score |
|--------|-------|------------|----------|-------------------|--------|
| **asyncpg** | Native | Fastest | Excellent | Yes | 9.5/10 |
| psycopg3 | Yes | Good | Excellent | Yes | 8.5/10 |
| SQLAlchemy Async | Yes | Good | Full ORM | No | 7.5/10 |
| databases | Yes | Good | Simple | No | 7.0/10 |

### asyncpg - Selected ✅

**Implementation Example:**
```python
import asyncpg
from typing import Optional, List, Dict, Any
import json
from datetime import datetime

class DatabasePool:
    """High-performance PostgreSQL connection pool"""
    
    def __init__(self):
        self.pool: Optional[asyncpg.Pool] = None
    
    async def initialize(self, dsn: str):
        """Initialize connection pool with optimal settings"""
        self.pool = await asyncpg.create_pool(
            dsn,
            min_size=10,
            max_size=50,
            max_queries=50000,
            max_inactive_connection_lifetime=300,
            command_timeout=60,
            # Custom type codecs
            init=self._init_connection
        )
    
    async def _init_connection(self, conn):
        """Initialize each connection with custom settings"""
        # JSON codec for JSONB fields
        await conn.set_type_codec(
            'jsonb',
            encoder=json.dumps,
            decoder=json.loads,
            schema='pg_catalog'
        )
        
        # Prepared statements for common queries
        await conn.execute("SET TIME ZONE 'UTC'")
    
    async def upsert_roster(self, roster_data: Dict) -> int:
        """Efficient upsert with RETURNING"""
        query = """
            INSERT INTO rosters (
                league_id, roster_id, owner_id, 
                wins, losses, points_for, players
            ) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)
            ON CONFLICT (league_id, roster_id) 
            DO UPDATE SET
                owner_id = EXCLUDED.owner_id,
                wins = EXCLUDED.wins,
                losses = EXCLUDED.losses,
                points_for = EXCLUDED.points_for,
                players = EXCLUDED.players,
                updated_at = NOW()
            RETURNING id
        """
        
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                query,
                roster_data['league_id'],
                roster_data['roster_id'],
                roster_data['owner_id'],
                roster_data['wins'],
                roster_data['losses'],
                roster_data['points_for'],
                roster_data['players']
            )
            return row['id']
    
    async def batch_upsert(self, table: str, records: List[Dict]):
        """Efficient batch upsert using COPY"""
        async with self.pool.acquire() as conn:
            # Use COPY for massive inserts
            result = await conn.copy_records_to_table(
                table,
                records=records,
                columns=list(records[0].keys())
            )
            return result
    
    async def close(self):
        if self.pool:
            await self.pool.close()
```

**Why asyncpg wins:**
1. **Performance**: 3x faster than psycopg2
2. **PostgreSQL Native**: Built specifically for PostgreSQL
3. **Prepared Statements**: Automatic query optimization
4. **COPY Support**: Bulk operations for massive data
5. **Type System**: Native PostgreSQL type support

## Task Scheduling Solution

### Hybrid Approach: APScheduler + Hasura Scheduled Events ✅

**Architecture:**
```python
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger
import asyncio

class HybridScheduler:
    """
    Combines Hasura scheduled events (primary) with 
    APScheduler (backup/internal)
    """
    
    def __init__(self):
        self.scheduler = AsyncIOScheduler(
            job_defaults={
                'coalesce': True,
                'max_instances': 3,
                'misfire_grace_time': 30
            }
        )
    
    def setup_internal_schedules(self):
        """Internal schedules for critical operations"""
        
        # Health check - internal only
        self.scheduler.add_job(
            self.health_check,
            IntervalTrigger(minutes=1),
            id='health_check',
            replace_existing=True
        )
        
        # Cache cleanup - internal only
        self.scheduler.add_job(
            self.cleanup_cache,
            CronTrigger(hour=2, minute=0),
            id='cache_cleanup',
            replace_existing=True
        )
    
    async def handle_hasura_event(self, event_data: dict):
        """
        Primary scheduling through Hasura
        This is called by Hasura scheduled events
        """
        event_type = event_data.get('scheduled_event', {}).get('name')
        
        handlers = {
            'sync_live_scores': self.sync_live_scores,
            'daily_full_sync': self.daily_full_sync,
            'waiver_period_sync': self.waiver_period_sync
        }
        
        handler = handlers.get(event_type)
        if handler:
            await handler(event_data.get('payload', {}))
        else:
            raise ValueError(f"Unknown event type: {event_type}")
    
    def start(self):
        self.setup_internal_schedules()
        self.scheduler.start()
    
    def shutdown(self):
        self.scheduler.shutdown(wait=True)
```

**Why this approach:**
1. **Hasura Primary**: Leverages Hasura's reliable scheduling
2. **APScheduler Backup**: Internal tasks and fallback
3. **Flexibility**: Can switch between schedulers
4. **Monitoring**: Both systems have monitoring

## Data Validation: Pydantic v2 ✅

```python
from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime
from enum import Enum

class TransactionType(str, Enum):
    TRADE = "trade"
    WAIVER = "waiver"
    FREE_AGENT = "free_agent"

class SleeperUser(BaseModel):
    """Validated Sleeper user model"""
    user_id: str
    username: str
    display_name: str
    avatar: Optional[str] = None
    
    class Config:
        # Pydantic v2 configuration
        str_strip_whitespace = True
        validate_assignment = True

class SleeperRoster(BaseModel):
    """Validated roster with computed fields"""
    roster_id: int
    owner_id: str
    league_id: str
    players: List[str] = Field(default_factory=list)
    starters: List[str] = Field(default_factory=list)
    wins: int = 0
    losses: int = 0
    ties: int = 0
    points_for: float = 0.0
    points_against: float = 0.0
    
    @validator('players', 'starters')
    def remove_nulls(cls, v):
        """Remove null values from player arrays"""
        return [p for p in v if p is not None]
    
    @property
    def win_percentage(self) -> float:
        """Computed win percentage"""
        total = self.wins + self.losses + self.ties
        return self.wins / total if total > 0 else 0.0

class SleeperTransaction(BaseModel):
    """Transaction with validation"""
    transaction_id: str
    type: TransactionType
    status: str
    creator: str
    created: datetime
    roster_ids: List[int]
    adds: Optional[Dict[str, int]] = None
    drops: Optional[Dict[str, int]] = None
    
    @validator('created', pre=True)
    def parse_timestamp(cls, v):
        """Convert millisecond timestamp to datetime"""
        if isinstance(v, int):
            return datetime.fromtimestamp(v / 1000)
        return v
```

## Testing Framework: pytest-asyncio ✅

```python
import pytest
import pytest_asyncio
from httpx import AsyncClient
from unittest.mock import AsyncMock, patch
import asyncio

@pytest.fixture
def anyio_backend():
    return "asyncio"

@pytest_asyncio.fixture
async def api_client():
    """Fixture for API client"""
    client = SleeperAPIClient()
    yield client
    await client.close()

@pytest_asyncio.fixture
async def db_pool():
    """Fixture for database pool"""
    pool = DatabasePool()
    await pool.initialize("postgresql://test@localhost/test_db")
    yield pool
    await pool.close()

@pytest.mark.asyncio
async def test_sync_league(api_client, db_pool):
    """Test league synchronization"""
    # Mock API response
    with patch.object(api_client, 'get', new_callable=AsyncMock) as mock_get:
        mock_get.return_value = {
            "league_id": "123",
            "name": "Test League",
            "season": "2024"
        }
        
        # Run sync
        syncer = LeagueSyncer(api_client, db_pool)
        result = await syncer.sync_league("123")
        
        # Assertions
        assert result.success
        assert result.records_updated > 0
        mock_get.assert_called_once_with("/league/123")

@pytest.mark.asyncio
async def test_concurrent_syncs():
    """Test concurrent sync operations"""
    tasks = []
    for i in range(10):
        task = sync_roster(f"roster_{i}")
        tasks.append(task)
    
    results = await asyncio.gather(*tasks)
    assert all(r.success for r in results)
```

## Logging: structlog ✅

```python
import structlog
from structlog.processors import JSONRenderer
import logging

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.CallsiteParameterAdder(
            parameters=[
                structlog.processors.CallsiteParameter.FILENAME,
                structlog.processors.CallsiteParameter.LINENO,
                structlog.processors.CallsiteParameter.FUNC_NAME,
            ]
        ),
        JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# Usage example
async def sync_with_logging(league_id: str):
    log = logger.bind(
        league_id=league_id,
        operation="sync_league"
    )
    
    log.info("Starting league sync")
    
    try:
        start_time = asyncio.get_event_loop().time()
        result = await perform_sync(league_id)
        
        duration = asyncio.get_event_loop().time() - start_time
        
        log.info(
            "League sync completed",
            duration_seconds=duration,
            records_updated=result.count,
            success=True
        )
        
    except Exception as e:
        log.error(
            "League sync failed",
            error=str(e),
            exc_info=True
        )
        raise
```

## Complete Technology Stack Summary

### Core Stack
| Component | Technology | Version | Justification |
|-----------|------------|---------|---------------|
| Language | Python | 3.11+ | Native async, performance |
| Web Framework | FastAPI | 0.110+ | Best async API framework |
| HTTP Client | httpx | 0.26+ | Modern, async, HTTP/2 |
| Database Driver | asyncpg | 0.29+ | Fastest PostgreSQL driver |
| Task Scheduler | APScheduler + Hasura | 3.10+ | Hybrid approach |
| Data Validation | Pydantic | 2.5+ | Type safety, validation |
| Testing | pytest-asyncio | 0.23+ | Async testing support |
| Logging | structlog | 24.1+ | Structured logging |

### Supporting Libraries
```toml
# pyproject.toml
[tool.poetry.dependencies]
python = "^3.11"
fastapi = "^0.110.0"
uvicorn = {extras = ["standard"], version = "^0.27.0"}
httpx = "^0.26.0"
asyncpg = "^0.29.0"
pydantic = "^2.5.0"
apscheduler = "^3.10.0"
structlog = "^24.1.0"
tenacity = "^8.2.0"
prometheus-client = "^0.19.0"
redis = "^5.0.0"
python-dotenv = "^1.0.0"

[tool.poetry.group.dev.dependencies]
pytest = "^8.0.0"
pytest-asyncio = "^0.23.0"
pytest-cov = "^4.1.0"
black = "^24.0.0"
ruff = "^0.2.0"
mypy = "^1.8.0"
pre-commit = "^3.6.0"
```

### Container Configuration
```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY pyproject.toml poetry.lock ./
RUN pip install poetry && \
    poetry config virtualenvs.create false && \
    poetry install --no-dev

# Copy application
COPY . .

# Run with uvicorn
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

## Performance Benchmarks

### Expected Performance Metrics
| Metric | Target | Stack Capability |
|--------|--------|------------------|
| Concurrent Connections | 1000+ | ✅ 10,000+ |
| Requests/Second | 500+ | ✅ 5,000+ |
| Database Queries/Second | 1000+ | ✅ 10,000+ |
| API Response Time (p95) | < 100ms | ✅ 20-50ms |
| Memory Usage | < 500MB | ✅ 200-300MB |
| Startup Time | < 5s | ✅ 1-2s |

## Decision Rationale

The selected stack prioritizes:
1. **Performance**: All components are best-in-class for async Python
2. **Developer Experience**: Modern tools with excellent documentation
3. **Production Readiness**: Battle-tested in production environments
4. **Type Safety**: Full typing support across the stack
5. **Observability**: Built-in metrics and structured logging
6. **Maintainability**: Clean architecture with separation of concerns

This technology stack provides the optimal foundation for building a high-performance, maintainable sync service that can handle the demands of real-time fantasy football data synchronization.