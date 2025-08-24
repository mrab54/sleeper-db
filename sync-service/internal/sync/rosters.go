package sync

import (
	"context"
	"fmt"

	"go.uber.org/zap"
)

// SyncRosters syncs all rosters in a league
func (s *Syncer) SyncRosters(ctx context.Context, leagueID string) error {
	s.logger.Info("Syncing rosters", zap.String("league_id", leagueID))

	// Fetch rosters from API
	rosters, err := s.client.GetRosters(ctx, leagueID)
	if err != nil {
		return fmt.Errorf("failed to fetch rosters: %w", err)
	}

	// Upsert each roster
	for _, roster := range rosters {
		if err := s.rosterRepo.UpsertRoster(ctx, leagueID, &roster); err != nil {
			s.logger.Error("Failed to upsert roster",
				zap.String("league_id", leagueID),
				zap.Int("roster_id", roster.RosterID),
				zap.Error(err),
			)
			// Continue with other rosters even if one fails
			continue
		}
	}

	s.logger.Info("Rosters synced successfully",
		zap.String("league_id", leagueID),
		zap.Int("count", len(rosters)),
	)

	return nil
}