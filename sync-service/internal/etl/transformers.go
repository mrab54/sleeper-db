package etl

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/mrab54/sleeper-db/sync-service/internal/database/repositories"
	"go.uber.org/zap"
)

// processMatchups transforms and inserts matchup data
func (p *Processor) processMatchups(ctx context.Context, resp *repositories.APIResponse) error {
	var matchups []map[string]interface{}
	if err := json.Unmarshal(resp.ResponseBody, &matchups); err != nil {
		return fmt.Errorf("failed to unmarshal matchups data: %w", err)
	}

	// Extract league_id and week from endpoint (format: /league/{league_id}/matchups/{week})
	parts := strings.Split(resp.Endpoint, "/")
	if len(parts) < 5 {
		return fmt.Errorf("invalid matchups endpoint format: %s", resp.Endpoint)
	}
	leagueID := parts[2]
	week, err := strconv.Atoi(parts[4])
	if err != nil {
		return fmt.Errorf("invalid week in endpoint: %s", resp.Endpoint)
	}

	tx, err := p.dbAnalytics.BeginTx(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Group matchups by matchup_id to find home/away teams
	matchupGroups := make(map[int][]map[string]interface{})
	for _, m := range matchups {
		matchupID := getInt(m, "matchup_id")
		matchupGroups[matchupID] = append(matchupGroups[matchupID], m)
	}

	// Process each matchup pair
	for matchupID, teams := range matchupGroups {
		if len(teams) != 2 {
			p.logger.Warn("Unexpected number of teams in matchup",
				zap.Int("matchup_id", matchupID),
				zap.Int("team_count", len(teams)),
			)
			continue
		}

		// Determine home and away (first team is home by convention)
		home := teams[0]
		away := teams[1]

		// Get roster IDs
		homeRosterNum := getInt(home, "roster_id")
		awayRosterNum := getInt(away, "roster_id")

		// Look up actual roster IDs from roster numbers
		var homeRosterID, awayRosterID int
		rosterQuery := `
			SELECT roster_id FROM analytics.rosters 
			WHERE league_id = $1 AND roster_number = $2
		`
		err = tx.QueryRow(ctx, rosterQuery, leagueID, homeRosterNum).Scan(&homeRosterID)
		if err != nil {
			p.logger.Warn("Could not find home roster",
				zap.String("league_id", leagueID),
				zap.Int("roster_number", homeRosterNum),
			)
			continue
		}

		err = tx.QueryRow(ctx, rosterQuery, leagueID, awayRosterNum).Scan(&awayRosterID)
		if err != nil {
			p.logger.Warn("Could not find away roster",
				zap.String("league_id", leagueID),
				zap.Int("roster_number", awayRosterNum),
			)
			continue
		}

		// Determine winner
		homePoints := getFloat(home, "points")
		awayPoints := getFloat(away, "points")
		var winnerRosterID *int
		if homePoints > awayPoints {
			winnerRosterID = &homeRosterID
		} else if awayPoints > homePoints {
			winnerRosterID = &awayRosterID
		}
		// NULL for tie

		// Insert matchup
		matchupQuery := `
			INSERT INTO analytics.matchups (
				league_id, week, matchup_number, home_roster_id, away_roster_id,
				home_points, away_points, winner_roster_id
			) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
			ON CONFLICT (league_id, week, matchup_number) DO UPDATE SET
				home_points = EXCLUDED.home_points,
				away_points = EXCLUDED.away_points,
				winner_roster_id = EXCLUDED.winner_roster_id,
				updated_at = NOW()
			RETURNING matchup_id
		`

		var matchupDBID int
		err = tx.QueryRow(ctx, matchupQuery,
			leagueID, week, matchupID, homeRosterID, awayRosterID,
			homePoints, awayPoints, winnerRosterID,
		).Scan(&matchupDBID)
		if err != nil {
			return fmt.Errorf("failed to insert matchup: %w", err)
		}

		// Process player stats for both teams
		err = p.processMatchupPlayers(ctx, tx, matchupDBID, homeRosterID, home)
		if err != nil {
			return fmt.Errorf("failed to process home team players: %w", err)
		}

		err = p.processMatchupPlayers(ctx, tx, matchupDBID, awayRosterID, away)
		if err != nil {
			return fmt.Errorf("failed to process away team players: %w", err)
		}
	}

	return tx.Commit(ctx)
}

// processMatchupPlayers inserts player performance for a matchup
func (p *Processor) processMatchupPlayers(ctx context.Context, tx pgx.Tx, matchupID int, rosterID int, matchup map[string]interface{}) error {
	// Delete existing players for this matchup/roster
	deleteQuery := `
		DELETE FROM analytics.matchup_players 
		WHERE matchup_id = $1 AND roster_id = $2
	`
	_, err := tx.Exec(ctx, deleteQuery, matchupID, rosterID)
	if err != nil {
		return err
	}

	// Get starters and players_points
	starters := []string{}
	if s, ok := matchup["starters"].([]interface{}); ok {
		for _, starter := range s {
			if playerID, ok := starter.(string); ok && playerID != "" {
				starters = append(starters, playerID)
			}
		}
	}

	playersPoints := make(map[string]float64)
	if pp, ok := matchup["players_points"].(map[string]interface{}); ok {
		for playerID, points := range pp {
			if pts, ok := points.(float64); ok {
				playersPoints[playerID] = pts
			}
		}
	}

	// Insert player performances
	insertQuery := `
		INSERT INTO analytics.matchup_players (
			matchup_id, roster_id, player_id, is_starter, actual_points
		) VALUES ($1, $2, $3, $4, $5)
	`

	// Process all players with points
	for playerID, points := range playersPoints {
		isStarter := false
		for _, starterID := range starters {
			if starterID == playerID {
				isStarter = true
				break
			}
		}

		_, err := tx.Exec(ctx, insertQuery, matchupID, rosterID, playerID, isStarter, points)
		if err != nil {
			return fmt.Errorf("failed to insert matchup player %s: %w", playerID, err)
		}
	}

	return nil
}

// processTransactions transforms and inserts transaction data
func (p *Processor) processTransactions(ctx context.Context, resp *repositories.APIResponse) error {
	var transactions []map[string]interface{}
	if err := json.Unmarshal(resp.ResponseBody, &transactions); err != nil {
		return fmt.Errorf("failed to unmarshal transactions data: %w", err)
	}

	// Extract league_id and week from endpoint
	parts := strings.Split(resp.Endpoint, "/")
	if len(parts) < 5 {
		return fmt.Errorf("invalid transactions endpoint format: %s", resp.Endpoint)
	}
	leagueID := parts[2]
	week, err := strconv.Atoi(parts[4])
	if err != nil {
		return fmt.Errorf("invalid week in endpoint: %s", resp.Endpoint)
	}

	tx, err := p.dbAnalytics.BeginTx(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	for _, trans := range transactions {
		transactionID := getString(trans, "transaction_id")
		transType := getString(trans, "type")
		status := getString(trans, "status")
		
		// Get creator roster
		var initiatorRosterID *int
		if creatorID := getString(trans, "creator"); creatorID != "" {
			// Look up roster for this user
			var rid int
			rosterQuery := `
				SELECT r.roster_id 
				FROM analytics.rosters r
				JOIN analytics.roster_ownership ro ON r.roster_id = ro.roster_id
				WHERE r.league_id = $1 AND ro.user_id = $2 AND ro.is_primary = true
				AND ro.valid_to = '9999-12-31'::timestamptz
				LIMIT 1
			`
			err = tx.QueryRow(ctx, rosterQuery, leagueID, creatorID).Scan(&rid)
			if err == nil {
				initiatorRosterID = &rid
			}
		}

		// Insert transaction
		transQuery := `
			INSERT INTO analytics.transactions (
				transaction_id, league_id, type, status, week,
				initiator_roster_id, created_timestamp, leg
			) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
			ON CONFLICT (transaction_id) DO UPDATE SET
				status = EXCLUDED.status,
				updated_at = NOW()
		`

		createdTimestamp := time.Unix(int64(getFloat(trans, "created")/1000), 0)
		leg := getInt(trans, "leg")

		_, err = tx.Exec(ctx, transQuery,
			transactionID, leagueID, transType, status, week,
			initiatorRosterID, createdTimestamp, leg,
		)
		if err != nil {
			return fmt.Errorf("failed to insert transaction: %w", err)
		}

		// Process adds and drops
		err = p.processTransactionDetails(ctx, tx, transactionID, leagueID, trans)
		if err != nil {
			return fmt.Errorf("failed to process transaction details: %w", err)
		}

		// Process FAAB (waiver budget)
		if settings, ok := trans["settings"].(map[string]interface{}); ok {
			if waiver, ok := settings["waiver_budget"].([]interface{}); ok {
				err = p.processTransactionFAAB(ctx, tx, transactionID, waiver)
				if err != nil {
					return fmt.Errorf("failed to process FAAB: %w", err)
				}
			}
		}

		// Process consenter rosters for trades
		if transType == "trade" {
			err = p.processTransactionConsenters(ctx, tx, transactionID, leagueID, trans)
			if err != nil {
				return fmt.Errorf("failed to process trade consenters: %w", err)
			}
		}
	}

	return tx.Commit(ctx)
}

// processTransactionDetails processes adds and drops for a transaction
func (p *Processor) processTransactionDetails(ctx context.Context, tx pgx.Tx, transactionID string, leagueID string, trans map[string]interface{}) error {
	// Process adds
	if adds, ok := trans["adds"].(map[string]interface{}); ok {
		for playerID, rosterNum := range adds {
			rosterNumber := int(rosterNum.(float64))
			
			// Get roster_id from roster_number
			var rosterID int
			rosterQuery := `
				SELECT roster_id FROM analytics.rosters 
				WHERE league_id = $1 AND roster_number = $2
			`
			err := tx.QueryRow(ctx, rosterQuery, leagueID, rosterNumber).Scan(&rosterID)
			if err != nil {
				continue
			}

			addQuery := `
				INSERT INTO analytics.transaction_adds (
					transaction_id, roster_id, player_id
				) VALUES ($1, $2, $3)
				ON CONFLICT DO NOTHING
			`
			_, err = tx.Exec(ctx, addQuery, transactionID, rosterID, playerID)
			if err != nil {
				return err
			}
		}
	}

	// Process drops
	if drops, ok := trans["drops"].(map[string]interface{}); ok {
		for playerID, rosterNum := range drops {
			rosterNumber := int(rosterNum.(float64))
			
			// Get roster_id from roster_number
			var rosterID int
			rosterQuery := `
				SELECT roster_id FROM analytics.rosters 
				WHERE league_id = $1 AND roster_number = $2
			`
			err := tx.QueryRow(ctx, rosterQuery, leagueID, rosterNumber).Scan(&rosterID)
			if err != nil {
				continue
			}

			dropQuery := `
				INSERT INTO analytics.transaction_drops (
					transaction_id, roster_id, player_id
				) VALUES ($1, $2, $3)
				ON CONFLICT DO NOTHING
			`
			_, err = tx.Exec(ctx, dropQuery, transactionID, rosterID, playerID)
			if err != nil {
				return err
			}
		}
	}

	return nil
}

// processTransactionFAAB processes waiver budget for transactions
func (p *Processor) processTransactionFAAB(ctx context.Context, tx pgx.Tx, transactionID string, waiverBudget []interface{}) error {
	for _, wb := range waiverBudget {
		if budget, ok := wb.(map[string]interface{}); ok {
			sender := getInt(budget, "sender")
			receiver := getInt(budget, "receiver")
			amount := getInt(budget, "amount")

			// Note: sender/receiver are roster numbers, need to be converted to roster_ids
			// For now, storing as-is since we don't have league context here
			faabQuery := `
				INSERT INTO analytics.transaction_faab (
					transaction_id, from_roster_id, to_roster_id, amount
				) VALUES ($1, $2, $3, $4)
				ON CONFLICT DO NOTHING
			`
			_, err := tx.Exec(ctx, faabQuery, transactionID, sender, receiver, amount)
			if err != nil {
				return err
			}
		}
	}
	return nil
}

// processTransactionConsenters processes trade participants
func (p *Processor) processTransactionConsenters(ctx context.Context, tx pgx.Tx, transactionID string, leagueID string, trans map[string]interface{}) error {
	if consenterIDs, ok := trans["consenter_ids"].([]interface{}); ok {
		for _, id := range consenterIDs {
			if rosterNum, ok := id.(float64); ok {
				// Get roster_id from roster_number
				var rosterID int
				rosterQuery := `
					SELECT roster_id FROM analytics.rosters 
					WHERE league_id = $1 AND roster_number = $2
				`
				err := tx.QueryRow(ctx, rosterQuery, leagueID, int(rosterNum)).Scan(&rosterID)
				if err != nil {
					continue
				}

				consenterQuery := `
					INSERT INTO analytics.transaction_rosters (
						transaction_id, roster_id, role
					) VALUES ($1, $2, 'consenter')
					ON CONFLICT DO NOTHING
				`
				_, err = tx.Exec(ctx, consenterQuery, transactionID, rosterID)
				if err != nil {
					return err
				}
			}
		}
	}
	return nil
}

// processPlayers transforms and inserts NFL player data
func (p *Processor) processPlayers(ctx context.Context, resp *repositories.APIResponse) error {
	var players map[string]interface{}
	if err := json.Unmarshal(resp.ResponseBody, &players); err != nil {
		return fmt.Errorf("failed to unmarshal players data: %w", err)
	}

	tx, err := p.dbAnalytics.BeginTx(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	for playerID, playerData := range players {
		player, ok := playerData.(map[string]interface{})
		if !ok {
			continue
		}

		// Insert player
		playerQuery := `
			INSERT INTO analytics.players (
				player_id, first_name, last_name, full_name,
				team, number, active, years_exp, age,
				height, weight, college, birth_date, birth_city,
				birth_state, birth_country, high_school
			) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
			ON CONFLICT (player_id) DO UPDATE SET
				first_name = EXCLUDED.first_name,
				last_name = EXCLUDED.last_name,
				full_name = EXCLUDED.full_name,
				team = EXCLUDED.team,
				number = EXCLUDED.number,
				active = EXCLUDED.active,
				years_exp = EXCLUDED.years_exp,
				age = EXCLUDED.age,
				height = EXCLUDED.height,
				weight = EXCLUDED.weight,
				college = EXCLUDED.college,
				birth_date = EXCLUDED.birth_date,
				birth_city = EXCLUDED.birth_city,
				birth_state = EXCLUDED.birth_state,
				birth_country = EXCLUDED.birth_country,
				high_school = EXCLUDED.high_school,
				updated_at = NOW()
		`

		firstName := getString(player, "first_name")
		lastName := getString(player, "last_name")
		fullName := getString(player, "full_name")
		if fullName == "" && (firstName != "" || lastName != "") {
			fullName = fmt.Sprintf("%s %s", firstName, lastName)
		}

		_, err = tx.Exec(ctx, playerQuery,
			playerID,
			firstName,
			lastName,
			fullName,
			getString(player, "team"),
			getInt(player, "number"),
			getBool(player, "active"),
			getInt(player, "years_exp"),
			getInt(player, "age"),
			getString(player, "height"),
			getInt(player, "weight"),
			getString(player, "college"),
			getString(player, "birth_date"),
			getString(player, "birth_city"),
			getString(player, "birth_state"),
			getString(player, "birth_country"),
			getString(player, "high_school"),
		)
		if err != nil {
			p.logger.Warn("Failed to insert player",
				zap.String("player_id", playerID),
				zap.Error(err),
			)
			continue
		}

		// Process player fantasy positions
		if positions, ok := player["fantasy_positions"].([]interface{}); ok {
			err = p.processPlayerPositions(ctx, tx, playerID, positions, time.Now())
			if err != nil {
				p.logger.Warn("Failed to process player positions",
					zap.String("player_id", playerID),
					zap.Error(err),
				)
			}
		}

		// Process player status
		err = p.processPlayerStatus(ctx, tx, playerID, player, time.Now())
		if err != nil {
			p.logger.Warn("Failed to process player status",
				zap.String("player_id", playerID),
				zap.Error(err),
			)
		}
	}

	return tx.Commit(ctx)
}

// processPlayerPositions inserts player fantasy positions
func (p *Processor) processPlayerPositions(ctx context.Context, tx pgx.Tx, playerID string, positions []interface{}, validFrom time.Time) error {
	// Mark old positions as no longer valid
	updateQuery := `
		UPDATE analytics.player_fantasy_positions 
		SET valid_to = $2
		WHERE player_id = $1 AND valid_to = '9999-12-31'::timestamptz
	`
	_, err := tx.Exec(ctx, updateQuery, playerID, validFrom)
	if err != nil {
		return err
	}

	// Insert new positions
	insertQuery := `
		INSERT INTO analytics.player_fantasy_positions (
			player_id, position, position_order, valid_from
		) VALUES ($1, $2, $3, $4)
	`

	for i, pos := range positions {
		if position, ok := pos.(string); ok {
			_, err := tx.Exec(ctx, insertQuery, playerID, position, i+1, validFrom)
			if err != nil {
				return err
			}
		}
	}

	return nil
}

// processPlayerStatus inserts player status
func (p *Processor) processPlayerStatus(ctx context.Context, tx pgx.Tx, playerID string, player map[string]interface{}, validFrom time.Time) error {
	status := getString(player, "status")
	injuryStatus := getString(player, "injury_status")
	injuryBodyPart := getString(player, "injury_body_part")
	injuryNotes := getString(player, "injury_notes")
	practiceParticipation := getString(player, "practice_participation")

	// Only insert if there's actual status information
	if status == "" && injuryStatus == "" {
		return nil
	}

	// Mark old status as no longer valid
	updateQuery := `
		UPDATE analytics.player_status 
		SET valid_to = $2
		WHERE player_id = $1 AND valid_to = '9999-12-31'::timestamptz
	`
	_, err := tx.Exec(ctx, updateQuery, playerID, validFrom)
	if err != nil {
		return err
	}

	// Insert new status
	insertQuery := `
		INSERT INTO analytics.player_status (
			player_id, status, injury_status, injury_body_part,
			injury_notes, practice_participation, valid_from
		) VALUES ($1, $2, $3, $4, $5, $6, $7)
	`

	_, err = tx.Exec(ctx, insertQuery,
		playerID, status, injuryStatus, injuryBodyPart,
		injuryNotes, practiceParticipation, validFrom,
	)

	return err
}

// processNFLState processes NFL state information
func (p *Processor) processNFLState(ctx context.Context, resp *repositories.APIResponse) error {
	var state map[string]interface{}
	if err := json.Unmarshal(resp.ResponseBody, &state); err != nil {
		return fmt.Errorf("failed to unmarshal NFL state: %w", err)
	}

	// For now, just log the state - could store in a state table if needed
	p.logger.Info("Processing NFL state",
		zap.String("season", getString(state, "season")),
		zap.String("season_type", getString(state, "season_type")),
		zap.Int("week", getInt(state, "week")),
		zap.Int("leg", getInt(state, "leg")),
		zap.String("league_season", getString(state, "league_season")),
	)

	// Could store this in a seasons table for reference
	season := getString(state, "season")
	if season != "" {
		tx, err := p.dbAnalytics.BeginTx(ctx)
		if err != nil {
			return err
		}
		defer tx.Rollback(ctx)

		seasonQuery := `
			INSERT INTO analytics.seasons (
				season, season_type, current_week, is_current
			) VALUES ($1, $2, $3, true)
			ON CONFLICT (season) DO UPDATE SET
				season_type = EXCLUDED.season_type,
				current_week = EXCLUDED.current_week,
				is_current = true,
				updated_at = NOW()
		`

		// Mark all other seasons as not current
		_, err = tx.Exec(ctx, "UPDATE analytics.seasons SET is_current = false WHERE season != $1", season)
		if err != nil {
			return err
		}

		_, err = tx.Exec(ctx, seasonQuery,
			season,
			getString(state, "season_type"),
			getInt(state, "week"),
		)
		if err != nil {
			return err
		}

		return tx.Commit(ctx)
	}

	return nil
}