package repositories

import (
	"context"
	"fmt"
	"strconv"
	"strings"
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
			player_id, first_name, last_name, full_name, search_full_name, position, 
			fantasy_positions, team, status, injury_status, injury_body_part, 
			injury_notes, number, years_exp, age, birth_date, height, weight, 
			college, espn_id, yahoo_id, fantasy_data_id, metadata, active
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, 
			$16, $17, $18, $19, $20, $21, $22, $23, $24
		)
		ON CONFLICT (player_id) DO UPDATE SET
			first_name = EXCLUDED.first_name,
			last_name = EXCLUDED.last_name,
			full_name = EXCLUDED.full_name,
			search_full_name = EXCLUDED.search_full_name,
			position = EXCLUDED.position,
			fantasy_positions = EXCLUDED.fantasy_positions,
			team = EXCLUDED.team,
			status = EXCLUDED.status,
			injury_status = EXCLUDED.injury_status,
			injury_body_part = EXCLUDED.injury_body_part,
			injury_notes = EXCLUDED.injury_notes,
			number = EXCLUDED.number,
			years_exp = EXCLUDED.years_exp,
			age = EXCLUDED.age,
			birth_date = EXCLUDED.birth_date,
			height = EXCLUDED.height,
			weight = EXCLUDED.weight,
			college = EXCLUDED.college,
			espn_id = EXCLUDED.espn_id,
			yahoo_id = EXCLUDED.yahoo_id,
			fantasy_data_id = EXCLUDED.fantasy_data_id,
			metadata = EXCLUDED.metadata,
			active = EXCLUDED.active,
			updated_at = CURRENT_TIMESTAMP
	`

	// Parse weight (comes as string, store as int)
	var weight *int
	if player.Weight != nil && *player.Weight != "" {
		if w, err := strconv.Atoi(*player.Weight); err == nil {
			weight = &w
		}
	}

	// Parse birth date
	var birthDate *time.Time
	if player.BirthDate != nil && *player.BirthDate != "" {
		if t, err := time.Parse("2006-01-02", *player.BirthDate); err == nil {
			birthDate = &t
		}
	}

	// Convert EspnID from int to string for database
	var espnID *string
	if player.EspnID != nil {
		espnIDStr := strconv.Itoa(*player.EspnID)
		espnID = &espnIDStr
	}

	// Convert YahooID from int to string for database
	var yahooID *string
	if player.YahooID != nil {
		yahooIDStr := strconv.Itoa(*player.YahooID)
		yahooID = &yahooIDStr
	}

	// Convert FantasyDataID from int to string for database
	var fantasyDataID *string
	if player.FantasyDataID != nil {
		fantasyDataIDStr := strconv.Itoa(*player.FantasyDataID)
		fantasyDataID = &fantasyDataIDStr
	}

	// Convert Status to lowercase and replace spaces with underscores for enum compatibility
	var status *string
	if player.Status != nil {
		statusConverted := strings.ToLower(*player.Status)
		statusConverted = strings.ReplaceAll(statusConverted, " ", "_")
		status = &statusConverted
	}

	_, err := r.db.Exec(ctx, query,
		player.PlayerID,              // $1
		player.FirstName,             // $2
		player.LastName,              // $3
		player.FullName,              // $4
		player.SearchFullName,        // $5
		player.Position,              // $6
		player.FantasyPositions,      // $7
		player.Team,                  // $8
		status,                       // $9
		player.InjuryStatus,          // $10
		player.InjuryBodyPart,        // $11
		player.InjuryNotes,           // $12
		player.Number,                // $13
		player.YearsExp,              // $14
		player.Age,                   // $15
		birthDate,                    // $16
		player.Height,                // $17 (height is stored as varchar in DB)
		weight,                       // $18
		player.College,               // $19
		espnID,                       // $20
		yahooID,                      // $21
		fantasyDataID,                // $22
		player.Metadata,              // $23
		player.Active,                // $24
	)

	if err != nil {
		var fullName string
		if player.FullName != nil {
			fullName = *player.FullName
		}
		r.logger.Error("Failed to upsert player",
			zap.String("player_id", player.PlayerID),
			zap.String("name", fullName),
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