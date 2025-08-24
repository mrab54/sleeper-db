package repositories

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/mrab54/sleeper-db/sync-service/internal/api"
	"github.com/mrab54/sleeper-db/sync-service/internal/database"
	"go.uber.org/zap"
)

// LeagueRepository handles league-related database operations
type LeagueRepository struct {
	db     *database.DB
	logger *zap.Logger
}

// NewLeagueRepository creates a new league repository
func NewLeagueRepository(db *database.DB, logger *zap.Logger) *LeagueRepository {
	return &LeagueRepository{
		db:     db,
		logger: logger,
	}
}

// UpsertLeague inserts or updates a league
func (r *LeagueRepository) UpsertLeague(ctx context.Context, league *api.League) error {
	query := `
		INSERT INTO sleeper.leagues (
			league_id, name, season, status, sport, total_rosters,
			settings, scoring_settings, roster_positions, metadata,
			previous_league_id, draft_id
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
		)
		ON CONFLICT (league_id) DO UPDATE SET
			name = EXCLUDED.name,
			status = EXCLUDED.status,
			settings = EXCLUDED.settings,
			scoring_settings = EXCLUDED.scoring_settings,
			roster_positions = EXCLUDED.roster_positions,
			metadata = EXCLUDED.metadata,
			updated_at = CURRENT_TIMESTAMP
	`

	// Convert roster_positions to JSONB
	rosterPositions, err := json.Marshal(league.RosterPositions)
	if err != nil {
		return fmt.Errorf("failed to marshal roster positions: %w", err)
	}

	// Convert season string to int
	var season int
	if _, err := fmt.Sscanf(league.Season, "%d", &season); err != nil {
		return fmt.Errorf("failed to parse season: %w", err)
	}

	_, err = r.db.Exec(ctx, query,
		league.LeagueID,
		league.Name,
		season,
		league.Status,
		league.Sport,
		league.TotalRosters,
		league.Settings,
		league.ScoringSettings,
		rosterPositions,
		league.Metadata,
		league.PreviousLeagueID,
		league.DraftID,
	)

	if err != nil {
		r.logger.Error("Failed to upsert league",
			zap.String("league_id", league.LeagueID),
			zap.Error(err),
		)
		return fmt.Errorf("failed to upsert league: %w", err)
	}

	r.logger.Info("League upserted successfully",
		zap.String("league_id", league.LeagueID),
		zap.String("name", league.Name),
	)

	return nil
}

// GetLeague retrieves a league by ID
func (r *LeagueRepository) GetLeague(ctx context.Context, leagueID string) (*api.League, error) {
	query := `
		SELECT 
			league_id, name, season, status, sport, total_rosters,
			settings, scoring_settings, roster_positions, metadata,
			previous_league_id, draft_id
		FROM sleeper.leagues
		WHERE league_id = $1
	`

	var league api.League
	var season int
	var rosterPositions json.RawMessage

	err := r.db.QueryRow(ctx, query, leagueID).Scan(
		&league.LeagueID,
		&league.Name,
		&season,
		&league.Status,
		&league.Sport,
		&league.TotalRosters,
		&league.Settings,
		&league.ScoringSettings,
		&rosterPositions,
		&league.Metadata,
		&league.PreviousLeagueID,
		&league.DraftID,
	)

	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get league: %w", err)
	}

	// Convert season int to string
	league.Season = fmt.Sprintf("%d", season)

	// Unmarshal roster positions
	if err := json.Unmarshal(rosterPositions, &league.RosterPositions); err != nil {
		return nil, fmt.Errorf("failed to unmarshal roster positions: %w", err)
	}

	return &league, nil
}

// GetLeaguesBySeason retrieves all leagues for a season
func (r *LeagueRepository) GetLeaguesBySeason(ctx context.Context, season int) ([]*api.League, error) {
	query := `
		SELECT 
			league_id, name, season, status, sport, total_rosters,
			settings, scoring_settings, roster_positions, metadata,
			previous_league_id, draft_id
		FROM sleeper.leagues
		WHERE season = $1
		ORDER BY created_at DESC
	`

	rows, err := r.db.Query(ctx, query, season)
	if err != nil {
		return nil, fmt.Errorf("failed to query leagues: %w", err)
	}
	defer rows.Close()

	var leagues []*api.League
	for rows.Next() {
		var league api.League
		var seasonInt int
		var rosterPositions json.RawMessage

		err := rows.Scan(
			&league.LeagueID,
			&league.Name,
			&seasonInt,
			&league.Status,
			&league.Sport,
			&league.TotalRosters,
			&league.Settings,
			&league.ScoringSettings,
			&rosterPositions,
			&league.Metadata,
			&league.PreviousLeagueID,
			&league.DraftID,
		)

		if err != nil {
			return nil, fmt.Errorf("failed to scan league: %w", err)
		}

		// Convert season int to string
		league.Season = fmt.Sprintf("%d", seasonInt)

		// Unmarshal roster positions
		if err := json.Unmarshal(rosterPositions, &league.RosterPositions); err != nil {
			return nil, fmt.Errorf("failed to unmarshal roster positions: %w", err)
		}

		leagues = append(leagues, &league)
	}

	return leagues, nil
}