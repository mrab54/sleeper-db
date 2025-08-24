package repositories

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mrab54/sleeper-db/sync-service/internal/api"
	"github.com/mrab54/sleeper-db/sync-service/internal/database"
	"go.uber.org/zap"
)

// RosterRepository handles roster-related database operations
type RosterRepository struct {
	db     *database.DB
	logger *zap.Logger
}

// NewRosterRepository creates a new roster repository
func NewRosterRepository(db *database.DB, logger *zap.Logger) *RosterRepository {
	return &RosterRepository{
		db:     db,
		logger: logger,
	}
}

// UpsertRoster inserts or updates a roster
func (r *RosterRepository) UpsertRoster(ctx context.Context, leagueID string, roster *api.Roster) error {
	tx, err := r.db.BeginTx(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// First, upsert the roster
	rosterQuery := `
		INSERT INTO sleeper.rosters (
			league_id, owner_id, roster_number, settings, metadata,
			starters, reserve, taxi
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8
		)
		ON CONFLICT (league_id, roster_number) DO UPDATE SET
			owner_id = EXCLUDED.owner_id,
			settings = EXCLUDED.settings,
			metadata = EXCLUDED.metadata,
			starters = EXCLUDED.starters,
			reserve = EXCLUDED.reserve,
			taxi = EXCLUDED.taxi,
			updated_at = CURRENT_TIMESTAMP
		RETURNING roster_id
	`

	// Convert arrays to JSONB
	starters, _ := json.Marshal(roster.Starters)
	reserve, _ := json.Marshal(roster.Reserve)
	taxi, _ := json.Marshal(roster.Taxi)

	var rosterID int
	err = tx.QueryRow(ctx, rosterQuery,
		leagueID,
		roster.OwnerID,
		roster.RosterID, // This is actually roster_number from API
		roster.Settings,
		roster.Metadata,
		starters,
		reserve,
		taxi,
	).Scan(&rosterID)

	if err != nil {
		return fmt.Errorf("failed to upsert roster: %w", err)
	}

	// Delete existing roster players
	deleteQuery := `DELETE FROM sleeper.roster_players WHERE roster_id = $1`
	_, err = tx.Exec(ctx, deleteQuery, rosterID)
	if err != nil {
		return fmt.Errorf("failed to delete existing roster players: %w", err)
	}

	// Insert new roster players
	if len(roster.Players) > 0 {
		insertQuery := `
			INSERT INTO sleeper.roster_players (roster_id, player_id, status)
			VALUES ($1, $2, $3)
		`

		for _, playerID := range roster.Players {
			// Determine if player is a starter
			status := "bench"
			for _, starterID := range roster.Starters {
				if playerID == starterID {
					status = "starter"
					break
				}
			}

			_, err = tx.Exec(ctx, insertQuery, rosterID, playerID, status)
			if err != nil {
				r.logger.Warn("Failed to insert roster player",
					zap.Int("roster_id", rosterID),
					zap.String("player_id", playerID),
					zap.Error(err),
				)
				// Continue with other players
			}
		}
	}

	// Parse and update roster settings (wins, losses, etc.)
	if roster.Settings != nil {
		var settings api.RosterSettings
		if err := json.Unmarshal(roster.Settings, &settings); err == nil {
			updateQuery := `
				UPDATE sleeper.rosters
				SET wins = $2, losses = $3, ties = $4,
				    points_for = $5, points_against = $6
				WHERE roster_id = $1
			`
			_, err = tx.Exec(ctx, updateQuery,
				rosterID,
				settings.Wins,
				settings.Losses,
				settings.Ties,
				settings.Fpts+settings.FptsDecimal,
				settings.FptsAgainst+settings.FptsAgainstDecimal,
			)
			if err != nil {
				r.logger.Warn("Failed to update roster settings",
					zap.Int("roster_id", rosterID),
					zap.Error(err),
				)
			}
		}
	}

	return tx.Commit(ctx)
}

// GetRostersByLeague retrieves all rosters for a league
func (r *RosterRepository) GetRostersByLeague(ctx context.Context, leagueID string) ([]*api.Roster, error) {
	query := `
		SELECT roster_id, owner_id, roster_number, settings, metadata,
		       starters, reserve, taxi
		FROM sleeper.rosters
		WHERE league_id = $1
		ORDER BY roster_number
	`

	rows, err := r.db.Query(ctx, query, leagueID)
	if err != nil {
		return nil, fmt.Errorf("failed to query rosters: %w", err)
	}
	defer rows.Close()

	var rosters []*api.Roster
	for rows.Next() {
		var roster api.Roster
		var dbRosterID int
		var starters, reserve, taxi json.RawMessage

		err := rows.Scan(
			&dbRosterID,
			&roster.OwnerID,
			&roster.RosterID, // This maps to roster_number
			&roster.Settings,
			&roster.Metadata,
			&starters,
			&reserve,
			&taxi,
		)

		if err != nil {
			return nil, fmt.Errorf("failed to scan roster: %w", err)
		}

		// Unmarshal arrays
		json.Unmarshal(starters, &roster.Starters)
		json.Unmarshal(reserve, &roster.Reserve)
		json.Unmarshal(taxi, &roster.Taxi)

		// Get players for this roster
		playersQuery := `
			SELECT player_id FROM sleeper.roster_players
			WHERE roster_id = $1
		`
		playerRows, err := r.db.Query(ctx, playersQuery, dbRosterID)
		if err == nil {
			defer playerRows.Close()
			for playerRows.Next() {
				var playerID string
				if err := playerRows.Scan(&playerID); err == nil {
					roster.Players = append(roster.Players, playerID)
				}
			}
		}

		rosters = append(rosters, &roster)
	}

	return rosters, nil
}