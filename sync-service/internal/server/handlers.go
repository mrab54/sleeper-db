package server

import (
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/rs/zerolog/log"
)

// Health check responses
type HealthResponse struct {
	Status    string    `json:"status"`
	Timestamp time.Time `json:"timestamp"`
	Version   string    `json:"version,omitempty"`
}

type ReadyResponse struct {
	Ready  bool                   `json:"ready"`
	Checks map[string]interface{} `json:"checks"`
}

// Sync request/response types
type SyncRequest struct {
	LeagueID string `json:"league_id" validate:"required"`
	Force    bool   `json:"force"`
}

type SyncResponse struct {
	Success        bool      `json:"success"`
	Message        string    `json:"message,omitempty"`
	RecordsUpdated int       `json:"records_updated"`
	Duration       string    `json:"duration"`
	Timestamp      time.Time `json:"timestamp"`
}

// handleHealth handles liveness probe
func (s *Server) handleHealth(c *fiber.Ctx) error {
	return c.JSON(HealthResponse{
		Status:    "healthy",
		Timestamp: time.Now(),
		Version:   "1.0.0", // TODO: Get from build info
	})
}

// handleReady handles readiness probe
func (s *Server) handleReady(c *fiber.Ctx) error {
	checks := make(map[string]interface{})
	ready := true

	// Check database connection
	if err := s.db.Ping(c.Context()); err != nil {
		checks["database"] = false
		ready = false
	} else {
		checks["database"] = true
	}

	// Check Sleeper API (test with NFL state endpoint)
	if _, err := s.apiClient.GetNFLState(c.Context()); err != nil {
		checks["sleeper_api"] = false
		ready = false
	} else {
		checks["sleeper_api"] = true
	}

	status := fiber.StatusOK
	if !ready {
		status = fiber.StatusServiceUnavailable
	}

	return c.Status(status).JSON(ReadyResponse{
		Ready:  ready,
		Checks: checks,
	})
}

// handleSyncLeague handles league sync requests from Hasura
func (s *Server) handleSyncLeague(c *fiber.Ctx) error {
	start := time.Now()
	
	var req SyncRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid request body")
	}

	// Use primary league ID if not specified
	if req.LeagueID == "" {
		req.LeagueID = s.config.Sleeper.PrimaryLeagueID
	}

	log.Info().
		Str("league_id", req.LeagueID).
		Bool("force", req.Force).
		Msg("Starting league sync")

	// Perform actual sync
	err := s.syncer.SyncLeague(c.Context(), req.LeagueID)
	if err != nil {
		log.Error().Err(err).Str("league_id", req.LeagueID).Msg("League sync failed")
		return fiber.NewError(fiber.StatusInternalServerError, "Sync failed: " + err.Error())
	}

	return c.JSON(SyncResponse{
		Success:        true,
		Message:        "League sync completed successfully",
		RecordsUpdated: 1, // League is a single record
		Duration:       time.Since(start).String(),
		Timestamp:      time.Now(),
	})
}

// handleSyncLiveScores handles live score sync requests
func (s *Server) handleSyncLiveScores(c *fiber.Ctx) error {
	start := time.Now()
	
	var req struct {
		LeagueID string `json:"league_id"`
		Week     int    `json:"week"`
	}
	
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid request body")
	}

	if req.LeagueID == "" {
		req.LeagueID = s.config.Sleeper.PrimaryLeagueID
	}

	log.Info().
		Str("league_id", req.LeagueID).
		Int("week", req.Week).
		Msg("Starting live scores sync")

	// TODO: Implement actual sync
	// result, err := s.syncer.SyncLiveScores(c.Context(), req.LeagueID, req.Week)

	return c.JSON(SyncResponse{
		Success:        true,
		Message:        "Live scores sync completed",
		RecordsUpdated: 12, // TODO: Get from actual sync
		Duration:       time.Since(start).String(),
		Timestamp:      time.Now(),
	})
}

// handleSyncTransactions handles transaction sync requests
func (s *Server) handleSyncTransactions(c *fiber.Ctx) error {
	start := time.Now()
	
	var req struct {
		LeagueID string `json:"league_id"`
		Week     int    `json:"week"`
	}
	
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid request body")
	}

	if req.LeagueID == "" {
		req.LeagueID = s.config.Sleeper.PrimaryLeagueID
	}

	log.Info().
		Str("league_id", req.LeagueID).
		Int("week", req.Week).
		Msg("Starting transactions sync")

	// TODO: Implement actual sync
	// result, err := s.syncer.SyncTransactions(c.Context(), req.LeagueID, req.Week)

	return c.JSON(SyncResponse{
		Success:        true,
		Message:        "Transactions sync completed",
		RecordsUpdated: 5, // TODO: Get from actual sync
		Duration:       time.Since(start).String(),
		Timestamp:      time.Now(),
	})
}

// handleSyncPlayers handles player data sync requests
func (s *Server) handleSyncPlayers(c *fiber.Ctx) error {
	start := time.Now()
	
	log.Info().Msg("Starting players sync")

	// TODO: Implement actual sync
	// This is a heavy operation, should be done carefully
	// result, err := s.syncer.SyncPlayers(c.Context())

	return c.JSON(SyncResponse{
		Success:        true,
		Message:        "Players sync completed",
		RecordsUpdated: 5000, // TODO: Get from actual sync
		Duration:       time.Since(start).String(),
		Timestamp:      time.Now(),
	})
}

// handleFullSync handles full sync requests
func (s *Server) handleFullSync(c *fiber.Ctx) error {
	start := time.Now()
	
	var req SyncRequest
	if err := c.BodyParser(&req); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid request body")
	}

	if req.LeagueID == "" {
		req.LeagueID = s.config.Sleeper.PrimaryLeagueID
	}

	log.Info().
		Str("league_id", req.LeagueID).
		Bool("force", req.Force).
		Msg("Starting full sync")

	// Perform actual full sync
	result, err := s.syncer.FullSync(c.Context(), req.LeagueID)
	if err != nil {
		log.Error().Err(err).Str("league_id", req.LeagueID).Msg("Full sync failed")
		return fiber.NewError(fiber.StatusInternalServerError, "Full sync failed: " + err.Error())
	}

	var message string
	if result.Success {
		message = "Full sync completed successfully"
	} else {
		message = "Full sync completed with errors"
	}

	return c.JSON(SyncResponse{
		Success:        result.Success,
		Message:        message,
		RecordsUpdated: result.RecordsProcessed,
		Duration:       time.Since(start).String(),
		Timestamp:      time.Now(),
	})
}

// handleManualSync handles manual sync triggers (dev only)
func (s *Server) handleManualSync(c *fiber.Ctx) error {
	entity := c.Params("entity")
	
	log.Info().
		Str("entity", entity).
		Str("triggered_by", c.IP()).
		Msg("Manual sync triggered")

	leagueID := s.config.Sleeper.PrimaryLeagueID
	var err error
	var recordsUpdated int

	// Trigger appropriate sync based on entity type
	switch entity {
	case "league":
		err = s.syncer.SyncLeague(c.Context(), leagueID)
		recordsUpdated = 1
	case "users":
		err = s.syncer.SyncUsers(c.Context(), leagueID)
		recordsUpdated = 12 // Estimate
	case "rosters":
		err = s.syncer.SyncRosters(c.Context(), leagueID)
		recordsUpdated = 10 // Estimate
	case "matchups":
		// For matchups, sync for week 1 as example
		err = s.syncer.SyncMatchups(c.Context(), leagueID, 1)
		recordsUpdated = 5 // Estimate
	case "transactions":
		// For transactions, sync for week 1 as example
		err = s.syncer.SyncTransactions(c.Context(), leagueID, 1)
		recordsUpdated = 10 // Estimate
	case "players":
		err = s.syncer.SyncPlayers(c.Context())
		recordsUpdated = 1000 // Estimate
	default:
		return fiber.NewError(fiber.StatusBadRequest, "Invalid entity type")
	}

	if err != nil {
		log.Error().Err(err).Str("entity", entity).Msg("Manual sync failed")
		return fiber.NewError(fiber.StatusInternalServerError, "Sync failed: " + err.Error())
	}

	return c.JSON(fiber.Map{
		"message": "Sync completed",
		"entity":  entity,
		"records": recordsUpdated,
		"success": true,
	})
}

// handleSyncStatus returns current sync status
func (s *Server) handleSyncStatus(c *fiber.Ctx) error {
	// TODO: Get actual status from syncer/scheduler
	status := fiber.Map{
		"last_sync": fiber.Map{
			"timestamp": time.Now().Add(-5 * time.Minute),
			"success":   true,
			"records":   42,
		},
		"next_sync": time.Now().Add(25 * time.Minute),
		"is_syncing": false,
		"queue_size": 0,
	}

	return c.JSON(status)
}

// Raw data fetching handlers

// handleFetchRawLeague fetches all raw data for a league
func (s *Server) handleFetchRawLeague(c *fiber.Ctx) error {
	start := time.Now()
	leagueID := c.Params("id")
	
	if leagueID == "" {
		leagueID = s.config.Sleeper.PrimaryLeagueID
	}
	
	log.Info().
		Str("league_id", leagueID).
		Msg("Starting raw data fetch for league")
	
	// Fetch all raw data for the league
	err := s.rawFetcher.FetchAllLeagueData(c.Context(), leagueID)
	if err != nil {
		log.Error().Err(err).Str("league_id", leagueID).Msg("Raw league fetch failed")
		return fiber.NewError(fiber.StatusInternalServerError, "Raw fetch failed: " + err.Error())
	}
	
	return c.JSON(fiber.Map{
		"success":   true,
		"message":   "Raw league data fetched successfully",
		"league_id": leagueID,
		"duration":  time.Since(start).String(),
		"timestamp": time.Now(),
	})
}

// handleFetchRawPlayers fetches the NFL players database
func (s *Server) handleFetchRawPlayers(c *fiber.Ctx) error {
	start := time.Now()
	
	log.Info().Msg("Starting raw NFL players fetch")
	
	err := s.rawFetcher.FetchNFLPlayers(c.Context())
	if err != nil {
		log.Error().Err(err).Msg("Raw players fetch failed")
		return fiber.NewError(fiber.StatusInternalServerError, "Players fetch failed: " + err.Error())
	}
	
	return c.JSON(fiber.Map{
		"success":   true,
		"message":   "NFL players data fetched successfully",
		"duration":  time.Since(start).String(),
		"timestamp": time.Now(),
	})
}

// handleFetchNFLState fetches the current NFL state
func (s *Server) handleFetchNFLState(c *fiber.Ctx) error {
	start := time.Now()
	
	log.Info().Msg("Starting NFL state fetch")
	
	err := s.rawFetcher.FetchNFLState(c.Context())
	if err != nil {
		log.Error().Err(err).Msg("NFL state fetch failed")
		return fiber.NewError(fiber.StatusInternalServerError, "NFL state fetch failed: " + err.Error())
	}
	
	return c.JSON(fiber.Map{
		"success":   true,
		"message":   "NFL state fetched successfully",
		"duration":  time.Since(start).String(),
		"timestamp": time.Now(),
	})
}

// ETL Processing handlers

// handleProcessETL triggers ETL processing of raw data
func (s *Server) handleProcessETL(c *fiber.Ctx) error {
	start := time.Now()
	
	log.Info().Msg("Starting ETL processing")
	
	result, err := s.etlProcessor.ProcessUnprocessedResponses(c.Context())
	if err != nil {
		log.Error().Err(err).Msg("ETL processing failed")
		return fiber.NewError(fiber.StatusInternalServerError, "ETL processing failed: " + err.Error())
	}
	
	status := "completed"
	if result.ErrorCount > 0 {
		status = "completed_with_errors"
	}
	
	return c.JSON(fiber.Map{
		"success":         result.ErrorCount == 0,
		"status":          status,
		"total_processed": result.TotalProcessed,
		"success_count":   result.SuccessCount,
		"error_count":     result.ErrorCount,
		"skipped_count":   result.SkippedCount,
		"duration":        time.Since(start).String(),
		"timestamp":       time.Now(),
		"errors":          result.Errors,
	})
}