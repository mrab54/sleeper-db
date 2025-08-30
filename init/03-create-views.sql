-- Sleeper Fantasy Football Database Views - FIXED
-- PostgreSQL 17
--
-- This script creates views for common queries and reporting
-- CRITICAL FIXES: Corrected table name references and optimized queries

-- Set search path to our schema
SET search_path TO sleeper, public;

-- ============================================================================
-- CURRENT ROSTERS VIEW - FIXED
-- ============================================================================

CREATE OR REPLACE VIEW current_rosters AS
SELECT 
    r.roster_id,
    r.league_id,
    r.owner_user_id,
    u.display_name as owner_name,
    u.username as owner_username,
    r.roster_position,
    r.wins,
    r.losses,
    r.ties,
    r.fantasy_points_for,
    r.fantasy_points_against,
    r.fantasy_points_for - r.fantasy_points_against as point_differential,
    r.waiver_position,
    r.waiver_budget_used,
    r.total_moves,
    l.name as league_name,
    l.status as league_status,
    l.season_type,
    s.year as season_year
FROM roster r  -- FIXED: was referencing non-existent 'rosters' table
LEFT JOIN "user" u ON r.owner_user_id = u.user_id
LEFT JOIN league l ON r.league_id = l.league_id
LEFT JOIN season s ON l.season_id = s.season_id;

-- ============================================================================
-- LEAGUE STANDINGS VIEW - OPTIMIZED
-- ============================================================================

CREATE OR REPLACE VIEW league_standings AS
SELECT 
    r.league_id,
    l.name as league_name,
    s.year as season_year,
    r.roster_id,
    r.roster_position,
    u.display_name as owner_name,
    u.username as owner_username,
    r.wins,
    r.losses,
    r.ties,
    -- Calculate win percentage efficiently
    CASE 
        WHEN (r.wins + r.losses + r.ties) > 0 
        THEN ROUND((r.wins::numeric + (r.ties::numeric * 0.5)) / (r.wins + r.losses + r.ties) * 100, 2)
        ELSE 0
    END as win_percentage,
    r.fantasy_points_for,
    r.fantasy_points_against,
    r.fantasy_points_for - r.fantasy_points_against as point_differential,
    -- Calculate rank within league
    RANK() OVER (
        PARTITION BY r.league_id 
        ORDER BY r.wins DESC, r.fantasy_points_for DESC
    ) as current_rank
FROM roster r
LEFT JOIN "user" u ON r.owner_user_id = u.user_id
LEFT JOIN league l ON r.league_id = l.league_id
LEFT JOIN season s ON l.season_id = s.season_id
ORDER BY r.league_id, current_rank;

-- ============================================================================
-- PLAYER STATS SUMMARY VIEW - FIXED AND OPTIMIZED
-- ============================================================================

CREATE OR REPLACE VIEW player_stats_summary AS
SELECT 
    p.player_id,
    p.full_name,
    p.position,
    p.team_abbr,
    p.status as player_status,
    p.injury_status,
    -- Count how many rosters the player is on (FIXED: added WHERE clause)
    COUNT(DISTINCT CASE WHEN rp.status = 'active' THEN rp.roster_id END) as rostered_count,
    -- Average points scored across all matchups  
    AVG(mps.points) as avg_points,
    MIN(mps.points) as min_points,
    MAX(mps.points) as max_points,
    -- Transaction activity
    SUM(CASE WHEN tp.action = 'add' THEN 1 ELSE 0 END) as total_adds,
    SUM(CASE WHEN tp.action = 'drop' THEN 1 ELSE 0 END) as total_drops
FROM player p
LEFT JOIN roster_player rp ON p.player_id = rp.player_id
LEFT JOIN matchup_player_stat mps ON p.player_id = mps.player_id  -- FIXED: table name
LEFT JOIN transaction_player tp ON p.player_id = tp.player_id
GROUP BY p.player_id, p.full_name, p.position, p.team_abbr, p.status, p.injury_status;

-- ============================================================================
-- WEEKLY MATCHUP RESULTS VIEW - COMPLETELY REWRITTEN FOR CORRECTNESS
-- ============================================================================

CREATE OR REPLACE VIEW weekly_matchup_results AS
WITH matchup_pairs AS (
    -- Get all unique matchup pairs
    SELECT 
        m.matchup_id,
        m.league_id,
        m.week,
        m.season_id,
        m.matchup_number,
        m.is_playoff,
        m.is_consolation,
        mt1.roster_id as team1_roster_id,
        mt1.points as team1_points,
        mt1.is_winner as team1_won,
        mt2.roster_id as team2_roster_id,
        mt2.points as team2_points,
        mt2.is_winner as team2_won
    FROM matchup m
    JOIN matchup_team mt1 ON m.matchup_id = mt1.matchup_id
    JOIN matchup_team mt2 ON m.matchup_id = mt2.matchup_id 
        AND mt1.matchup_team_id < mt2.matchup_team_id  -- Ensure we get each pair only once
)
SELECT 
    mp.matchup_id,
    mp.league_id,
    l.name as league_name,
    mp.week,
    mp.season_id,
    s.year as season_year,
    mp.matchup_number,
    mp.is_playoff,
    mp.is_consolation,
    -- Team 1 details
    mp.team1_roster_id,
    u1.display_name as team1_owner,
    mp.team1_points,
    mp.team1_won,
    -- Team 2 details
    mp.team2_roster_id,
    u2.display_name as team2_owner,
    mp.team2_points,
    mp.team2_won,
    -- Match details
    ABS(mp.team1_points - mp.team2_points) as point_margin
FROM matchup_pairs mp
LEFT JOIN roster r1 ON mp.league_id = r1.league_id AND mp.team1_roster_id = r1.roster_id  -- FIXED
LEFT JOIN roster r2 ON mp.league_id = r2.league_id AND mp.team2_roster_id = r2.roster_id  -- FIXED
LEFT JOIN "user" u1 ON r1.owner_user_id = u1.user_id
LEFT JOIN "user" u2 ON r2.owner_user_id = u2.user_id
LEFT JOIN league l ON mp.league_id = l.league_id
LEFT JOIN season s ON mp.season_id = s.season_id;

-- ============================================================================
-- RECENT TRANSACTIONS VIEW - PERFORMANCE OPTIMIZED
-- ============================================================================

CREATE OR REPLACE VIEW recent_transactions AS
SELECT 
    t.transaction_id,
    t.league_id,
    l.name as league_name,
    t.type as transaction_type,
    t.status,
    t.week,
    t.created_at,
    t.processed_at,
    u.display_name as creator_name,
    -- Get player adds (OPTIMIZED: using FILTER clause)
    STRING_AGG(p.full_name, ', ') FILTER (WHERE tp.action = 'add') as players_added,
    -- Get player drops
    STRING_AGG(p.full_name, ', ') FILTER (WHERE tp.action = 'drop') as players_dropped,
    -- Add roster involvement count
    COUNT(DISTINCT tr.roster_id) as rosters_involved
FROM transaction t
LEFT JOIN league l ON t.league_id = l.league_id
LEFT JOIN "user" u ON t.creator_user_id = u.user_id
LEFT JOIN transaction_player tp ON t.transaction_id = tp.transaction_id
LEFT JOIN player p ON tp.player_id = p.player_id
LEFT JOIN transaction_roster tr ON t.transaction_id = tr.transaction_id
GROUP BY t.transaction_id, t.league_id, l.name, t.type, t.status, 
         t.week, t.created_at, t.processed_at, u.display_name
ORDER BY t.created_at DESC;

-- ============================================================================
-- ROSTER COMPOSITION VIEW - FIXED AND ENHANCED
-- ============================================================================

CREATE OR REPLACE VIEW roster_composition AS
SELECT 
    r.roster_id,
    r.league_id,
    l.name as league_name,
    r.roster_position,
    u.display_name as owner_name,
    -- Count players by position (FIXED: added active status filter)
    COUNT(CASE WHEN p.position = 'QB' AND rp.status = 'active' THEN 1 END) as qb_count,
    COUNT(CASE WHEN p.position = 'RB' AND rp.status = 'active' THEN 1 END) as rb_count,
    COUNT(CASE WHEN p.position = 'WR' AND rp.status = 'active' THEN 1 END) as wr_count,
    COUNT(CASE WHEN p.position = 'TE' AND rp.status = 'active' THEN 1 END) as te_count,
    COUNT(CASE WHEN p.position = 'K' AND rp.status = 'active' THEN 1 END) as k_count,
    COUNT(CASE WHEN p.position = 'DEF' AND rp.status = 'active' THEN 1 END) as def_count,
    COUNT(CASE WHEN rp.status = 'active' THEN 1 END) as total_players,
    -- List all active players only
    STRING_AGG(
        CASE WHEN rp.status = 'active' 
        THEN p.full_name || ' (' || p.position || ')' 
        END, 
        ', ' 
        ORDER BY p.position, p.full_name
    ) as all_players
FROM roster r
LEFT JOIN league l ON r.league_id = l.league_id
LEFT JOIN "user" u ON r.owner_user_id = u.user_id
LEFT JOIN roster_player rp ON r.league_id = rp.league_id AND r.roster_id = rp.roster_id  -- FIXED: added league join
LEFT JOIN player p ON rp.player_id = p.player_id
GROUP BY r.roster_id, r.league_id, l.name, r.roster_position, u.display_name;

-- ============================================================================
-- DRAFT RESULTS VIEW - FIXED
-- ============================================================================

CREATE OR REPLACE VIEW draft_results AS
SELECT 
    dp.draft_id,
    d.league_id,
    l.name as league_name,
    s.year as season_year,
    dp.overall_pick,
    dp.round,
    dp.pick_in_round,
    dp.slot as draft_slot,
    r.roster_position,
    u.display_name as picking_owner,
    p.full_name as player_name,
    p.position as player_position,
    p.team_abbr as player_team,
    dp.is_keeper,
    dp.auction_amount,
    dp.pick_time
FROM draft_pick dp
LEFT JOIN draft d ON dp.draft_id = d.draft_id
LEFT JOIN league l ON d.league_id = l.league_id
LEFT JOIN season s ON d.season_id = s.season_id
LEFT JOIN roster r ON dp.league_id = r.league_id AND dp.roster_id = r.roster_id  -- FIXED
LEFT JOIN "user" u ON dp.picked_by_user_id = u.user_id
LEFT JOIN player p ON dp.player_id = p.player_id
ORDER BY dp.draft_id, dp.overall_pick;

-- ============================================================================
-- PLAYER OWNERSHIP VIEW - PERFORMANCE OPTIMIZED
-- ============================================================================

CREATE OR REPLACE VIEW player_ownership AS
WITH active_leagues AS (
    SELECT COUNT(DISTINCT league_id) as total_league_count
    FROM league
    WHERE status = 'in_season'
),
active_roster_players AS (
    SELECT 
        rp.player_id,
        COUNT(DISTINCT rp.roster_id) as roster_count,
        COUNT(DISTINCT r.league_id) as league_count
    FROM roster_player rp
    JOIN roster r ON rp.league_id = r.league_id AND rp.roster_id = r.roster_id
    JOIN league l ON r.league_id = l.league_id
    WHERE rp.status = 'active' 
    AND l.status = 'in_season'
    GROUP BY rp.player_id
)
SELECT 
    p.player_id,
    p.full_name,
    p.position,
    p.team_abbr,
    COALESCE(arp.roster_count, 0) as roster_count,
    COALESCE(arp.league_count, 0) as league_count,
    ROUND(
        COALESCE(arp.league_count, 0)::numeric / NULLIF(al.total_league_count, 0) * 100, 2
    ) as ownership_percentage
FROM player p
LEFT JOIN active_roster_players arp ON p.player_id = arp.player_id
CROSS JOIN active_leagues al
ORDER BY roster_count DESC;

-- ============================================================================
-- NEW OPTIMIZED VIEWS FOR SYNC OPERATIONS
-- ============================================================================

-- View for tracking sync status across entities
CREATE OR REPLACE VIEW sync_status_summary AS
SELECT 
    entity_type,
    COUNT(*) as total_syncs,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_syncs,
    COUNT(*) FILTER (WHERE status = 'failed') as failed_syncs,
    COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress_syncs,
    AVG(EXTRACT(EPOCH FROM (completed_at - started_at))) as avg_duration_seconds,
    MAX(started_at) as last_sync_attempt
FROM data_sync_log
WHERE started_at > NOW() - INTERVAL '24 hours'
GROUP BY entity_type
ORDER BY last_sync_attempt DESC;

-- View for league health metrics
CREATE OR REPLACE VIEW league_health_metrics AS
SELECT 
    l.league_id,
    l.name as league_name,
    l.status,
    l.total_rosters,
    COUNT(DISTINCT r.roster_id) as active_rosters,
    COUNT(DISTINCT lm.user_id) as total_members,
    l.last_synced_at,
    EXTRACT(EPOCH FROM (NOW() - l.last_synced_at))/60 as minutes_since_sync,
    s.year as season_year
FROM league l
LEFT JOIN roster r ON l.league_id = r.league_id
LEFT JOIN league_member lm ON l.league_id = lm.league_id AND lm.leave_date IS NULL
LEFT JOIN season s ON l.season_id = s.season_id
GROUP BY l.league_id, l.name, l.status, l.total_rosters, l.last_synced_at, s.year
ORDER BY l.last_synced_at DESC;

-- ============================================================================
-- PERFORMANCE HINTS FOR VIEWS
-- ============================================================================

-- Add comments for query planner hints
COMMENT ON VIEW current_rosters IS 'Materialized view candidate - frequently accessed roster data';
COMMENT ON VIEW league_standings IS 'Consider partitioning by league_id for large datasets';
COMMENT ON VIEW player_ownership IS 'Heavy aggregation view - consider materializing for production';