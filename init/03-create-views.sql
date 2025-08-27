-- Sleeper Fantasy Football Database Views
-- PostgreSQL 17
--
-- This script creates views for common queries and reporting

-- Set search path to our schema
SET search_path TO sleeper, public;

-- ============================================================================
-- CURRENT ROSTERS VIEW
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
FROM rosters r
LEFT JOIN users u ON r.owner_user_id = u.user_id
LEFT JOIN leagues l ON r.league_id = l.league_id
LEFT JOIN seasons s ON l.season_id = s.season_id;

-- ============================================================================
-- LEAGUE STANDINGS VIEW
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
    -- Calculate win percentage
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
FROM rosters r
LEFT JOIN users u ON r.owner_user_id = u.user_id
LEFT JOIN leagues l ON r.league_id = l.league_id
LEFT JOIN seasons s ON l.season_id = s.season_id
ORDER BY r.league_id, current_rank;

-- ============================================================================
-- PLAYER STATS SUMMARY VIEW
-- ============================================================================

CREATE OR REPLACE VIEW player_stats_summary AS
SELECT 
    p.player_id,
    p.full_name,
    p.position,
    p.team_abbr,
    p.status as player_status,
    p.injury_status,
    -- Count how many rosters the player is on
    COUNT(DISTINCT rp.roster_id) as rostered_count,
    -- Average points scored across all matchups
    AVG(mps.points) as avg_points,
    MIN(mps.points) as min_points,
    MAX(mps.points) as max_points,
    -- Transaction activity
    SUM(CASE WHEN tp.action = 'add' THEN 1 ELSE 0 END) as total_adds,
    SUM(CASE WHEN tp.action = 'drop' THEN 1 ELSE 0 END) as total_drops
FROM players p
LEFT JOIN roster_players rp ON p.player_id = rp.player_id
LEFT JOIN matchup_player_stats mps ON p.player_id = mps.player_id
LEFT JOIN transaction_players tp ON p.player_id = tp.player_id
GROUP BY p.player_id, p.full_name, p.position, p.team_abbr, p.status, p.injury_status;

-- ============================================================================
-- WEEKLY MATCHUP RESULTS VIEW
-- ============================================================================

CREATE OR REPLACE VIEW weekly_matchup_results AS
SELECT 
    m.matchup_id,
    m.league_id,
    l.name as league_name,
    m.week,
    m.season_id,
    s.year as season_year,
    m.matchup_number,
    m.is_playoff,
    m.is_consolation,
    -- Team 1 details
    mt1.roster_id as team1_roster_id,
    u1.display_name as team1_owner,
    mt1.points as team1_points,
    mt1.is_winner as team1_won,
    -- Team 2 details
    mt2.roster_id as team2_roster_id,
    u2.display_name as team2_owner,
    mt2.points as team2_points,
    mt2.is_winner as team2_won,
    -- Match details
    ABS(mt1.points - mt2.points) as point_margin
FROM matchups m
JOIN matchup_teams mt1 ON m.matchup_id = mt1.matchup_id
JOIN matchup_teams mt2 ON m.matchup_id = mt2.matchup_id AND mt1.matchup_team_id < mt2.matchup_team_id
LEFT JOIN rosters r1 ON mt1.roster_id = r1.roster_id
LEFT JOIN rosters r2 ON mt2.roster_id = r2.roster_id
LEFT JOIN users u1 ON r1.owner_user_id = u1.user_id
LEFT JOIN users u2 ON r2.owner_user_id = u2.user_id
LEFT JOIN leagues l ON m.league_id = l.league_id
LEFT JOIN seasons s ON m.season_id = s.season_id;

-- ============================================================================
-- RECENT TRANSACTIONS VIEW
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
    -- Get player adds
    STRING_AGG(
        CASE WHEN tp.action = 'add' 
        THEN p.full_name 
        ELSE NULL END, ', '
    ) as players_added,
    -- Get player drops
    STRING_AGG(
        CASE WHEN tp.action = 'drop' 
        THEN p.full_name 
        ELSE NULL END, ', '
    ) as players_dropped
FROM transactions t
LEFT JOIN leagues l ON t.league_id = l.league_id
LEFT JOIN users u ON t.creator_user_id = u.user_id
LEFT JOIN transaction_players tp ON t.transaction_id = tp.transaction_id
LEFT JOIN players p ON tp.player_id = p.player_id
GROUP BY t.transaction_id, t.league_id, l.name, t.type, t.status, 
         t.week, t.created_at, t.processed_at, u.display_name
ORDER BY t.created_at DESC;

-- ============================================================================
-- ROSTER COMPOSITION VIEW
-- ============================================================================

CREATE OR REPLACE VIEW roster_composition AS
SELECT 
    r.roster_id,
    r.league_id,
    l.name as league_name,
    r.roster_position,
    u.display_name as owner_name,
    -- Count players by position
    COUNT(CASE WHEN p.position = 'QB' THEN 1 END) as qb_count,
    COUNT(CASE WHEN p.position = 'RB' THEN 1 END) as rb_count,
    COUNT(CASE WHEN p.position = 'WR' THEN 1 END) as wr_count,
    COUNT(CASE WHEN p.position = 'TE' THEN 1 END) as te_count,
    COUNT(CASE WHEN p.position = 'K' THEN 1 END) as k_count,
    COUNT(CASE WHEN p.position = 'DEF' THEN 1 END) as def_count,
    COUNT(*) as total_players,
    -- List all players
    STRING_AGG(p.full_name || ' (' || p.position || ')', ', ' ORDER BY p.position, p.full_name) as all_players
FROM rosters r
LEFT JOIN leagues l ON r.league_id = l.league_id
LEFT JOIN users u ON r.owner_user_id = u.user_id
LEFT JOIN roster_players rp ON r.roster_id = rp.roster_id
LEFT JOIN players p ON rp.player_id = p.player_id
GROUP BY r.roster_id, r.league_id, l.name, r.roster_position, u.display_name;

-- ============================================================================
-- DRAFT RESULTS VIEW
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
FROM draft_picks dp
LEFT JOIN drafts d ON dp.draft_id = d.draft_id
LEFT JOIN leagues l ON d.league_id = l.league_id
LEFT JOIN seasons s ON d.season_id = s.season_id
LEFT JOIN rosters r ON dp.roster_id = r.roster_id
LEFT JOIN users u ON dp.picked_by_user_id = u.user_id
LEFT JOIN players p ON dp.player_id = p.player_id
ORDER BY dp.draft_id, dp.overall_pick;

-- ============================================================================
-- PLAYER OWNERSHIP VIEW
-- ============================================================================

CREATE OR REPLACE VIEW player_ownership AS
WITH total_leagues AS (
    SELECT COUNT(DISTINCT league_id) as total_league_count
    FROM leagues
    WHERE status = 'in_season'
)
SELECT 
    p.player_id,
    p.full_name,
    p.position,
    p.team_abbr,
    COUNT(DISTINCT rp.roster_id) as roster_count,
    COUNT(DISTINCT r.league_id) as league_count,
    ROUND(COUNT(DISTINCT r.league_id)::numeric / tl.total_league_count * 100, 2) as ownership_percentage
FROM players p
LEFT JOIN roster_players rp ON p.player_id = rp.player_id
LEFT JOIN rosters r ON rp.roster_id = r.roster_id
CROSS JOIN total_leagues tl
GROUP BY p.player_id, p.full_name, p.position, p.team_abbr, tl.total_league_count
ORDER BY roster_count DESC;