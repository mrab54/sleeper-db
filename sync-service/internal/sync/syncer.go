package sync

import (
	"context"
	"fmt"
	"time"

	"github.com/mrab54/sleeper-db/sync-service/internal/api"
	"github.com/mrab54/sleeper-db/sync-service/internal/database"
	"github.com/mrab54/sleeper-db/sync-service/internal/database/repositories"
	"go.uber.org/zap"
)

// Syncer is the main synchronization orchestrator
type Syncer struct {
	client      *api.SleeperClient
	db          *database.DB
	logger      *zap.Logger
	leagueRepo  *repositories.LeagueRepository
	userRepo    *repositories.UserRepository
	rosterRepo  *repositories.RosterRepository
	playerRepo  *repositories.PlayerRepository
	matchupRepo *repositories.MatchupRepository
	txRepo      *repositories.TransactionRepository
}

// NewSyncer creates a new syncer instance
func NewSyncer(client *api.SleeperClient, db *database.DB, logger *zap.Logger) *Syncer {
	return &Syncer{
		client:      client,
		db:          db,
		logger:      logger,
		leagueRepo:  repositories.NewLeagueRepository(db, logger),
		userRepo:    repositories.NewUserRepository(db, logger),
		rosterRepo:  repositories.NewRosterRepository(db, logger),
		playerRepo:  repositories.NewPlayerRepository(db, logger),
		matchupRepo: repositories.NewMatchupRepository(db, logger),
		txRepo:      repositories.NewTransactionRepository(db, logger),
	}
}

// SyncResult represents the result of a sync operation
type SyncResult struct {
	Success         bool
	RecordsProcessed int
	Errors          []error
	Duration        time.Duration
}

// FullSync performs a complete synchronization for a league
func (s *Syncer) FullSync(ctx context.Context, leagueID string) (*SyncResult, error) {
	start := time.Now()
	result := &SyncResult{
		Success: true,
		Errors:  []error{},
	}

	s.logger.Info("Starting full sync", zap.String("league_id", leagueID))

	// Log sync start
	syncID, err := s.logSyncStart(ctx, "full", "league", leagueID)
	if err != nil {
		s.logger.Error("Failed to log sync start", zap.Error(err))
	}

	// Sync league first
	if err := s.SyncLeague(ctx, leagueID); err != nil {
		result.Success = false
		result.Errors = append(result.Errors, fmt.Errorf("league sync failed: %w", err))
		s.logSyncError(ctx, syncID, err)
		return result, err
	}
	result.RecordsProcessed++

	// Sync users (required for rosters foreign key)
	if err := s.SyncUsers(ctx, leagueID); err != nil {
		result.Success = false
		result.Errors = append(result.Errors, fmt.Errorf("users sync failed: %w", err))
		s.logSyncError(ctx, syncID, err)
	}

	// Sync all players (required for roster_players foreign key)
	if err := s.SyncPlayers(ctx); err != nil {
		result.Errors = append(result.Errors, fmt.Errorf("players sync failed: %w", err))
		s.logSyncError(ctx, syncID, err)
		// Continue even if players sync fails
	}

	// Sync rosters (depends on users and players)
	if err := s.SyncRosters(ctx, leagueID); err != nil {
		result.Success = false
		result.Errors = append(result.Errors, fmt.Errorf("rosters sync failed: %w", err))
		s.logSyncError(ctx, syncID, err)
	}

	// Get NFL state to determine current week
	nflState, err := s.client.GetNFLState(ctx)
	if err != nil {
		result.Success = false
		result.Errors = append(result.Errors, fmt.Errorf("failed to get NFL state: %w", err))
		s.logSyncError(ctx, syncID, err)
	} else {
		// Sync matchups for all weeks up to current
		for week := 1; week <= nflState.Week; week++ {
			if err := s.SyncMatchups(ctx, leagueID, week); err != nil {
				result.Errors = append(result.Errors, fmt.Errorf("matchup sync failed for week %d: %w", week, err))
			}
		}

		// Sync transactions for all weeks
		for week := 1; week <= nflState.Week; week++ {
			if err := s.SyncTransactions(ctx, leagueID, week); err != nil {
				result.Errors = append(result.Errors, fmt.Errorf("transaction sync failed for week %d: %w", week, err))
			}
		}
	}

	// Players already synced above before rosters

	result.Duration = time.Since(start)

	// Log sync completion
	if err := s.logSyncComplete(ctx, syncID, result.RecordsProcessed); err != nil {
		s.logger.Error("Failed to log sync completion", zap.Error(err))
	}

	s.logger.Info("Full sync completed",
		zap.String("league_id", leagueID),
		zap.Bool("success", result.Success),
		zap.Int("records", result.RecordsProcessed),
		zap.Duration("duration", result.Duration),
		zap.Int("errors", len(result.Errors)),
	)

	return result, nil
}

// logSyncStart logs the start of a sync operation
func (s *Syncer) logSyncStart(ctx context.Context, syncType, entityType, entityID string) (int, error) {
	query := `
		INSERT INTO sleeper.sync_log (
			sync_type, entity_type, entity_id, status, started_at
		) VALUES ($1, $2, $3, 'running', CURRENT_TIMESTAMP)
		RETURNING id
	`

	var syncID int
	err := s.db.QueryRow(ctx, query, syncType, entityType, entityID).Scan(&syncID)
	return syncID, err
}

// logSyncComplete logs the completion of a sync operation
func (s *Syncer) logSyncComplete(ctx context.Context, syncID int, recordsProcessed int) error {
	query := `
		UPDATE sleeper.sync_log 
		SET status = 'completed',
		    completed_at = CURRENT_TIMESTAMP,
		    records_processed = $2
		WHERE id = $1
	`

	_, err := s.db.Exec(ctx, query, syncID, recordsProcessed)
	return err
}

// logSyncError logs an error during sync
func (s *Syncer) logSyncError(ctx context.Context, syncID int, err error) error {
	query := `
		UPDATE sleeper.sync_log 
		SET status = 'failed',
		    completed_at = CURRENT_TIMESTAMP,
		    error_message = $2
		WHERE id = $1
	`

	_, execErr := s.db.Exec(ctx, query, syncID, err.Error())
	return execErr
}