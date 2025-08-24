package sync

import (
	"context"
	"fmt"

	"go.uber.org/zap"
)

// SyncMatchups syncs matchups for a specific week
func (s *Syncer) SyncMatchups(ctx context.Context, leagueID string, week int) error {
	s.logger.Info("Syncing matchups",
		zap.String("league_id", leagueID),
		zap.Int("week", week),
	)

	// Fetch matchups from API
	matchups, err := s.client.GetMatchups(ctx, leagueID, week)
	if err != nil {
		return fmt.Errorf("failed to fetch matchups: %w", err)
	}

	// Upsert each matchup
	for _, matchup := range matchups {
		if err := s.matchupRepo.UpsertMatchup(ctx, leagueID, week, &matchup); err != nil {
			s.logger.Error("Failed to upsert matchup",
				zap.String("league_id", leagueID),
				zap.Int("week", week),
				zap.Int("roster_id", matchup.RosterID),
				zap.Error(err),
			)
			// Continue with other matchups
			continue
		}
	}

	s.logger.Info("Matchups synced successfully",
		zap.String("league_id", leagueID),
		zap.Int("week", week),
		zap.Int("count", len(matchups)),
	)

	return nil
}