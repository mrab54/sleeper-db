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
	// Start transaction
	tx, err := r.db.BeginTx(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Insert/update main league record
	leagueQuery := `
		INSERT INTO sleeper.leagues (
			league_id, name, season, status, sport, total_rosters,
			metadata, previous_league_id, draft_id
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9
		)
		ON CONFLICT (league_id) DO UPDATE SET
			name = EXCLUDED.name,
			status = EXCLUDED.status,
			metadata = EXCLUDED.metadata,
			updated_at = CURRENT_TIMESTAMP
	`

	// Handle empty previous_league_id or self-reference
	var previousLeagueID interface{} = nil
	if league.PreviousLeagueID != "" && league.PreviousLeagueID != league.LeagueID {
		// Check if the previous league exists
		var exists bool
		checkQuery := `SELECT EXISTS(SELECT 1 FROM sleeper.leagues WHERE league_id = $1)`
		err := tx.QueryRow(ctx, checkQuery, league.PreviousLeagueID).Scan(&exists)
		if err == nil && exists {
			previousLeagueID = league.PreviousLeagueID
		}
		// If it doesn't exist, leave as NULL
	}

	// Handle empty draft_id
	var draftID interface{} = nil
	if league.DraftID != "" {
		draftID = league.DraftID
	}

	_, err = tx.Exec(ctx, leagueQuery,
		league.LeagueID,
		league.Name,
		league.Season,
		league.Status,
		league.Sport,
		league.TotalRosters,
		league.Metadata,
		previousLeagueID,
		draftID,
	)

	if err != nil {
		r.logger.Error("Failed to upsert league",
			zap.String("league_id", league.LeagueID),
			zap.Error(err),
		)
		return fmt.Errorf("failed to upsert league: %w", err)
	}

	// Insert/update league settings if provided
	if league.Settings != nil {
		settingsQuery := `
			INSERT INTO sleeper.league_settings (league_id, settings_json)
			VALUES ($1, $2)
			ON CONFLICT (league_id) DO UPDATE SET
				settings_json = EXCLUDED.settings_json,
				updated_at = CURRENT_TIMESTAMP
		`
		_, err = tx.Exec(ctx, settingsQuery, league.LeagueID, league.Settings)
		if err != nil {
			return fmt.Errorf("failed to upsert league settings: %w", err)
		}
	}

	// Insert/update scoring settings if provided
	if league.ScoringSettings != nil {
		scoringQuery := `
			INSERT INTO sleeper.league_scoring_settings (league_id, scoring_json)
			VALUES ($1, $2)
			ON CONFLICT (league_id) DO UPDATE SET
				scoring_json = EXCLUDED.scoring_json,
				updated_at = CURRENT_TIMESTAMP
		`
		_, err = tx.Exec(ctx, scoringQuery, league.LeagueID, league.ScoringSettings)
		if err != nil {
			return fmt.Errorf("failed to upsert scoring settings: %w", err)
		}
	}

	// Commit transaction
	if err = tx.Commit(ctx); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
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