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

	// Upsert each transaction
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