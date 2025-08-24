package repositories

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"github.com/mrab54/sleeper-db/sync-service/internal/api"
	"github.com/mrab54/sleeper-db/sync-service/internal/database"
	"go.uber.org/zap"
)

// PlayerRepository handles player-related database operations
type PlayerRepository struct {
	db     *database.DB
	logger *zap.Logger
}

// NewPlayerRepository creates a new player repository
func NewPlayerRepository(db *database.DB, logger *zap.Logger) *PlayerRepository {
	return &PlayerRepository{
		db:     db,
		logger: logger,
	}
}

// UpsertPlayer inserts or updates a player
func (r *PlayerRepository) UpsertPlayer(ctx context.Context, player *api.Player) error {
	query := `
		INSERT INTO sleeper.players (
			player_id, first_name, last_name, full_name, position, team,
			age, years_exp, college, weight, height, birth_date,
			birth_country, birth_state, birth_city,
			injury_status, injury_body_part, injury_start_date, injury_notes,
			practice_participation, practice_description,
			status, sport, search_first_name, search_last_name, search_full_name,
			depth_chart_position, depth_chart_order, metadata
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12,
			$13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23,
			$24, $25, $26, $27, $28, $29
		)
		ON CONFLICT (player_id) DO UPDATE SET
			first_name = EXCLUDED.first_name,
			last_name = EXCLUDED.last_name,
			full_name = EXCLUDED.full_name,
			position = EXCLUDED.position,
			team = EXCLUDED.team,
			age = EXCLUDED.age,
			years_exp = EXCLUDED.years_exp,
			college = EXCLUDED.college,
			weight = EXCLUDED.weight,
			height = EXCLUDED.height,
			injury_status = EXCLUDED.injury_status,
			injury_body_part = EXCLUDED.injury_body_part,
			injury_start_date = EXCLUDED.injury_start_date,
			injury_notes = EXCLUDED.injury_notes,
			practice_participation = EXCLUDED.practice_participation,
			practice_description = EXCLUDED.practice_description,
			status = EXCLUDED.status,
			depth_chart_position = EXCLUDED.depth_chart_position,
			depth_chart_order = EXCLUDED.depth_chart_order,
			metadata = EXCLUDED.metadata,
			updated_at = CURRENT_TIMESTAMP
	`

	// Parse weight and height (they come as strings)
	var weight, height *int
	if player.Weight != "" {
		if w, err := strconv.Atoi(player.Weight); err == nil {
			weight = &w
		}
	}
	if player.Height != "" {
		if h, err := strconv.Atoi(player.Height); err == nil {
			height = &h
		}
	}

	// Parse birth date
	var birthDate *time.Time
	if player.BirthDate != "" {
		if t, err := time.Parse("2006-01-02", player.BirthDate); err == nil {
			birthDate = &t
		}
	}

	// Parse injury start date
	var injuryStartDate *time.Time
	if player.InjuryStartDate != "" {
		if t, err := time.Parse("2006-01-02", player.InjuryStartDate); err == nil {
			injuryStartDate = &t
		}
	}

	_, err := r.db.Exec(ctx, query,
		player.PlayerID,
		player.FirstName,
		player.LastName,
		player.FullName,
		player.Position,
		player.Team,
		player.Age,
		player.YearsExp,
		player.College,
		weight,
		height,
		birthDate,
		player.BirthCountry,
		player.BirthState,
		player.BirthCity,
		player.InjuryStatus,
		player.InjuryBodyPart,
		injuryStartDate,
		player.InjuryNotes,
		player.PracticeParticipation,
		player.PracticeDescription,
		player.Status,
		player.Sport,
		player.SearchFirstName,
		player.SearchLastName,
		player.SearchFullName,
		player.DepthChartPosition,
		player.DepthChartOrder,
		player.Metadata,
	)

	if err != nil {
		r.logger.Error("Failed to upsert player",
			zap.String("player_id", player.PlayerID),
			zap.String("name", player.FullName),
			zap.Error(err),
		)
		return fmt.Errorf("failed to upsert player: %w", err)
	}

	return nil
}

// BulkUpsertPlayers efficiently upserts multiple players
func (r *PlayerRepository) BulkUpsertPlayers(ctx context.Context, players map[string]api.Player) error {
	tx, err := r.db.BeginTx(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	count := 0
	for _, player := range players {
		// Use the same upsert logic
		if err := r.UpsertPlayer(ctx, &player); err != nil {
			r.logger.Warn("Failed to upsert player in bulk operation",
				zap.String("player_id", player.PlayerID),
				zap.Error(err),
			)
			// Continue with other players
			continue
		}
		count++

		// Commit in batches
		if count%100 == 0 {
			if err := tx.Commit(ctx); err != nil {
				return fmt.Errorf("failed to commit batch: %w", err)
			}
			// Start new transaction
			tx, err = r.db.BeginTx(ctx)
			if err != nil {
				return fmt.Errorf("failed to begin new transaction: %w", err)
			}
		}
	}

	return tx.Commit(ctx)
}