-- ============================================================================
-- Test Data for Development
-- ============================================================================

\c sleeper_db
SET search_path TO sleeper, public;

-- ============================================================================
-- Test Users
-- ============================================================================

INSERT INTO users (user_id, username, display_name, avatar, is_bot) VALUES
    ('test_user_1', 'testuser1', 'Test User 1', 'https://example.com/avatar1.jpg', false),
    ('test_user_2', 'testuser2', 'Test User 2', 'https://example.com/avatar2.jpg', false),
    ('test_user_3', 'testuser3', 'Test User 3', NULL, false),
    ('test_user_4', 'testuser4', 'Test User 4', NULL, false),
    ('bot_user_1', 'sleeperbot', 'Sleeper Bot', NULL, true)
ON CONFLICT (user_id) DO NOTHING;

-- ============================================================================
-- Test League
-- ============================================================================

INSERT INTO leagues (
    league_id, name, season, season_type, status, 
    total_rosters, draft_id, metadata
) VALUES (
    'test_league_2025',
    'Test Fantasy League',
    '2025',
    'regular',
    'in_season',
    4,
    'test_draft_2025',
    '{"sport": "nfl", "settings": {"type": "redraft"}}'::jsonb
) ON CONFLICT (league_id) DO NOTHING;

-- League settings
INSERT INTO league_settings (
    league_id, 
    waiver_type, 
    waiver_day, 
    waiver_clear_time,
    weekly_waivers,
    playoff_week_start,
    settings
) VALUES (
    'test_league_2025',
    'FAAB',
    3,
    '10:00:00',
    3,
    15,
    '{"roster_size": 16, "starting_roster": ["QB", "RB", "RB", "WR", "WR", "TE", "FLEX", "K", "DEF"]}'::jsonb
) ON CONFLICT (league_id) DO NOTHING;

-- League scoring settings
INSERT INTO league_scoring_settings (league_id, scoring_type, settings) VALUES (
    'test_league_2025',
    'PPR',
    '{
        "pass_td": 4,
        "pass_yd": 0.04,
        "pass_int": -2,
        "rush_td": 6,
        "rush_yd": 0.1,
        "rec_td": 6,
        "rec_yd": 0.1,
        "rec": 1,
        "fum_lost": -2
    }'::jsonb
) ON CONFLICT (league_id) DO NOTHING;

-- ============================================================================
-- Test Rosters
-- ============================================================================

INSERT INTO rosters (league_id, roster_id, owner_id, is_active) VALUES
    ('test_league_2025', 1, 'test_user_1', true),
    ('test_league_2025', 2, 'test_user_2', true),
    ('test_league_2025', 3, 'test_user_3', true),
    ('test_league_2025', 4, 'test_user_4', true)
ON CONFLICT (league_id, roster_id) DO NOTHING;

-- ============================================================================
-- Test Players
-- ============================================================================

INSERT INTO players (player_id, first_name, last_name, full_name, position, team, status) VALUES
    ('1234', 'Patrick', 'Mahomes', 'Patrick Mahomes', 'QB', 'KC', 'active'),
    ('2345', 'Christian', 'McCaffrey', 'Christian McCaffrey', 'RB', 'SF', 'active'),
    ('3456', 'Tyreek', 'Hill', 'Tyreek Hill', 'WR', 'MIA', 'active'),
    ('4567', 'Justin', 'Jefferson', 'Justin Jefferson', 'WR', 'MIN', 'active'),
    ('5678', 'Travis', 'Kelce', 'Travis Kelce', 'TE', 'KC', 'active'),
    ('6789', 'Austin', 'Ekeler', 'Austin Ekeler', 'RB', 'LAC', 'active'),
    ('7890', 'Davante', 'Adams', 'Davante Adams', 'WR', 'LV', 'active'),
    ('8901', 'Josh', 'Allen', 'Josh Allen', 'QB', 'BUF', 'active'),
    ('9012', 'Stefon', 'Diggs', 'Stefon Diggs', 'WR', 'BUF', 'active'),
    ('0123', 'Derrick', 'Henry', 'Derrick Henry', 'RB', 'TEN', 'active'),
    ('1235', 'Mark', 'Andrews', 'Mark Andrews', 'TE', 'BAL', 'active'),
    ('2346', 'Cooper', 'Kupp', 'Cooper Kupp', 'WR', 'LAR', 'injured'),
    ('3457', 'Jonathan', 'Taylor', 'Jonathan Taylor', 'RB', 'IND', 'active'),
    ('4568', 'AJ', 'Brown', 'AJ Brown', 'WR', 'PHI', 'active'),
    ('5679', 'CeeDee', 'Lamb', 'CeeDee Lamb', 'WR', 'DAL', 'active'),
    ('6780', 'Saquon', 'Barkley', 'Saquon Barkley', 'RB', 'NYG', 'active')
ON CONFLICT (player_id) DO NOTHING;

-- ============================================================================
-- Test Roster Players
-- ============================================================================

-- Roster 1
INSERT INTO roster_players (league_id, roster_id, player_id, is_starter, slot_position) VALUES
    ('test_league_2025', 1, '1234', true, 'QB'),
    ('test_league_2025', 1, '2345', true, 'RB'),
    ('test_league_2025', 1, '3456', true, 'WR'),
    ('test_league_2025', 1, '4567', true, 'WR'),
    ('test_league_2025', 1, '5678', true, 'TE'),
    ('test_league_2025', 1, '6789', true, 'FLEX'),
    ('test_league_2025', 1, '7890', false, 'BENCH')
ON CONFLICT (league_id, roster_id, player_id) DO NOTHING;

-- Roster 2
INSERT INTO roster_players (league_id, roster_id, player_id, is_starter, slot_position) VALUES
    ('test_league_2025', 2, '8901', true, 'QB'),
    ('test_league_2025', 2, '9012', true, 'WR'),
    ('test_league_2025', 2, '0123', true, 'RB'),
    ('test_league_2025', 2, '1235', true, 'TE'),
    ('test_league_2025', 2, '2346', true, 'WR'),
    ('test_league_2025', 2, '3457', true, 'RB'),
    ('test_league_2025', 2, '4568', true, 'FLEX')
ON CONFLICT (league_id, roster_id, player_id) DO NOTHING;

-- ============================================================================
-- Test Matchups
-- ============================================================================

-- Week 1 matchups
INSERT INTO matchups (
    league_id, week, roster_id, matchup_id, points, opponent_points
) VALUES
    ('test_league_2025', 1, 1, 2, 125.50, 118.75),
    ('test_league_2025', 1, 2, 1, 118.75, 125.50),
    ('test_league_2025', 1, 3, 4, 132.25, 110.00),
    ('test_league_2025', 1, 4, 3, 110.00, 132.25)
ON CONFLICT DO NOTHING;

-- Week 2 matchups
INSERT INTO matchups (
    league_id, week, roster_id, matchup_id, points, opponent_points
) VALUES
    ('test_league_2025', 2, 1, 3, 142.00, 135.50),
    ('test_league_2025', 2, 3, 1, 135.50, 142.00),
    ('test_league_2025', 2, 2, 4, 128.75, 122.25),
    ('test_league_2025', 2, 4, 2, 122.25, 128.75)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Test Transactions
-- ============================================================================

-- Add/drop transaction
INSERT INTO transactions (
    transaction_id, league_id, type, status, week, 
    transaction_created_at, creator_user_id
) VALUES (
    'trans_001',
    'test_league_2025',
    'waiver',
    'complete',
    2,
    CURRENT_TIMESTAMP - INTERVAL '2 days',
    'test_user_1'
) ON CONFLICT (transaction_id) DO NOTHING;

INSERT INTO transaction_details (
    transaction_id, player_id, action, from_roster_id, to_roster_id
) VALUES
    ('trans_001', '5679', 'add', NULL, 1),
    ('trans_001', '7890', 'drop', 1, NULL)
ON CONFLICT DO NOTHING;

-- Trade transaction
INSERT INTO transactions (
    transaction_id, league_id, type, status, week, 
    transaction_created_at, creator_user_id
) VALUES (
    'trans_002',
    'test_league_2025',
    'trade',
    'complete',
    3,
    CURRENT_TIMESTAMP - INTERVAL '1 day',
    'test_user_2'
) ON CONFLICT (transaction_id) DO NOTHING;

INSERT INTO transaction_details (
    transaction_id, player_id, action, from_roster_id, to_roster_id
) VALUES
    ('trans_002', '3456', 'trade', 1, 2),
    ('trans_002', '0123', 'trade', 2, 1)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Test Player Stats
-- ============================================================================

-- Week 1 stats for some players
INSERT INTO player_stats (player_id, season, week, stats, points) VALUES
    ('1234', '2025', 1, '{"pass_yd": 325, "pass_td": 3, "int": 1}', 24.00),
    ('2345', '2025', 1, '{"rush_yd": 105, "rush_td": 1, "rec": 4, "rec_yd": 35}', 22.00),
    ('3456', '2025', 1, '{"rec": 8, "rec_yd": 120, "rec_td": 1}', 26.00),
    ('8901', '2025', 1, '{"pass_yd": 285, "pass_td": 2, "rush_yd": 45, "rush_td": 1}', 23.90)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Test Draft Data
-- ============================================================================

INSERT INTO drafts (
    draft_id, league_id, type, status, start_time, 
    draft_order, slot_to_roster_id, rounds
) VALUES (
    'test_draft_2025',
    'test_league_2025',
    'snake',
    'complete',
    '2025-08-15 19:00:00-05',
    ARRAY[1, 2, 3, 4],
    '{"1": 1, "2": 2, "3": 3, "4": 4}'::jsonb,
    16
) ON CONFLICT (draft_id) DO NOTHING;

-- Draft picks (first round only for brevity)
INSERT INTO draft_picks (
    draft_id, round, pick_no, player_id, picked_by, is_keeper
) VALUES
    ('test_draft_2025', 1, 1, '2345', 'test_user_1', false),
    ('test_draft_2025', 1, 2, '4567', 'test_user_2', false),
    ('test_draft_2025', 1, 3, '3456', 'test_user_3', false),
    ('test_draft_2025', 1, 4, '5678', 'test_user_4', false)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Test Sync Log Entries
-- ============================================================================

INSERT INTO sync_log (
    entity_type, entity_id, action, status, 
    records_affected, duration_ms, details
) VALUES
    ('league', 'test_league_2025', 'full_sync', 'success', 50, 1250, '{"source": "manual"}'::jsonb),
    ('roster', 'test_league_2025', 'update', 'success', 4, 325, '{"week": 1}'::jsonb),
    ('matchup', 'test_league_2025', 'sync', 'success', 8, 450, '{"week": 1}'::jsonb),
    ('player', 'all', 'metadata_update', 'success', 2000, 5500, '{"updated": 150}'::jsonb)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- Summary
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Test data loaded successfully!';
    RAISE NOTICE 'Created: 5 users, 1 league, 4 rosters, 16 players';
    RAISE NOTICE 'Created: Sample matchups, transactions, and stats';
END $$;