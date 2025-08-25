package sync

import (
	"context"
	"fmt"

	"go.uber.org/zap"
)

// SyncTransactions syncs transactions for a specific week
func (s *Syncer) SyncTransactions(ctx context.Context, leagueID string, week int) error {
	s.logger.Info("Syncing transactions",
		zap.String("league_id", leagueID),
		zap.Int("week", week),
	)

	// Fetch transactions from API
	transactions, err := s.client.GetTransactions(ctx, leagueID, week)
	if err != nil {
		return fmt.Errorf("failed to fetch transactions: %w", err)
	}

	// First, sync any users referenced in transactions that might not be in the league
	userIDSet := make(map[string]bool)
	for _, tx := range transactions {
		if tx.Creator != "" {
			userIDSet[tx.Creator] = true
		}
		// Note: Sleeper API doesn't provide consenter IDs in transaction response
		// Only the creator is available
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

	// Now upsert each transaction
	for _, tx := range transactions {
		if err := s.txRepo.UpsertTransaction(ctx, leagueID, &tx); err != nil {
			s.logger.Error("Failed to upsert transaction",
				zap.String("league_id", leagueID),
				zap.String("transaction_id", tx.TransactionID),
				zap.Error(err),
			)
			// Continue with other transactions
			continue
		}
	}

	s.logger.Info("Transactions synced successfully",
		zap.String("league_id", leagueID),
		zap.Int("week", week),
		zap.Int("count", len(transactions)),
	)

	return nil
}