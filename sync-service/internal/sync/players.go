package sync

import (
	"context"
	"fmt"

	"github.com/mrab54/sleeper-db/sync-service/internal/api"
	"go.uber.org/zap"
)

// SyncPlayers syncs all NFL players
func (s *Syncer) SyncPlayers(ctx context.Context) error {
	s.logger.Info("Syncing all NFL players")

	// Fetch players from API
	players, err := s.client.GetPlayers(ctx)
	if err != nil {
		return fmt.Errorf("failed to fetch players: %w", err)
	}

	// Bulk upsert players
	if err := s.playerRepo.BulkUpsertPlayers(ctx, players); err != nil {
		return fmt.Errorf("failed to bulk upsert players: %w", err)
	}

	s.logger.Info("Players synced successfully",
		zap.Int("count", len(players)),
	)

	return nil
}

// GetNFLState gets the current NFL state
func (s *Syncer) GetNFLState(ctx context.Context) (*api.NFLState, error) {
	return s.client.GetNFLState(ctx)
}