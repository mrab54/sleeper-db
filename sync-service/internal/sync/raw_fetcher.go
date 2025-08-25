package sync

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/mrab54/sleeper-db/sync-service/internal/api"
	"github.com/mrab54/sleeper-db/sync-service/internal/database/repositories"
	"go.uber.org/zap"
)

// RawDataFetcher fetches raw data from Sleeper API and stores it
type RawDataFetcher struct {
	client  *api.SleeperClient
	rawRepo *repositories.RawRepository
	logger  *zap.Logger
}

// NewRawDataFetcher creates a new raw data fetcher
func NewRawDataFetcher(client *api.SleeperClient, rawRepo *repositories.RawRepository, logger *zap.Logger) *RawDataFetcher {
	return &RawDataFetcher{
		client:  client,
		rawRepo: rawRepo,
		logger:  logger,
	}
}

// FetchResult represents the result of a fetch operation
type FetchResult struct {
	Endpoint       string
	Success        bool
	ResponseTimeMs int
	ResponseSize   int
	Error          error
}

// FetchAllLeagueData fetches all data for a specific league
func (f *RawDataFetcher) FetchAllLeagueData(ctx context.Context, leagueID string) error {
	f.logger.Info("Starting raw data fetch for league", zap.String("league_id", leagueID))
	
	// Create a sync run
	metadata, _ := json.Marshal(map[string]string{"league_id": leagueID})
	syncRun, err := f.rawRepo.CreateSyncRun(ctx, "league_full", metadata)
	if err != nil {
		return fmt.Errorf("failed to create sync run: %w", err)
	}
	
	var successCount, errorCount, skippedCount int
	var errorDetails []map[string]interface{}
	
	// Helper function to record endpoint result
	recordResult := func(endpoint string, result *FetchResult) {
		status := "success"
		var errorMsg string
		var apiResponseID *int64
		
		if !result.Success {
			status = "error"
			errorMsg = result.Error.Error()
			errorCount++
			errorDetails = append(errorDetails, map[string]interface{}{
				"endpoint": endpoint,
				"error":    errorMsg,
			})
		} else {
			successCount++
		}
		
		err := f.rawRepo.RecordEndpointSync(ctx, syncRun.ID, endpoint, status, 200, result.ResponseTimeMs, result.ResponseSize, errorMsg, apiResponseID)
		if err != nil {
			f.logger.Error("Failed to record endpoint sync", zap.Error(err))
		}
	}
	
	// 1. Fetch League Details
	f.logger.Info("Fetching league details", zap.String("league_id", leagueID))
	if result := f.fetchAndStoreLeague(ctx, leagueID); result != nil {
		recordResult(fmt.Sprintf("/league/%s", leagueID), result)
	}
	
	// 2. Fetch League Users
	f.logger.Info("Fetching league users", zap.String("league_id", leagueID))
	if result := f.fetchAndStoreUsers(ctx, leagueID); result != nil {
		recordResult(fmt.Sprintf("/league/%s/users", leagueID), result)
	}
	
	// 3. Fetch Rosters
	f.logger.Info("Fetching rosters", zap.String("league_id", leagueID))
	if result := f.fetchAndStoreRosters(ctx, leagueID); result != nil {
		recordResult(fmt.Sprintf("/league/%s/rosters", leagueID), result)
	}
	
	// 4. Fetch Matchups for all weeks
	f.logger.Info("Fetching matchups", zap.String("league_id", leagueID))
	for week := 1; week <= 18; week++ { // Regular season + playoffs
		if result := f.fetchAndStoreMatchups(ctx, leagueID, week); result != nil {
			if result.Error != nil && result.Error.Error() == "no matchups found" {
				// This is expected for future weeks
				skippedCount++
				continue
			}
			recordResult(fmt.Sprintf("/league/%s/matchups/%d", leagueID, week), result)
		}
	}
	
	// 5. Fetch Transactions for all weeks
	f.logger.Info("Fetching transactions", zap.String("league_id", leagueID))
	for week := 1; week <= 18; week++ {
		if result := f.fetchAndStoreTransactions(ctx, leagueID, week); result != nil {
			if result.Error != nil && result.Error.Error() == "no transactions found" {
				skippedCount++
				continue
			}
			recordResult(fmt.Sprintf("/league/%s/transactions/%d", leagueID, week), result)
		}
	}
	
	// 6. Fetch Draft (if exists)
	// TODO: Implement draft fetching
	
	// 7. Fetch Traded Picks
	// TODO: Implement traded picks fetching
	
	// Update sync run with final status
	status := "completed"
	if errorCount > 0 {
		status = "completed_with_errors"
	}
	
	errorDetailsJSON, _ := json.Marshal(errorDetails)
	err = f.rawRepo.UpdateSyncRun(ctx, syncRun.ID, status, successCount, errorCount, skippedCount, errorDetailsJSON)
	if err != nil {
		f.logger.Error("Failed to update sync run", zap.Error(err))
	}
	
	f.logger.Info("Completed raw data fetch",
		zap.String("league_id", leagueID),
		zap.Int("success", successCount),
		zap.Int("errors", errorCount),
		zap.Int("skipped", skippedCount),
	)
	
	return nil
}

// fetchAndStoreLeague fetches and stores league data
func (f *RawDataFetcher) fetchAndStoreLeague(ctx context.Context, leagueID string) *FetchResult {
	startTime := time.Now()
	
	// Fetch from API
	league, err := f.client.GetLeague(ctx, leagueID)
	if err != nil {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s", leagueID),
			Success:  false,
			Error:    err,
		}
	}
	
	// Convert to JSON
	data, err := json.Marshal(league)
	if err != nil {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s", leagueID),
			Success:  false,
			Error:    err,
		}
	}
	
	// Store in raw database
	responseTime := int(time.Since(startTime).Milliseconds())
	_, err = f.rawRepo.StoreAPIResponse(ctx, fmt.Sprintf("/league/%s", leagueID), "league", data, 200, responseTime)
	if err != nil {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s", leagueID),
			Success:  false,
			Error:    err,
		}
	}
	
	// Also store in league-specific table
	err = f.rawRepo.StoreLeagueResponse(ctx, leagueID, data, time.Now())
	if err != nil {
		f.logger.Warn("Failed to store in league table", zap.Error(err))
	}
	
	return &FetchResult{
		Endpoint:       fmt.Sprintf("/league/%s", leagueID),
		Success:        true,
		ResponseTimeMs: responseTime,
		ResponseSize:   len(data),
	}
}

// fetchAndStoreUsers fetches and stores league users
func (f *RawDataFetcher) fetchAndStoreUsers(ctx context.Context, leagueID string) *FetchResult {
	startTime := time.Now()
	
	// Fetch from API
	users, err := f.client.GetLeagueUsers(ctx, leagueID)
	if err != nil {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s/users", leagueID),
			Success:  false,
			Error:    err,
		}
	}
	
	// Convert to JSON
	data, err := json.Marshal(users)
	if err != nil {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s/users", leagueID),
			Success:  false,
			Error:    err,
		}
	}
	
	// Store in raw database
	responseTime := int(time.Since(startTime).Milliseconds())
	_, err = f.rawRepo.StoreAPIResponse(ctx, fmt.Sprintf("/league/%s/users", leagueID), "users", data, 200, responseTime)
	if err != nil {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s/users", leagueID),
			Success:  false,
			Error:    err,
		}
	}
	
	// Also store in users table
	err = f.rawRepo.StoreUsersResponse(ctx, leagueID, data, time.Now())
	if err != nil {
		f.logger.Warn("Failed to store in users table", zap.Error(err))
	}
	
	return &FetchResult{
		Endpoint:       fmt.Sprintf("/league/%s/users", leagueID),
		Success:        true,
		ResponseTimeMs: responseTime,
		ResponseSize:   len(data),
	}
}

// fetchAndStoreRosters fetches and stores rosters
func (f *RawDataFetcher) fetchAndStoreRosters(ctx context.Context, leagueID string) *FetchResult {
	startTime := time.Now()
	
	// Fetch from API
	rosters, err := f.client.GetRosters(ctx, leagueID)
	if err != nil {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s/rosters", leagueID),
			Success:  false,
			Error:    err,
		}
	}
	
	// Convert to JSON
	data, err := json.Marshal(rosters)
	if err != nil {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s/rosters", leagueID),
			Success:  false,
			Error:    err,
		}
	}
	
	// Store in raw database
	responseTime := int(time.Since(startTime).Milliseconds())
	_, err = f.rawRepo.StoreAPIResponse(ctx, fmt.Sprintf("/league/%s/rosters", leagueID), "rosters", data, 200, responseTime)
	if err != nil {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s/rosters", leagueID),
			Success:  false,
			Error:    err,
		}
	}
	
	// Also store in rosters table
	err = f.rawRepo.StoreRostersResponse(ctx, leagueID, data, time.Now())
	if err != nil {
		f.logger.Warn("Failed to store in rosters table", zap.Error(err))
	}
	
	return &FetchResult{
		Endpoint:       fmt.Sprintf("/league/%s/rosters", leagueID),
		Success:        true,
		ResponseTimeMs: responseTime,
		ResponseSize:   len(data),
	}
}

// fetchAndStoreMatchups fetches and stores matchups for a specific week
func (f *RawDataFetcher) fetchAndStoreMatchups(ctx context.Context, leagueID string, week int) *FetchResult {
	startTime := time.Now()
	
	// Fetch from API
	matchups, err := f.client.GetMatchups(ctx, leagueID, week)
	if err != nil {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s/matchups/%d", leagueID, week),
			Success:  false,
			Error:    err,
		}
	}
	
	if len(matchups) == 0 {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s/matchups/%d", leagueID, week),
			Success:  false,
			Error:    fmt.Errorf("no matchups found"),
		}
	}
	
	// Convert to JSON
	data, err := json.Marshal(matchups)
	if err != nil {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s/matchups/%d", leagueID, week),
			Success:  false,
			Error:    err,
		}
	}
	
	// Store in raw database
	responseTime := int(time.Since(startTime).Milliseconds())
	_, err = f.rawRepo.StoreAPIResponse(ctx, fmt.Sprintf("/league/%s/matchups/%d", leagueID, week), "matchups", data, 200, responseTime)
	if err != nil {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s/matchups/%d", leagueID, week),
			Success:  false,
			Error:    err,
		}
	}
	
	// Also store in matchups table
	err = f.rawRepo.StoreMatchupsResponse(ctx, leagueID, week, data, time.Now())
	if err != nil {
		f.logger.Warn("Failed to store in matchups table", zap.Error(err))
	}
	
	return &FetchResult{
		Endpoint:       fmt.Sprintf("/league/%s/matchups/%d", leagueID, week),
		Success:        true,
		ResponseTimeMs: responseTime,
		ResponseSize:   len(data),
	}
}

// fetchAndStoreTransactions fetches and stores transactions for a specific week
func (f *RawDataFetcher) fetchAndStoreTransactions(ctx context.Context, leagueID string, week int) *FetchResult {
	startTime := time.Now()
	
	// Fetch from API
	transactions, err := f.client.GetTransactions(ctx, leagueID, week)
	if err != nil {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s/transactions/%d", leagueID, week),
			Success:  false,
			Error:    err,
		}
	}
	
	if len(transactions) == 0 {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s/transactions/%d", leagueID, week),
			Success:  false,
			Error:    fmt.Errorf("no transactions found"),
		}
	}
	
	// Convert to JSON
	data, err := json.Marshal(transactions)
	if err != nil {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s/transactions/%d", leagueID, week),
			Success:  false,
			Error:    err,
		}
	}
	
	// Store in raw database
	responseTime := int(time.Since(startTime).Milliseconds())
	_, err = f.rawRepo.StoreAPIResponse(ctx, fmt.Sprintf("/league/%s/transactions/%d", leagueID, week), "transactions", data, 200, responseTime)
	if err != nil {
		return &FetchResult{
			Endpoint: fmt.Sprintf("/league/%s/transactions/%d", leagueID, week),
			Success:  false,
			Error:    err,
		}
	}
	
	// Also store in transactions table
	err = f.rawRepo.StoreTransactionsResponse(ctx, leagueID, week, data, time.Now())
	if err != nil {
		f.logger.Warn("Failed to store in transactions table", zap.Error(err))
	}
	
	return &FetchResult{
		Endpoint:       fmt.Sprintf("/league/%s/transactions/%d", leagueID, week),
		Success:        true,
		ResponseTimeMs: responseTime,
		ResponseSize:   len(data),
	}
}

// FetchNFLPlayers fetches and stores the full NFL players database
func (f *RawDataFetcher) FetchNFLPlayers(ctx context.Context) error {
	f.logger.Info("Fetching NFL players database")
	startTime := time.Now()
	
	// Create a sync run
	metadata, _ := json.Marshal(map[string]string{"type": "nfl_players"})
	syncRun, err := f.rawRepo.CreateSyncRun(ctx, "players", metadata)
	if err != nil {
		return fmt.Errorf("failed to create sync run: %w", err)
	}
	
	// Fetch from API
	players, err := f.client.GetPlayers(ctx)
	if err != nil {
		f.rawRepo.UpdateSyncRun(ctx, syncRun.ID, "failed", 0, 1, 0, json.RawMessage(`[{"error": "`+err.Error()+`"}]`))
		return fmt.Errorf("failed to fetch players: %w", err)
	}
	
	// Convert to JSON
	data, err := json.Marshal(players)
	if err != nil {
		f.rawRepo.UpdateSyncRun(ctx, syncRun.ID, "failed", 0, 1, 0, json.RawMessage(`[{"error": "`+err.Error()+`"}]`))
		return fmt.Errorf("failed to marshal players: %w", err)
	}
	
	// Store in raw database
	responseTime := int(time.Since(startTime).Milliseconds())
	_, err = f.rawRepo.StoreAPIResponse(ctx, "/players/nfl", "players", data, 200, responseTime)
	if err != nil {
		f.rawRepo.UpdateSyncRun(ctx, syncRun.ID, "failed", 0, 1, 0, json.RawMessage(`[{"error": "`+err.Error()+`"}]`))
		return fmt.Errorf("failed to store players response: %w", err)
	}
	
	// Also store in players table
	err = f.rawRepo.StorePlayersResponse(ctx, data, time.Now())
	if err != nil {
		f.logger.Warn("Failed to store in players table", zap.Error(err))
	}
	
	// Update sync run as successful
	f.rawRepo.UpdateSyncRun(ctx, syncRun.ID, "completed", 1, 0, 0, nil)
	
	f.logger.Info("Successfully fetched NFL players",
		zap.Int("response_time_ms", responseTime),
		zap.Int("size_bytes", len(data)),
	)
	
	return nil
}

// FetchNFLState fetches and stores the current NFL state
func (f *RawDataFetcher) FetchNFLState(ctx context.Context) error {
	f.logger.Info("Fetching NFL state")
	startTime := time.Now()
	
	// Fetch from API
	state, err := f.client.GetNFLState(ctx)
	if err != nil {
		return fmt.Errorf("failed to fetch NFL state: %w", err)
	}
	
	// Convert to JSON
	data, err := json.Marshal(state)
	if err != nil {
		return fmt.Errorf("failed to marshal NFL state: %w", err)
	}
	
	// Store in raw database
	responseTime := int(time.Since(startTime).Milliseconds())
	_, err = f.rawRepo.StoreAPIResponse(ctx, "/state/nfl", "nfl_state", data, 200, responseTime)
	if err != nil {
		return fmt.Errorf("failed to store NFL state response: %w", err)
	}
	
	f.logger.Info("Successfully fetched NFL state",
		zap.Int("response_time_ms", responseTime),
		zap.Int("size_bytes", len(data)),
	)
	
	return nil
}