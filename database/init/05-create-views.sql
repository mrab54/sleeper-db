-- ============================================================================
-- Database Views
-- ============================================================================

\c sleeper_db
SET search_path TO sleeper, public;

-- ============================================================================
-- Core Views (already in schema, recreating for completeness)
-- ============================================================================

-- League standings view
CREATE OR REPLACE VIEW v_league_standings AS
SELECT 
    l.league_id,
    l.name as league_name,
    r.roster_id,
    u.display_name as owner_name,
    COUNT(CASE WHEN m.points > m.opponent_points THEN 1 END) as wins,
    COUNT(CASE WHEN m.points < m.opponent_points THEN 1 END) as losses,
    COUNT(CASE WHEN m.points = m.opponent_points THEN 1 END) as ties,
    COALESCE(SUM(m.points), 0) as points_for,
    COALESCE(SUM(m.opponent_points), 0) as points_against,
    COALESCE(SUM(m.points), 0) - COALESCE(SUM(m.opponent_points), 0) as point_differential,
    COUNT(CASE WHEN m.points > m.opponent_points THEN 1 END)::DECIMAL / 
        NULLIF(COUNT(m.id), 0) as win_percentage,
    RANK() OVER (
        PARTITION BY l.league_id 
        ORDER BY 
            COUNT(CASE WHEN m.points > m.opponent_points THEN 1 END) DESC,
            COALESCE(SUM(m.points), 0) DESC
    ) as ranking
FROM leagues l
JOIN rosters r ON l.league_id = r.league_id
LEFT JOIN users u ON r.owner_id = u.user_id
LEFT JOIN matchups m ON r.league_id = m.league_id AND r.roster_id = m.roster_id
WHERE r.is_active = true
GROUP BY l.league_id, l.name, r.roster_id, u.display_name;

-- Recent transactions view
CREATE OR REPLACE VIEW v_recent_transactions AS
SELECT 
    t.transaction_id,
    t.league_id,
    l.name as league_name,
    t.type,
    t.status,
    t.week,
    t.transaction_created_at,
    u.display_name as creator_name,
    t.metadata,
    td.action,
    td.player_id,
    p.full_name as player_name,
    td.from_roster_id,
    td.to_roster_id
FROM transactions t
JOIN leagues l ON t.league_id = l.league_id
LEFT JOIN users u ON t.creator_user_id = u.user_id
LEFT JOIN transaction_details td ON t.transaction_id = td.transaction_id
LEFT JOIN players p ON td.player_id = p.player_id
ORDER BY t.transaction_created_at DESC;

-- Current matchups view
CREATE OR REPLACE VIEW v_current_matchups AS
SELECT 
    m.id as matchup_id,
    m.league_id,
    m.week,
    m.roster_id,
    r1.owner_id,
    u1.display_name as owner_name,
    m.points,
    m.matchup_id as opponent_roster_id,
    r2.owner_id as opponent_owner_id,
    u2.display_name as opponent_name,
    m.opponent_points,
    CASE 
        WHEN m.points > m.opponent_points THEN 'W'
        WHEN m.points < m.opponent_points THEN 'L'
        WHEN m.points = m.opponent_points AND m.points IS NOT NULL THEN 'T'
        ELSE NULL
    END as result,
    m.points - m.opponent_points as margin
FROM matchups m
JOIN rosters r1 ON m.league_id = r1.league_id AND m.roster_id = r1.roster_id
LEFT JOIN users u1 ON r1.owner_id = u1.user_id
LEFT JOIN rosters r2 ON m.league_id = r2.league_id AND m.matchup_id = r2.roster_id
LEFT JOIN users u2 ON r2.owner_id = u2.user_id;

-- ============================================================================
-- Additional Analytics Views
-- ============================================================================

-- Player performance trends
CREATE OR REPLACE VIEW v_player_performance AS
SELECT 
    ps.player_id,
    p.full_name,
    p.position,
    p.team,
    ps.season,
    ps.week,
    ps.stats,
    ps.points,
    AVG(ps.points) OVER (
        PARTITION BY ps.player_id 
        ORDER BY ps.season, ps.week 
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    ) as moving_avg_4_weeks,
    RANK() OVER (
        PARTITION BY p.position, ps.season, ps.week 
        ORDER BY ps.points DESC
    ) as position_rank_week
FROM player_stats ps
JOIN players p ON ps.player_id = p.player_id
WHERE ps.points IS NOT NULL;

-- Roster composition analysis
CREATE OR REPLACE VIEW v_roster_composition AS
SELECT 
    rp.league_id,
    rp.roster_id,
    r.owner_id,
    u.display_name as owner_name,
    p.position,
    COUNT(*) as player_count,
    COUNT(CASE WHEN rp.is_starter THEN 1 END) as starter_count,
    STRING_AGG(p.full_name, ', ' ORDER BY p.full_name) as players
FROM roster_players rp
JOIN rosters r ON rp.league_id = r.league_id AND rp.roster_id = r.roster_id
JOIN players p ON rp.player_id = p.player_id
LEFT JOIN users u ON r.owner_id = u.user_id
GROUP BY rp.league_id, rp.roster_id, r.owner_id, u.display_name, p.position;

-- Trade analysis view
CREATE OR REPLACE VIEW v_trade_analysis AS
SELECT 
    t.transaction_id,
    t.league_id,
    t.week,
    t.transaction_created_at,
    td1.from_roster_id as roster_1,
    u1.display_name as owner_1,
    td1.to_roster_id as roster_2,
    u2.display_name as owner_2,
    STRING_AGG(
        CASE WHEN td.from_roster_id = td1.from_roster_id 
        THEN p.full_name END, ', '
    ) as players_from_roster_1,
    STRING_AGG(
        CASE WHEN td.from_roster_id = td1.to_roster_id 
        THEN p.full_name END, ', '
    ) as players_from_roster_2
FROM transactions t
JOIN transaction_details td1 ON t.transaction_id = td1.transaction_id
JOIN transaction_details td ON t.transaction_id = td.transaction_id
JOIN players p ON td.player_id = p.player_id
LEFT JOIN rosters r1 ON td1.from_roster_id = r1.roster_id AND t.league_id = r1.league_id
LEFT JOIN users u1 ON r1.owner_id = u1.user_id
LEFT JOIN rosters r2 ON td1.to_roster_id = r2.roster_id AND t.league_id = r2.league_id
LEFT JOIN users u2 ON r2.owner_id = u2.user_id
WHERE t.type = 'trade' AND t.status = 'complete'
GROUP BY t.transaction_id, t.league_id, t.week, t.transaction_created_at,
         td1.from_roster_id, u1.display_name, td1.to_roster_id, u2.display_name;

-- Weekly scoring leaders
CREATE OR REPLACE VIEW v_weekly_scoring_leaders AS
SELECT 
    m.league_id,
    m.week,
    m.roster_id,
    u.display_name as owner_name,
    m.points,
    RANK() OVER (PARTITION BY m.league_id, m.week ORDER BY m.points DESC) as week_rank,
    AVG(m.points) OVER (
        PARTITION BY m.league_id, m.roster_id 
        ORDER BY m.week 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as season_avg_to_date
FROM matchups m
JOIN rosters r ON m.league_id = r.league_id AND m.roster_id = r.roster_id
LEFT JOIN users u ON r.owner_id = u.user_id
WHERE m.points IS NOT NULL;

-- Best/worst weekly performances
CREATE OR REPLACE VIEW v_extreme_performances AS
WITH weekly_stats AS (
    SELECT 
        league_id,
        week,
        MAX(points) as highest_score,
        MIN(points) as lowest_score,
        AVG(points) as avg_score,
        STDDEV(points) as stddev_score
    FROM matchups
    WHERE points IS NOT NULL
    GROUP BY league_id, week
)
SELECT 
    m.league_id,
    m.week,
    m.roster_id,
    u.display_name as owner_name,
    m.points,
    ws.avg_score,
    CASE 
        WHEN m.points = ws.highest_score THEN 'Highest'
        WHEN m.points = ws.lowest_score THEN 'Lowest'
        ELSE 'Normal'
    END as performance_type,
    (m.points - ws.avg_score) / NULLIF(ws.stddev_score, 0) as z_score
FROM matchups m
JOIN weekly_stats ws ON m.league_id = ws.league_id AND m.week = ws.week
JOIN rosters r ON m.league_id = r.league_id AND m.roster_id = r.roster_id
LEFT JOIN users u ON r.owner_id = u.user_id
WHERE m.points IN (ws.highest_score, ws.lowest_score);

-- Head-to-head records
CREATE OR REPLACE VIEW v_head_to_head AS
SELECT 
    m1.league_id,
    m1.roster_id as roster_1,
    u1.display_name as owner_1,
    m1.matchup_id as roster_2,
    u2.display_name as owner_2,
    COUNT(*) as games_played,
    COUNT(CASE WHEN m1.points > m1.opponent_points THEN 1 END) as roster_1_wins,
    COUNT(CASE WHEN m1.points < m1.opponent_points THEN 1 END) as roster_2_wins,
    COUNT(CASE WHEN m1.points = m1.opponent_points THEN 1 END) as ties,
    ROUND(AVG(m1.points), 2) as roster_1_avg_points,
    ROUND(AVG(m1.opponent_points), 2) as roster_2_avg_points
FROM matchups m1
JOIN rosters r1 ON m1.league_id = r1.league_id AND m1.roster_id = r1.roster_id
LEFT JOIN users u1 ON r1.owner_id = u1.user_id
JOIN rosters r2 ON m1.league_id = r2.league_id AND m1.matchup_id = r2.roster_id
LEFT JOIN users u2 ON r2.owner_id = u2.user_id
WHERE m1.points IS NOT NULL
GROUP BY m1.league_id, m1.roster_id, u1.display_name, m1.matchup_id, u2.display_name;

-- Season progression view
CREATE OR REPLACE VIEW v_season_progression AS
SELECT 
    m.league_id,
    m.roster_id,
    u.display_name as owner_name,
    m.week,
    m.points,
    SUM(CASE WHEN m.points > m.opponent_points THEN 1 ELSE 0 END) 
        OVER (PARTITION BY m.league_id, m.roster_id ORDER BY m.week) as wins_to_date,
    SUM(CASE WHEN m.points < m.opponent_points THEN 1 ELSE 0 END) 
        OVER (PARTITION BY m.league_id, m.roster_id ORDER BY m.week) as losses_to_date,
    SUM(m.points) OVER (PARTITION BY m.league_id, m.roster_id ORDER BY m.week) as total_points_to_date,
    AVG(m.points) OVER (PARTITION BY m.league_id, m.roster_id ORDER BY m.week) as avg_points_to_date,
    RANK() OVER (
        PARTITION BY m.league_id, m.week 
        ORDER BY 
            SUM(CASE WHEN m.points > m.opponent_points THEN 1 ELSE 0 END) 
                OVER (PARTITION BY m.league_id, m.roster_id ORDER BY m.week) DESC,
            SUM(m.points) OVER (PARTITION BY m.league_id, m.roster_id ORDER BY m.week) DESC
    ) as rank_after_week
FROM matchups m
JOIN rosters r ON m.league_id = r.league_id AND m.roster_id = r.roster_id
LEFT JOIN users u ON r.owner_id = u.user_id
WHERE m.points IS NOT NULL
ORDER BY m.league_id, m.roster_id, m.week;

-- Draft value analysis
CREATE OR REPLACE VIEW v_draft_value AS
SELECT 
    dp.draft_id,
    dp.round,
    dp.pick_no,
    dp.player_id,
    p.full_name,
    p.position,
    dp.picked_by,
    u.display_name as picker_name,
    dp.keeper_status,
    COALESCE(
        AVG(ps.points),
        0
    ) as avg_points_per_week,
    RANK() OVER (
        PARTITION BY dp.draft_id, p.position 
        ORDER BY dp.pick_no
    ) as position_draft_order,
    RANK() OVER (
        PARTITION BY dp.draft_id, p.position 
        ORDER BY AVG(ps.points) DESC
    ) as position_performance_rank
FROM draft_picks dp
JOIN players p ON dp.player_id = p.player_id
LEFT JOIN users u ON dp.picked_by = u.user_id
LEFT JOIN player_stats ps ON dp.player_id = ps.player_id
GROUP BY dp.draft_id, dp.round, dp.pick_no, dp.player_id, 
         p.full_name, p.position, dp.picked_by, u.display_name, dp.keeper_status;

-- Grant permissions on all views
GRANT SELECT ON ALL TABLES IN SCHEMA sleeper TO sleeper_user;