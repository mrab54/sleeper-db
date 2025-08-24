package sync

import (
	"context"
	"fmt"

	"go.uber.org/zap"
)

// SyncLeague syncs league information
func (s *Syncer) SyncLeague(ctx context.Context, leagueID string) error {
	s.logger.Info("Syncing league", zap.String("league_id", leagueID))

	// Fetch league from API
	league, err := s.client.GetLeague(ctx, leagueID)
	if err != nil {
		return fmt.Errorf("failed to fetch league: %w", err)
	}

	// Upsert league to database
	if err := s.leagueRepo.UpsertLeague(ctx, league); err != nil {
		return fmt.Errorf("failed to upsert league: %w", err)
	}

	s.logger.Info("League synced successfully",
		zap.String("league_id", leagueID),
		zap.String("name", league.Name),
		zap.String("season", league.Season),
	)

	return nil
}