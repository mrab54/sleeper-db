package sync

import (
	"context"
	"fmt"

	"go.uber.org/zap"
)

// SyncUsers syncs all users in a league
func (s *Syncer) SyncUsers(ctx context.Context, leagueID string) error {
	s.logger.Info("Syncing users", zap.String("league_id", leagueID))

	// Fetch users from API
	users, err := s.client.GetUsers(ctx, leagueID)
	if err != nil {
		return fmt.Errorf("failed to fetch users: %w", err)
	}

	// Upsert each user
	for _, user := range users {
		if err := s.userRepo.UpsertUser(ctx, &user); err != nil {
			s.logger.Error("Failed to upsert user",
				zap.String("user_id", user.UserID),
				zap.String("username", user.Username),
				zap.Error(err),
			)
			// Continue with other users even if one fails
			continue
		}
	}

	s.logger.Info("Users synced successfully",
		zap.String("league_id", leagueID),
		zap.Int("count", len(users)),
	)

	return nil
}