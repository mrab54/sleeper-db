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

	// First, sync any users referenced in rosters that might not be in the league
	userIDSet := make(map[string]bool)
	for _, roster := range rosters {
		if roster.OwnerID != "" {
			userIDSet[roster.OwnerID] = true
		}
		// Add any co-owner IDs
		if roster.CoOwners != nil {
			for _, coOwnerID := range roster.CoOwners {
				if coOwnerID != "" {
					userIDSet[coOwnerID] = true
				}
			}
		}
	}

	// Sync missing users
	for userID := range userIDSet {
		// Try to get user info (this might fail for some users)
		user, err := s.client.GetUser(ctx, userID)
		if err != nil {
			// Create a minimal user record
			s.logger.Warn("Could not fetch user details, creating minimal record",
				zap.String("user_id", userID),
				zap.Error(err),
			)
			// Continue anyway - we'll create a minimal user record
			minimalUser := struct {
				UserID      string  `json:"user_id"`
				Username    *string `json:"username"`
				DisplayName string  `json:"display_name"`
			}{
				UserID:      userID,
				DisplayName: "User " + userID[:8],
			}
			s.userRepo.UpsertMinimalUser(ctx, userID, minimalUser.DisplayName)
			continue
		}
		if user != nil {
			s.userRepo.UpsertUser(ctx, user)
		}
	}

	// Now upsert each roster
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