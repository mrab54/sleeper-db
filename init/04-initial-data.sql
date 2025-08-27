-- Sleeper Fantasy Football Database Initial Data
-- PostgreSQL 17
--
-- This script inserts initial reference data

-- Set search path to our schema
SET search_path TO sleeper, public;

-- ============================================================================
-- SPORTS
-- ============================================================================

INSERT INTO sports (sport_id, sport_name, is_active) VALUES
('nfl', 'National Football League', true)
ON CONFLICT (sport_id) DO NOTHING;

-- ============================================================================
-- NFL TEAMS (2024 Season)
-- ============================================================================

INSERT INTO nfl_teams (team_abbr, team_name, conference, division, is_active) VALUES
-- AFC East
('BUF', 'Buffalo Bills', 'AFC', 'East', true),
('MIA', 'Miami Dolphins', 'AFC', 'East', true),
('NE', 'New England Patriots', 'AFC', 'East', true),
('NYJ', 'New York Jets', 'AFC', 'East', true),
-- AFC North
('BAL', 'Baltimore Ravens', 'AFC', 'North', true),
('CIN', 'Cincinnati Bengals', 'AFC', 'North', true),
('CLE', 'Cleveland Browns', 'AFC', 'North', true),
('PIT', 'Pittsburgh Steelers', 'AFC', 'North', true),
-- AFC South
('HOU', 'Houston Texans', 'AFC', 'South', true),
('IND', 'Indianapolis Colts', 'AFC', 'South', true),
('JAX', 'Jacksonville Jaguars', 'AFC', 'South', true),
('TEN', 'Tennessee Titans', 'AFC', 'South', true),
-- AFC West
('DEN', 'Denver Broncos', 'AFC', 'West', true),
('KC', 'Kansas City Chiefs', 'AFC', 'West', true),
('LV', 'Las Vegas Raiders', 'AFC', 'West', true),
('LAC', 'Los Angeles Chargers', 'AFC', 'West', true),
-- NFC East
('DAL', 'Dallas Cowboys', 'NFC', 'East', true),
('NYG', 'New York Giants', 'NFC', 'East', true),
('PHI', 'Philadelphia Eagles', 'NFC', 'East', true),
('WAS', 'Washington Commanders', 'NFC', 'East', true),
-- NFC North
('CHI', 'Chicago Bears', 'NFC', 'North', true),
('DET', 'Detroit Lions', 'NFC', 'North', true),
('GB', 'Green Bay Packers', 'NFC', 'North', true),
('MIN', 'Minnesota Vikings', 'NFC', 'North', true),
-- NFC South
('ATL', 'Atlanta Falcons', 'NFC', 'South', true),
('CAR', 'Carolina Panthers', 'NFC', 'South', true),
('NO', 'New Orleans Saints', 'NFC', 'South', true),
('TB', 'Tampa Bay Buccaneers', 'NFC', 'South', true),
-- NFC West
('ARI', 'Arizona Cardinals', 'NFC', 'West', true),
('LAR', 'Los Angeles Rams', 'NFC', 'West', true),
('SF', 'San Francisco 49ers', 'NFC', 'West', true),
('SEA', 'Seattle Seahawks', 'NFC', 'West', true)
ON CONFLICT (team_abbr) DO NOTHING;

-- ============================================================================
-- INITIAL SEASON (2025)
-- ============================================================================

INSERT INTO seasons (sport_id, year, season_type, is_current) VALUES
('nfl', '2025', 'regular', true)
ON CONFLICT (sport_id, year) DO NOTHING;