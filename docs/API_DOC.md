# Sleeper API Documentation

## Overview
The Sleeper API provides read-only access to fantasy football league data. This document covers the essential information for working with the API.

## Base URL
```
https://api.sleeper.app/v1
```

## Authentication
The Sleeper API is **publicly accessible** and requires **no authentication** or API keys.

## Rate Limiting
- No official rate limits documented
- Best practice: Stay under 1000 API calls per minute
- Implement reasonable delays between requests

## Primary League ID
```
1199102384316362752
```

## API Reference
For complete endpoint documentation, request/response schemas, and detailed parameter descriptions, see the **[OpenAPI/Swagger specification](./sleeper-api-swagger.yaml)**.

The Swagger file includes:
- All 21 API endpoints with full documentation
- Detailed request parameters and types
- Complete response schemas for all objects
- Enum values and field descriptions

## Quick Start Examples

### Test API Access
```bash
# Test NFL State (smallest response)
curl -s https://api.sleeper.app/v1/state/nfl | jq '.'

# Test specific league
curl -s https://api.sleeper.app/v1/league/1199102384316362752 | jq '.name, .season, .status'
```

### Common Requests
```bash
# Get league rosters
curl https://api.sleeper.app/v1/league/1199102384316362752/rosters

# Get current week matchups (replace {week} with 1-18)
curl https://api.sleeper.app/v1/league/1199102384316362752/matchups/{week}

# Get all NFL players (large response, ~5-10MB)
curl https://api.sleeper.app/v1/players/nfl > players.json
```

## Data Update Frequencies

### Real-time (During Games)
- **Matchups**: Update every ~30 seconds during games
- **Player stats**: Update as plays happen

### Frequent Updates
- **Transactions**: Immediate when processed
- **Rosters**: Immediate after transactions

### Daily Updates
- **League settings**: Check daily for changes
- **NFL State**: Updates at midnight ET

### Weekly Updates
- **Player database**: Full refresh weekly (Tuesdays)

## Implementation Notes

### Optimal Sync Strategy
1. **During Season (Sept-Jan)**
   - NFL State: Daily at midnight
   - League: Daily at 3 AM
   - Rosters: Every hour
   - Matchups: Every 5 min during games, hourly otherwise
   - Transactions: Every 30 minutes
   - Players: Weekly on Tuesday

2. **Off Season (Feb-Aug)**
   - All endpoints: Daily at 3 AM
   - Players: Weekly

### Error Handling
- Implement exponential backoff for retries
- Handle 404s gracefully (future weeks return 404)
- Log all errors with context
- Continue processing other endpoints if one fails

### Data Storage Best Practices
1. Store raw responses for replay/debugging
2. Hash responses to detect changes
3. Track fetch timestamps
4. Separate raw storage from processed data
5. Implement idempotent processing

## Common Gotchas

1. **Player IDs are strings**, not integers
2. **Week numbers** continue through playoffs (15-18)
3. **Empty arrays** returned for future weeks (not 404s)
4. **Draft picks** only available if draft is complete
5. **User IDs** can be null for unclaimed teams
6. **Matchup points** are decimal, need proper precision
7. **Transaction timestamps** are Unix milliseconds
8. **Player data** includes inactive/retired players

## Sample Implementation Flow

```python
# Daily sync flow
async def daily_sync(league_id):
    # 1. Fetch current NFL state
    nfl_state = await fetch("/state/nfl")
    current_week = nfl_state["week"]
    
    # 2. Fetch league info
    league = await fetch(f"/league/{league_id}")
    
    # 3. Fetch users if needed
    users = await fetch(f"/league/{league_id}/users")
    
    # 4. Fetch current rosters
    rosters = await fetch(f"/league/{league_id}/rosters")
    
    # 5. Fetch matchups for current week
    if current_week <= 18:
        matchups = await fetch(f"/league/{league_id}/matchups/{current_week}")
    
    # 6. Fetch recent transactions
    for week in range(max(1, current_week-2), current_week+1):
        transactions = await fetch(f"/league/{league_id}/transactions/{week}")
    
    # 7. Check for traded picks
    traded_picks = await fetch(f"/league/{league_id}/traded_picks")
    
    # 8. Weekly player update (Tuesdays)
    if datetime.now().weekday() == 1:  # Tuesday
        players = await fetch("/players/nfl")
```

## Tools & Resources

- Use the Swagger file with tools like:
  - [Swagger UI](https://swagger.io/tools/swagger-ui/) for interactive documentation
  - [Postman](https://www.postman.com/) for API testing
  - [OpenAPI Generator](https://openapi-generator.tech/) for client SDK generation

## Support

For API issues or questions:
- Official documentation: https://docs.sleeper.com
- Community resources and discussions available on Sleeper's platform