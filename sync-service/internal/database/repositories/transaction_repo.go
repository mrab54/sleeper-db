package repositories

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mrab54/sleeper-db/sync-service/internal/api"
	"github.com/mrab54/sleeper-db/sync-service/internal/database"
	"go.uber.org/zap"
)

// TransactionRepository handles transaction-related database operations
type TransactionRepository struct {
	db     *database.DB
	logger *zap.Logger
}

// NewTransactionRepository creates a new transaction repository
func NewTransactionRepository(db *database.DB, logger *zap.Logger) *TransactionRepository {
	return &TransactionRepository{
		db:     db,
		logger: logger,
	}
}

// UpsertTransaction inserts or updates a transaction
func (r *TransactionRepository) UpsertTransaction(ctx context.Context, leagueID string, tx *api.Transaction) error {
	// Convert arrays and maps to JSONB
	rosterIDs, _ := json.Marshal(tx.RosterIDs)
	adds, _ := json.Marshal(tx.Adds)
	drops, _ := json.Marshal(tx.Drops)
	draftPicks, _ := json.Marshal(tx.DraftPicks)
	waiverBudget, _ := json.Marshal(tx.WaiverBudget)

	query := `
		INSERT INTO sleeper.transactions (
			transaction_id, league_id, type, transaction_type, status,
			status_updated, roster_ids, settings, adds, drops,
			draft_picks, waiver_budget, metadata, creator, created, leg
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16
		)
		ON CONFLICT (transaction_id) DO UPDATE SET
			status = EXCLUDED.status,
			status_updated = EXCLUDED.status_updated,
			settings = EXCLUDED.settings,
			metadata = EXCLUDED.metadata,
			updated_at = CURRENT_TIMESTAMP
	`

	_, err := r.db.Exec(ctx, query,
		tx.TransactionID,
		leagueID,
		tx.Type,
		tx.TransactionType,
		tx.Status,
		tx.StatusUpdated,
		rosterIDs,
		tx.Settings,
		adds,
		drops,
		draftPicks,
		waiverBudget,
		tx.Metadata,
		tx.Creator,
		tx.Created,
		tx.Leg,
	)

	if err != nil {
		r.logger.Error("Failed to upsert transaction",
			zap.String("transaction_id", tx.TransactionID),
			zap.String("type", tx.Type),
			zap.Error(err),
		)
		return fmt.Errorf("failed to upsert transaction: %w", err)
	}

	return nil
}

// GetTransactionsByWeek retrieves all transactions for a specific week
func (r *TransactionRepository) GetTransactionsByWeek(ctx context.Context, leagueID string, week int) ([]*api.Transaction, error) {
	// Transactions don't have a week field directly, but we can filter by creation time
	// This is a simplified version - you might need to adjust based on your needs
	query := `
		SELECT transaction_id, type, transaction_type, status, status_updated,
		       roster_ids, settings, adds, drops, draft_picks, waiver_budget,
		       metadata, creator, created, leg
		FROM sleeper.transactions
		WHERE league_id = $1 AND leg = $2
		ORDER BY created DESC
	`

	rows, err := r.db.Query(ctx, query, leagueID, week)
	if err != nil {
		return nil, fmt.Errorf("failed to query transactions: %w", err)
	}
	defer rows.Close()

	var transactions []*api.Transaction
	for rows.Next() {
		var tx api.Transaction
		var rosterIDs, adds, drops, draftPicks, waiverBudget json.RawMessage

		err := rows.Scan(
			&tx.TransactionID,
			&tx.Type,
			&tx.TransactionType,
			&tx.Status,
			&tx.StatusUpdated,
			&rosterIDs,
			&tx.Settings,
			&adds,
			&drops,
			&draftPicks,
			&waiverBudget,
			&tx.Metadata,
			&tx.Creator,
			&tx.Created,
			&tx.Leg,
		)

		if err != nil {
			return nil, fmt.Errorf("failed to scan transaction: %w", err)
		}

		// Unmarshal JSON fields
		json.Unmarshal(rosterIDs, &tx.RosterIDs)
		json.Unmarshal(adds, &tx.Adds)
		json.Unmarshal(drops, &tx.Drops)
		json.Unmarshal(draftPicks, &tx.DraftPicks)
		json.Unmarshal(waiverBudget, &tx.WaiverBudget)

		transactions = append(transactions, &tx)
	}

	return transactions, nil
}