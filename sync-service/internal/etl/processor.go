package etl

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/mrab54/sleeper-db/sync-service/internal/database"
	"github.com/mrab54/sleeper-db/sync-service/internal/database/repositories"
	"go.uber.org/zap"
)

// Processor handles ETL operations from raw to analytics database
type Processor struct {
	dbAnalytics *database.DB
	dbRaw       *database.DB
	rawRepo     *repositories.RawRepository
	logger      *zap.Logger
	batchSize   int
}

// NewProcessor creates a new ETL processor
func NewProcessor(dbAnalytics, dbRaw *database.DB, logger *zap.Logger) *Processor {
	return &Processor{
		dbAnalytics: dbAnalytics,
		dbRaw:       dbRaw,
		rawRepo:     repositories.NewRawRepository(dbRaw.Pool()),
		logger:      logger,
		batchSize:   100, // Process 100 records at a time
	}
}

// ProcessResult represents the result of an ETL process
type ProcessResult struct {
	TotalProcessed   int
	SuccessCount     int
	ErrorCount       int
	SkippedCount     int
	ProcessingTimeMs int64
	Errors           []ProcessError
}

// ProcessError represents an error during processing
type ProcessError struct {
	ResponseID int64
	Endpoint   string
	Error      string
	Timestamp  time.Time
}

// ProcessUnprocessedResponses processes all unprocessed raw responses
func (p *Processor) ProcessUnprocessedResponses(ctx context.Context) (*ProcessResult, error) {
	startTime := time.Now()
	result := &ProcessResult{}

	for {
		// Get batch of unprocessed responses
		responses, err := p.rawRepo.GetUnprocessedResponses(ctx, p.batchSize)
		if err != nil {
			return result, fmt.Errorf("failed to get unprocessed responses: %w", err)
		}

		if len(responses) == 0 {
			break // No more unprocessed responses
		}

		// Process each response
		for _, resp := range responses {
			err := p.processResponse(ctx, resp)
			if err != nil {
				p.logger.Error("Failed to process response",
					zap.Int64("response_id", resp.ID),
					zap.String("endpoint", resp.Endpoint),
					zap.Error(err),
				)
				result.ErrorCount++
				result.Errors = append(result.Errors, ProcessError{
					ResponseID: resp.ID,
					Endpoint:   resp.Endpoint,
					Error:      err.Error(),
					Timestamp:  time.Now(),
				})
				
				// Mark as failed in raw database
				p.rawRepo.MarkResponseProcessed(ctx, resp.ID, "failed", err.Error())
			} else {
				result.SuccessCount++
				// Mark as processed in raw database
				p.rawRepo.MarkResponseProcessed(ctx, resp.ID, "processed", "")
			}
			result.TotalProcessed++
		}
	}

	result.ProcessingTimeMs = time.Since(startTime).Milliseconds()
	return result, nil
}

// processResponse processes a single raw response based on its type
func (p *Processor) processResponse(ctx context.Context, resp *repositories.APIResponse) error {
	switch resp.EndpointType {
	case "league":
		return p.processLeague(ctx, resp)
	case "users":
		return p.processUsers(ctx, resp)
	case "rosters":
		return p.processRosters(ctx, resp)
	case "matchups":
		return p.processMatchups(ctx, resp)
	case "transactions":
		return p.processTransactions(ctx, resp)
	case "players":
		return p.processPlayers(ctx, resp)
	case "nfl_state":
		return p.processNFLState(ctx, resp)
	default:
		return fmt.Errorf("unknown endpoint type: %s", resp.EndpointType)
	}
}

// processLeague transforms and inserts league data
func (p *Processor) processLeague(ctx context.Context, resp *repositories.APIResponse) error {
	var league map[string]interface{}
	if err := json.Unmarshal(resp.ResponseBody, &league); err != nil {
		return fmt.Errorf("failed to unmarshal league data: %w", err)
	}

	tx, err := p.dbAnalytics.BeginTx(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Extract league data
	leagueID := getString(league, "league_id")
	name := getString(league, "name")
	season := getString(league, "season")
	sport := getString(league, "sport")
	status := getString(league, "status")
	totalRosters := getInt(league, "total_rosters")
	draftID := getString(league, "draft_id")
	previousLeagueID := getString(league, "previous_league_id")

	// Insert league
	leagueQuery := `
		INSERT INTO analytics.leagues (
			league_id, name, season, sport, status,
			total_rosters, draft_id, previous_league_id
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		ON CONFLICT (league_id) DO UPDATE SET
			name = EXCLUDED.name,
			status = EXCLUDED.status,
			total_rosters = EXCLUDED.total_rosters,
			updated_at = NOW()
	`
	
	_, err = tx.Exec(ctx, leagueQuery,
		leagueID, name, season, sport, status,
		totalRosters, draftID, previousLeagueID,
	)
	if err != nil {
		return fmt.Errorf("failed to insert league: %w", err)
	}

	// Process league settings
	if settings, ok := league["settings"].(map[string]interface{}); ok {
		err = p.processLeagueSettings(ctx, tx, leagueID, settings)
		if err != nil {
			return fmt.Errorf("failed to process league settings: %w", err)
		}
	}

	// Process scoring settings
	if scoringSettings, ok := league["scoring_settings"].(map[string]interface{}); ok {
		err = p.processLeagueScoringSettings(ctx, tx, leagueID, scoringSettings)
		if err != nil {
			return fmt.Errorf("failed to process scoring settings: %w", err)
		}
	}

	return tx.Commit(ctx)
}

// processLeagueSettings inserts league settings
func (p *Processor) processLeagueSettings(ctx context.Context, tx pgx.Tx, leagueID string, settings map[string]interface{}) error {
	query := `
		INSERT INTO analytics.league_settings (
			league_id, playoff_week_start, leg, max_keepers,
			draft_rounds, trade_deadline, waiver_type, waiver_day_of_week,
			waiver_budget, reserve_slots, taxi_slots, waiver_clear_days
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		ON CONFLICT (league_id) DO UPDATE SET
			playoff_week_start = EXCLUDED.playoff_week_start,
			leg = EXCLUDED.leg,
			max_keepers = EXCLUDED.max_keepers,
			draft_rounds = EXCLUDED.draft_rounds,
			trade_deadline = EXCLUDED.trade_deadline,
			waiver_type = EXCLUDED.waiver_type,
			waiver_day_of_week = EXCLUDED.waiver_day_of_week,
			waiver_budget = EXCLUDED.waiver_budget,
			reserve_slots = EXCLUDED.reserve_slots,
			taxi_slots = EXCLUDED.taxi_slots,
			waiver_clear_days = EXCLUDED.waiver_clear_days,
			updated_at = NOW()
	`

	// Extract waiver clear days array
	var waiverClearDays []int
	if days, ok := settings["waiver_clear_days"].([]interface{}); ok {
		for _, d := range days {
			if day, ok := d.(float64); ok {
				waiverClearDays = append(waiverClearDays, int(day))
			}
		}
	}

	_, err := tx.Exec(ctx, query,
		leagueID,
		getInt(settings, "playoff_week_start"),
		getInt(settings, "leg"),
		getInt(settings, "max_keepers"),
		getInt(settings, "draft_rounds"),
		getInt(settings, "trade_deadline"),
		getInt(settings, "waiver_type"),
		getInt(settings, "waiver_day_of_week"),
		getInt(settings, "waiver_budget"),
		getInt(settings, "reserve_slots"),
		getInt(settings, "taxi_slots"),
		waiverClearDays,
	)
	
	return err
}

// processLeagueScoringSettings inserts league scoring settings
func (p *Processor) processLeagueScoringSettings(ctx context.Context, tx pgx.Tx, leagueID string, scoring map[string]interface{}) error {
	query := `
		INSERT INTO analytics.league_scoring_settings (
			league_id, pass_td, pass_yd, pass_int, pass_2pt,
			rush_td, rush_yd, rush_2pt,
			rec_td, rec_yd, rec, rec_2pt,
			fum_lost, fum_rec_td
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
		ON CONFLICT (league_id) DO UPDATE SET
			pass_td = EXCLUDED.pass_td,
			pass_yd = EXCLUDED.pass_yd,
			pass_int = EXCLUDED.pass_int,
			pass_2pt = EXCLUDED.pass_2pt,
			rush_td = EXCLUDED.rush_td,
			rush_yd = EXCLUDED.rush_yd,
			rush_2pt = EXCLUDED.rush_2pt,
			rec_td = EXCLUDED.rec_td,
			rec_yd = EXCLUDED.rec_yd,
			rec = EXCLUDED.rec,
			rec_2pt = EXCLUDED.rec_2pt,
			fum_lost = EXCLUDED.fum_lost,
			fum_rec_td = EXCLUDED.fum_rec_td,
			updated_at = NOW()
	`

	_, err := tx.Exec(ctx, query,
		leagueID,
		getFloat(scoring, "pass_td"),
		getFloat(scoring, "pass_yd"),
		getFloat(scoring, "pass_int"),
		getFloat(scoring, "pass_2pt"),
		getFloat(scoring, "rush_td"),
		getFloat(scoring, "rush_yd"),
		getFloat(scoring, "rush_2pt"),
		getFloat(scoring, "rec_td"),
		getFloat(scoring, "rec_yd"),
		getFloat(scoring, "rec"),
		getFloat(scoring, "rec_2pt"),
		getFloat(scoring, "fum_lost"),
		getFloat(scoring, "fum_rec_td"),
	)
	
	return err
}

// processUsers transforms and inserts user data
func (p *Processor) processUsers(ctx context.Context, resp *repositories.APIResponse) error {
	var users []map[string]interface{}
	if err := json.Unmarshal(resp.ResponseBody, &users); err != nil {
		return fmt.Errorf("failed to unmarshal users data: %w", err)
	}

	tx, err := p.dbAnalytics.BeginTx(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	query := `
		INSERT INTO analytics.users (
			user_id, username, display_name, avatar, is_bot
		) VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (user_id) DO UPDATE SET
			username = EXCLUDED.username,
			display_name = EXCLUDED.display_name,
			avatar = EXCLUDED.avatar,
			is_bot = EXCLUDED.is_bot,
			updated_at = NOW()
	`

	for _, user := range users {
		userID := getString(user, "user_id")
		username := getString(user, "username")
		displayName := getString(user, "display_name")
		if displayName == "" {
			displayName = username
		}
		avatar := getString(user, "avatar")
		isBot := getBool(user, "is_bot")

		_, err = tx.Exec(ctx, query, userID, username, displayName, avatar, isBot)
		if err != nil {
			return fmt.Errorf("failed to insert user %s: %w", userID, err)
		}
	}

	return tx.Commit(ctx)
}

// processRosters transforms and inserts roster data
func (p *Processor) processRosters(ctx context.Context, resp *repositories.APIResponse) error {
	var rosters []map[string]interface{}
	if err := json.Unmarshal(resp.ResponseBody, &rosters); err != nil {
		return fmt.Errorf("failed to unmarshal rosters data: %w", err)
	}

	// Extract league_id from endpoint (format: /league/{league_id}/rosters)
	leagueID := extractLeagueIDFromEndpoint(resp.Endpoint)
	if leagueID == "" {
		return fmt.Errorf("could not extract league_id from endpoint: %s", resp.Endpoint)
	}

	tx, err := p.dbAnalytics.BeginTx(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	for _, roster := range rosters {
		// Insert roster
		rosterNumber := getInt(roster, "roster_id")
		
		rosterQuery := `
			INSERT INTO analytics.rosters (
				league_id, roster_number, current_owner_id
			) VALUES ($1, $2, $3)
			ON CONFLICT (league_id, roster_number) DO UPDATE SET
				current_owner_id = EXCLUDED.current_owner_id,
				updated_at = NOW()
			RETURNING roster_id
		`
		
		var rosterID int
		ownerID := getString(roster, "owner_id")
		err = tx.QueryRow(ctx, rosterQuery, leagueID, rosterNumber, ownerID).Scan(&rosterID)
		if err != nil {
			return fmt.Errorf("failed to insert roster: %w", err)
		}

		// Process roster ownership (including co-owners)
		err = p.processRosterOwnership(ctx, tx, rosterID, roster, time.Now())
		if err != nil {
			return fmt.Errorf("failed to process roster ownership: %w", err)
		}

		// Process roster stats
		err = p.processRosterStats(ctx, tx, rosterID, roster)
		if err != nil {
			return fmt.Errorf("failed to process roster stats: %w", err)
		}

		// Process roster players
		if players, ok := roster["players"].([]interface{}); ok {
			err = p.processRosterPlayers(ctx, tx, rosterID, players, time.Now())
			if err != nil {
				return fmt.Errorf("failed to process roster players: %w", err)
			}
		}
	}

	return tx.Commit(ctx)
}

// processRosterOwnership inserts roster ownership records
func (p *Processor) processRosterOwnership(ctx context.Context, tx pgx.Tx, rosterID int, roster map[string]interface{}, validFrom time.Time) error {
	// Primary owner
	ownerID := getString(roster, "owner_id")
	if ownerID != "" {
		query := `
			INSERT INTO analytics.roster_ownership (
				roster_id, user_id, is_primary, valid_from
			) VALUES ($1, $2, true, $3)
			ON CONFLICT (roster_id, user_id) WHERE valid_to = '9999-12-31'::timestamptz
			DO UPDATE SET updated_at = NOW()
		`
		_, err := tx.Exec(ctx, query, rosterID, ownerID, validFrom)
		if err != nil {
			return err
		}
	}

	// Co-owners
	if coOwners, ok := roster["co_owners"].([]interface{}); ok {
		for _, coOwner := range coOwners {
			if coOwnerID, ok := coOwner.(string); ok && coOwnerID != "" {
				query := `
					INSERT INTO analytics.roster_ownership (
						roster_id, user_id, is_primary, valid_from
					) VALUES ($1, $2, false, $3)
					ON CONFLICT (roster_id, user_id) WHERE valid_to = '9999-12-31'::timestamptz
					DO UPDATE SET updated_at = NOW()
				`
				_, err := tx.Exec(ctx, query, rosterID, coOwnerID, validFrom)
				if err != nil {
					return err
				}
			}
		}
	}

	return nil
}

// processRosterStats inserts roster statistics
func (p *Processor) processRosterStats(ctx context.Context, tx pgx.Tx, rosterID int, roster map[string]interface{}) error {
	// Get settings for extracting stats
	settings := getMap(roster, "settings")
	
	query := `
		INSERT INTO analytics.roster_stats (
			roster_id, wins, losses, ties, points_for, points_against,
			waiver_position, waiver_budget_used, total_moves
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT (roster_id) DO UPDATE SET
			wins = EXCLUDED.wins,
			losses = EXCLUDED.losses,
			ties = EXCLUDED.ties,
			points_for = EXCLUDED.points_for,
			points_against = EXCLUDED.points_against,
			waiver_position = EXCLUDED.waiver_position,
			waiver_budget_used = EXCLUDED.waiver_budget_used,
			total_moves = EXCLUDED.total_moves,
			updated_at = NOW()
	`

	_, err := tx.Exec(ctx, query,
		rosterID,
		getInt(settings, "wins"),
		getInt(settings, "losses"),
		getInt(settings, "ties"),
		getFloat(settings, "fpts"),
		getFloat(settings, "fpts_against"),
		getInt(settings, "waiver_position"),
		getInt(settings, "waiver_budget_used"),
		getInt(settings, "total_moves"),
	)
	
	return err
}

// processRosterPlayers inserts roster player relationships
func (p *Processor) processRosterPlayers(ctx context.Context, tx pgx.Tx, rosterID int, players []interface{}, validFrom time.Time) error {
	// First, mark all existing players for this roster as no longer valid
	updateQuery := `
		UPDATE analytics.roster_players 
		SET valid_to = $2
		WHERE roster_id = $1 AND valid_to = '9999-12-31'::timestamptz
	`
	_, err := tx.Exec(ctx, updateQuery, rosterID, validFrom)
	if err != nil {
		return err
	}

	// Insert new player relationships
	insertQuery := `
		INSERT INTO analytics.roster_players (
			roster_id, player_id, valid_from
		) VALUES ($1, $2, $3)
		ON CONFLICT DO NOTHING
	`

	for _, player := range players {
		if playerID, ok := player.(string); ok && playerID != "" {
			_, err := tx.Exec(ctx, insertQuery, rosterID, playerID, validFrom)
			if err != nil {
				return err
			}
		}
	}

	return nil
}

// Helper functions to extract data from maps
func getString(m map[string]interface{}, key string) string {
	if v, ok := m[key].(string); ok {
		return v
	}
	return ""
}

func getInt(m map[string]interface{}, key string) int {
	if v, ok := m[key].(float64); ok {
		return int(v)
	}
	return 0
}

func getFloat(m map[string]interface{}, key string) float64 {
	if v, ok := m[key].(float64); ok {
		return v
	}
	return 0.0
}

func getBool(m map[string]interface{}, key string) bool {
	if v, ok := m[key].(bool); ok {
		return v
	}
	return false
}

func getMap(m map[string]interface{}, key string) map[string]interface{} {
	if v, ok := m[key].(map[string]interface{}); ok {
		return v
	}
	return make(map[string]interface{})
}

func extractLeagueIDFromEndpoint(endpoint string) string {
	// Extract league_id from endpoints like /league/123456789/rosters
	parts := []string{}
	for _, part := range []byte(endpoint) {
		parts = append(parts, string(part))
	}
	
	// Simple extraction - look for pattern /league/{id}/
	if len(endpoint) > 8 && endpoint[:8] == "/league/" {
		remaining := endpoint[8:]
		for i, char := range remaining {
			if char == '/' {
				return remaining[:i]
			}
		}
	}
	return ""
}