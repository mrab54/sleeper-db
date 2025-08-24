package repositories

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mrab54/sleeper-db/sync-service/internal/api"
	"github.com/mrab54/sleeper-db/sync-service/internal/database"
	"go.uber.org/zap"
)

// MatchupRepository handles matchup-related database operations
type MatchupRepository struct {
	db     *database.DB
	logger *zap.Logger
}

// NewMatchupRepository creates a new matchup repository
func NewMatchupRepository(db *database.DB, logger *zap.Logger) *MatchupRepository {
	return &MatchupRepository{
		db:     db,
		logger: logger,
	}
}

// UpsertMatchup inserts or updates a matchup
func (r *MatchupRepository) UpsertMatchup(ctx context.Context, leagueID string, week int, matchup *api.Matchup) error {
	// First, get the internal roster_id from roster_number
	var rosterID int
	rosterQuery := `
		SELECT roster_id FROM sleeper.rosters
		WHERE league_id = $1 AND roster_number = $2
	`
	err := r.db.QueryRow(ctx, rosterQuery, leagueID, matchup.RosterID).Scan(&rosterID)
	if err != nil {
		return fmt.Errorf("failed to get roster_id: %w", err)
	}

	// Convert players_points map to JSONB
	playersPoints, err := json.Marshal(matchup.PlayersPoints)
	if err != nil {
		return fmt.Errorf("failed to marshal players points: %w", err)
	}

	query := `
		INSERT INTO sleeper.matchups (
			league_id, week, matchup_id, roster_id,
			points, custom_points, players_points
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7
		)
		ON CONFLICT (league_id, week, roster_id) DO UPDATE SET
			matchup_id = EXCLUDED.matchup_id,
			points = EXCLUDED.points,
			custom_points = EXCLUDED.custom_points,
			players_points = EXCLUDED.players_points,
			updated_at = CURRENT_TIMESTAMP
	`

	_, err = r.db.Exec(ctx, query,
		leagueID,
		week,
		matchup.MatchupID,
		rosterID,
		matchup.Points,
		matchup.CustomPoints,
		playersPoints,
	)

	if err != nil {
		r.logger.Error("Failed to upsert matchup",
			zap.String("league_id", leagueID),
			zap.Int("week", week),
			zap.Int("roster_id", rosterID),
			zap.Error(err),
		)
		return fmt.Errorf("failed to upsert matchup: %w", err)
	}

	return nil
}

// GetMatchupsByWeek retrieves all matchups for a specific week
func (r *MatchupRepository) GetMatchupsByWeek(ctx context.Context, leagueID string, week int) ([]*api.Matchup, error) {
	query := `
		SELECT m.matchup_id, r.roster_number, m.points, m.custom_points, m.players_points
		FROM sleeper.matchups m
		JOIN sleeper.rosters r ON m.roster_id = r.roster_id
		WHERE m.league_id = $1 AND m.week = $2
		ORDER BY m.matchup_id, r.roster_number
	`

	rows, err := r.db.Query(ctx, query, leagueID, week)
	if err != nil {
		return nil, fmt.Errorf("failed to query matchups: %w", err)
	}
	defer rows.Close()

	var matchups []*api.Matchup
	for rows.Next() {
		var matchup api.Matchup
		var playersPoints json.RawMessage

		err := rows.Scan(
			&matchup.MatchupID,
			&matchup.RosterID,
			&matchup.Points,
			&matchup.CustomPoints,
			&playersPoints,
		)

		if err != nil {
			return nil, fmt.Errorf("failed to scan matchup: %w", err)
		}

		// Unmarshal players points
		if err := json.Unmarshal(playersPoints, &matchup.PlayersPoints); err != nil {
			r.logger.Warn("Failed to unmarshal players points",
				zap.Int("matchup_id", matchup.MatchupID),
				zap.Error(err),
			)
		}

		matchups = append(matchups, &matchup)
	}

	return matchups, nil
}