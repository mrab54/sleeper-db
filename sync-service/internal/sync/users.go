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

	s.logger.Info("Fetched users from API", 
		zap.String("league_id", leagueID),
		zap.Int("count", len(users)),
	)

	// Upsert each user
	successCount := 0
	for i, user := range users {
		var username string
		if user.Username != nil {
			username = *user.Username
		} else {
			username = "<null>"
		}
		
		s.logger.Debug("Processing user",
			zap.Int("index", i),
			zap.String("user_id", user.UserID),
			zap.String("username", username),
			zap.String("display_name", user.DisplayName),
			zap.Bool("is_bot", user.IsBot),
		)
		
		if err := s.userRepo.UpsertUser(ctx, &user); err != nil {
			s.logger.Error("Failed to upsert user",
				zap.String("user_id", user.UserID),
				zap.String("username", username),
				zap.Error(err),
			)
			// Continue with other users even if one fails
			continue
		}
		
		s.logger.Debug("Successfully upserted user",
			zap.String("user_id", user.UserID),
			zap.String("username", username),
		)
		successCount++
	}

	s.logger.Info("Users synced successfully",
		zap.String("league_id", leagueID),
		zap.Int("total_fetched", len(users)),
		zap.Int("success_count", successCount),
		zap.Int("failed_count", len(users) - successCount),
	)

	return nil
}