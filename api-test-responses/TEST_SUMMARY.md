# Sleeper API Endpoint Test Summary

## Test Execution Date

2025-08-27

## Primary League ID Used

`1199102384316362752`

## Test Results

### Successfully Tested Endpoints (20 working + 2 non-functional)

| Endpoint                                     | File                                                                   | Notes                                     |
| -------------------------------------------- | ---------------------------------------------------------------------- | ----------------------------------------- |
| GET /state/nfl                               | 01-state-nfl.json                                                      | ✓ Success                                 |
| GET /league/{league_id}                      | 02-league.json                                                         | ✓ Success                                 |
| GET /league/{league_id}/users                | 03-league-users.json                                                   | ✓ Success                                 |
| GET /league/{league_id}/rosters              | 04-league-rosters.json                                                 | ✓ Success                                 |
| GET /league/{league_id}/matchups/{week}      | 05-league-matchups-current.json, 05-league-matchups-week1.json         | ✓ Success (tested week 1)                 |
| GET /league/{league_id}/transactions/{round} | 06-league-transactions-current.json, 06-league-transactions-week1.json | ✓ Success (tested week 1)                 |
| GET /league/{league_id}/winners_bracket      | 07-league-winners-bracket.json                                         | ✓ Success                                 |
| GET /league/{league_id}/losers_bracket       | 08-league-losers-bracket.json                                          | ✓ Success                                 |
| GET /league/{league_id}/traded_picks         | 09-league-traded-picks.json                                            | ✓ Success                                 |
| GET /league/{league_id}/drafts               | 10-league-drafts.json                                                  | ✓ Success                                 |
| GET /user/{user_id}                          | 11-user-by-id.json                                                     | ✓ Success (user_id: 213866320939196416)   |
| GET /user/{username}                         | 11-user-by-username.json                                               | ✓ Success (username: rab12345)            |
| GET /user/{user_id}/leagues/{sport}/{season} | 12-user-leagues.json                                                   | ✓ Success (nfl/2025)                      |
| GET /user/{user_id}/drafts/{sport}/{season}  | 13-user-drafts.json                                                    | ✓ Success (nfl/2025)                      |
| GET /draft/{draft_id}                        | 14-draft-details.json                                                  | ✓ Success (draft_id: 1199102384333144064) |
| GET /draft/{draft_id}/picks                  | 15-draft-picks.json                                                    | ✓ Success                                 |
| GET /draft/{draft_id}/traded_picks           | 16-draft-traded-picks.json                                             | ✓ Success                                 |
| GET /players/nfl                             | 17-players-nfl-full.json                                               | ✓ Success (13MB file)                     |
| GET /players/nfl/trending/add                | 18-trending-players-add.json                                           | ✓ Success                                 |
| GET /players/nfl/trending/drop               | 19-trending-players-drop.json                                          | ✓ Success                                 |
| GET /avatars/{avatar_id}                     | 20-avatar.json                                                         | ✗ Returns 404 HTML page                   |
| GET /avatars/thumbs/{avatar_id}              | 21-avatar-thumbs.json                                                  | ✗ Returns 404 HTML page                   |

## Key Findings

### Data Extracted for Testing

- **League ID**: 1199102384316362752
- **Season**: 2025
- **Draft ID**: 1199102384333144064
- **Sample User ID**: 213866320939196416
- **Sample Username**: rab12345
- **Sample Avatar ID**: a7edf17a1956ebe79017732156625301
- **Current Week**: 1 (as of test date)

### File Sizes

- Players endpoint response: 13MB (largest response)
- All other endpoints: < 100KB each

## Endpoint Call Order Used

1. **State** - To get current week and season info
2. **League** - To get league details and draft ID
3. **League Users** - To get user IDs for further testing
4. **League Rosters** - League roster data
5. **League Matchups** - Using current week from state
6. **League Transactions** - For current and historical weeks
7. **League Brackets** - Winners and losers brackets
8. **League Traded Picks** - Traded draft picks
9. **League Drafts** - Draft information
10. **User Details** - Using extracted user ID
11. **User Leagues** - User's leagues for the season
12. **User Drafts** - User's drafts for the season
13. **Draft Details** - Using extracted draft ID
14. **Draft Picks** - All picks from the draft
15. **Draft Traded Picks** - Traded picks in the draft
16. **Players** - Full player database
17. **Trending Players** - Both adds and drops
18. **Avatars** - API endpoints return 404 (use CDN URLs directly)

## Response Storage

All responses are stored in `/mnt/o/sleeper-db/api-test-responses/` with descriptive filenames indicating the endpoint tested.

## Notes

- Most endpoints returned valid JSON responses (20 out of 22)
- No authentication was required for any endpoint
- The API appears to be functioning as documented in the Swagger specification for most endpoints
- Week 1 data was available for matchups and transactions
- Bracket endpoints returned data even though playoffs haven't occurred yet (likely empty or placeholder data)
- **Avatar Endpoints Issue**: The `/avatars/{id}` and `/avatars/thumbs/{id}` endpoints documented in Swagger **do not work** - they return 404 HTML pages
  - Avatar IDs are provided in user and league objects
  - To display avatars, construct CDN URLs directly:
    - Full size: `https://sleepercdn.com/avatars/{avatar_id}`
    - Thumbnail: `https://sleepercdn.com/avatars/thumbs/{avatar_id}`
