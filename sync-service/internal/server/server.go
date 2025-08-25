package server

import (
	"context"
	"fmt"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/compress"
	"github.com/gofiber/fiber/v2/middleware/cors"
	fiberlogger "github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/gofiber/fiber/v2/middleware/requestid"
	"github.com/mrab54/sleeper-db/sync-service/internal/api"
	"github.com/mrab54/sleeper-db/sync-service/internal/config"
	"github.com/mrab54/sleeper-db/sync-service/internal/database"
	"github.com/mrab54/sleeper-db/sync-service/internal/database/repositories"
	"github.com/mrab54/sleeper-db/sync-service/internal/etl"
	"github.com/mrab54/sleeper-db/sync-service/internal/scheduler"
	"github.com/mrab54/sleeper-db/sync-service/internal/sync"
	"go.uber.org/zap"
)

// Server represents the HTTP server
type Server struct {
	app          *fiber.App
	config       *config.Config
	db           *database.DB      // Analytics database
	dbRaw        *database.DB      // Raw database
	apiClient    *api.SleeperClient
	syncer       *sync.Syncer
	rawFetcher   *sync.RawDataFetcher
	etlProcessor *etl.Processor
	scheduler    *scheduler.Scheduler
	logger       *zap.Logger
}

// New creates a new server instance
func New(cfg *config.Config, logger *zap.Logger) (*Server, error) {
	// Initialize analytics database
	dbConfig := &database.Config{
		Host:            cfg.Database.Host,
		Port:            cfg.Database.Port,
		User:            cfg.Database.User,
		Password:        cfg.Database.Password,
		Database:        cfg.Database.Database,
		SSLMode:         cfg.Database.SSLMode,
		Schema:          "analytics",
		MaxConns:        int32(cfg.Database.MaxConnections),
		MinConns:        int32(cfg.Database.MinConnections),
		MaxConnLifetime: time.Duration(cfg.Database.MaxConnLifetime) * time.Second,
		MaxConnIdleTime: time.Duration(cfg.Database.MaxConnIdleTime) * time.Second,
	}

	db, err := database.NewAnalyticsDB(context.Background(), dbConfig, logger)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to analytics database: %w", err)
	}

	// Initialize raw database
	dbRawConfig := &database.Config{
		Host:            cfg.DatabaseRaw.Host,
		Port:            cfg.DatabaseRaw.Port,
		User:            cfg.DatabaseRaw.User,
		Password:        cfg.DatabaseRaw.Password,
		Database:        cfg.DatabaseRaw.Database,
		SSLMode:         cfg.DatabaseRaw.SSLMode,
		Schema:          "raw",
		MaxConns:        int32(cfg.DatabaseRaw.MaxConnections),
		MinConns:        int32(cfg.DatabaseRaw.MinConnections),
		MaxConnLifetime: time.Duration(cfg.DatabaseRaw.MaxConnLifetime) * time.Second,
		MaxConnIdleTime: time.Duration(cfg.DatabaseRaw.MaxConnIdleTime) * time.Second,
	}

	dbRaw, err := database.NewRawDB(context.Background(), dbRawConfig, logger)
	if err != nil {
		db.Close() // Clean up analytics DB
		return nil, fmt.Errorf("failed to connect to raw database: %w", err)
	}

	// Initialize Sleeper API client
	apiClient := api.NewSleeperClient(cfg.Sleeper.BaseURL, logger)

	// Initialize repositories
	rawRepo := repositories.NewRawRepository(dbRaw.Pool())

	// Initialize syncer for analytics database
	syncer := sync.NewSyncer(apiClient, db, logger)

	// Initialize raw data fetcher
	rawFetcher := sync.NewRawDataFetcher(apiClient, rawRepo, logger)

	// Initialize ETL processor
	etlProcessor := etl.NewProcessor(db, dbRaw, logger)

	// Initialize scheduler
	sched := scheduler.NewScheduler(syncer, logger)

	// Create Fiber app with configuration
	app := fiber.New(fiber.Config{
		AppName:               "Sleeper Sync Service",
		DisableStartupMessage: cfg.Server.Environment == "production",
		ServerHeader:          "Sleeper-Sync",
		StrictRouting:         true,
		CaseSensitive:         true,
		Immutable:             true,
		UnescapePath:          true,
		BodyLimit:             4 * 1024 * 1024, // 4MB
		ReadTimeout:           cfg.Server.ReadTimeout,
		WriteTimeout:          cfg.Server.WriteTimeout,
		IdleTimeout:           cfg.Server.IdleTimeout,
		Concurrency:           256 * 1024,
		ErrorHandler: func(c *fiber.Ctx, err error) error {
			return customErrorHandler(c, err, logger)
		},
	})

	// Setup middleware
	setupMiddleware(app, cfg, logger)

	s := &Server{
		app:          app,
		config:       cfg,
		db:           db,
		dbRaw:        dbRaw,
		apiClient:    apiClient,
		syncer:       syncer,
		rawFetcher:   rawFetcher,
		etlProcessor: etlProcessor,
		scheduler:    sched,
		logger:       logger,
	}

	// Setup routes
	s.setupRoutes()


	return s, nil
}

// setupMiddleware configures all middleware
func setupMiddleware(app *fiber.App, cfg *config.Config, logger *zap.Logger) {
	// Recover from panics
	app.Use(recover.New(recover.Config{
		EnableStackTrace: cfg.Server.Environment == "development",
	}))

	// Request ID
	app.Use(requestid.New())

	// Logging
	if cfg.Server.Environment == "development" {
		app.Use(fiberlogger.New(fiberlogger.Config{
			Format:     "[${time}] ${status} - ${latency} ${method} ${path} ${error}\n",
			TimeFormat: "15:04:05.000",
		}))
	} else {
		// Production uses structured logging via zap
		app.Use(func(c *fiber.Ctx) error {
			start := time.Now()
			
			// Continue to next handler
			err := c.Next()
			
			// Log request
			logger.Info("HTTP Request",
				zap.String("request_id", c.Locals("requestid").(string)),
				zap.String("method", c.Method()),
				zap.String("path", c.Path()),
				zap.Int("status", c.Response().StatusCode()),
				zap.Duration("latency", time.Since(start)),
				zap.String("ip", c.IP()),
			)
			
			return err
		})
	}

	// CORS for development
	if cfg.Server.Environment == "development" {
		app.Use(cors.New(cors.Config{
			AllowOrigins: "*",
			AllowHeaders: "Origin, Content-Type, Accept, Authorization",
			AllowMethods: "GET, POST, PUT, DELETE, OPTIONS",
		}))
	}

	// Compression
	app.Use(compress.New(compress.Config{
		Level: compress.LevelBestSpeed,
	}))
}

// setupRoutes configures all routes
func (s *Server) setupRoutes() {
	// Health checks
	s.app.Get("/health", s.handleHealth)
	s.app.Get("/ready", s.handleReady)

	// Metrics endpoint (if enabled)
	if s.config.Metrics.Enabled {
		// TODO: Add Prometheus metrics handler
		// s.app.Get(s.config.Metrics.Path, adaptor.HTTPHandler(promhttp.Handler()))
	}

	// API v1 routes
	api := s.app.Group("/api/v1")

	// Sync endpoints (called by Hasura scheduled events)
	sync := api.Group("/sync")
	sync.Post("/league", s.handleSyncLeague)
	sync.Post("/live-scores", s.handleSyncLiveScores)
	sync.Post("/transactions", s.handleSyncTransactions)
	sync.Post("/players", s.handleSyncPlayers)
	sync.Post("/full", s.handleFullSync)

	// Raw data fetching endpoints
	raw := api.Group("/raw")
	raw.Post("/fetch/league/:id", s.handleFetchRawLeague)
	raw.Post("/fetch/players", s.handleFetchRawPlayers)
	raw.Post("/fetch/nfl-state", s.handleFetchNFLState)

	// ETL processing endpoints
	etl := api.Group("/etl")
	etl.Post("/process", s.handleProcessETL)

	// Manual trigger endpoints (for debugging/admin)
	if s.config.Server.Environment == "development" {
		admin := api.Group("/admin")
		admin.Post("/trigger-sync/:entity", s.handleManualSync)
		admin.Get("/sync-status", s.handleSyncStatus)
	}
}

// Start starts the HTTP server
func (s *Server) Start(ctx context.Context) error {
	addr := fmt.Sprintf("%s:%d", s.config.Server.Host, s.config.Server.Port)
	
	s.logger.Info("Starting HTTP server",
		zap.String("address", addr),
		zap.String("environment", s.config.Server.Environment),
	)

	// Start scheduler
	if err := s.scheduler.Start(); err != nil {
		return fmt.Errorf("failed to start scheduler: %w", err)
	}

	// Schedule initial jobs
	s.scheduleJobs()

	// Start server
	errChan := make(chan error, 1)
	go func() {
		if err := s.app.Listen(addr); err != nil {
			errChan <- err
		}
	}()

	select {
	case <-ctx.Done():
		return s.Shutdown(ctx)
	case err := <-errChan:
		return err
	}
}

// Shutdown gracefully shuts down the server
func (s *Server) Shutdown(ctx context.Context) error {
	s.logger.Info("Shutting down server...")

	// Stop scheduler
	s.scheduler.Stop()

	// Close database connections
	s.db.Close()
	s.dbRaw.Close()

	// Shutdown Fiber app
	return s.app.ShutdownWithContext(ctx)
}

// scheduleJobs sets up recurring sync jobs
func (s *Server) scheduleJobs() {
	// Schedule raw data fetch daily at 2 AM
	s.scheduler.AddCronJob("daily_raw_fetch", "0 2 * * *", func() {
		ctx := context.Background()
		s.logger.Info("Running scheduled raw data fetch")
		
		// Fetch league data
		err := s.rawFetcher.FetchAllLeagueData(ctx, s.config.Sleeper.PrimaryLeagueID)
		if err != nil {
			s.logger.Error("Scheduled raw fetch failed", zap.Error(err))
		}
		
		// Fetch players (weekly)
		if time.Now().Weekday() == time.Sunday {
			err = s.rawFetcher.FetchNFLPlayers(ctx)
			if err != nil {
				s.logger.Error("Scheduled players fetch failed", zap.Error(err))
			}
		}
	})

	// Schedule ETL processing every 30 minutes
	s.scheduler.AddCronJob("etl_processing", "*/30 * * * *", func() {
		ctx := context.Background()
		s.logger.Info("Running scheduled ETL processing")
		
		result, err := s.etlProcessor.ProcessUnprocessedResponses(ctx)
		if err != nil {
			s.logger.Error("Scheduled ETL processing failed", zap.Error(err))
		} else {
			s.logger.Info("ETL processing completed",
				zap.Int("processed", result.TotalProcessed),
				zap.Int("success", result.SuccessCount),
				zap.Int("errors", result.ErrorCount),
			)
		}
	})

	// Schedule full sync daily at 3 AM (legacy - for direct sync)
	s.scheduler.AddCronJob("daily_full_sync", "0 3 * * *", func() {
		ctx := context.Background()
		s.logger.Info("Running scheduled full sync")
		_, err := s.syncer.FullSync(ctx, s.config.Sleeper.PrimaryLeagueID)
		if err != nil {
			s.logger.Error("Scheduled full sync failed", zap.Error(err))
		}
	})

	// Schedule roster sync every hour
	s.scheduler.AddIntervalJob("hourly_roster_sync", time.Hour, func() {
		ctx := context.Background()
		s.logger.Info("Running scheduled roster sync")
		// First ensure league exists
		if err := s.syncer.SyncLeague(ctx, s.config.Sleeper.PrimaryLeagueID); err != nil {
			s.logger.Error("Failed to sync league before rosters", zap.Error(err))
			return
		}
		err := s.syncer.SyncRosters(ctx, s.config.Sleeper.PrimaryLeagueID)
		if err != nil {
			s.logger.Error("Scheduled roster sync failed", zap.Error(err))
		}
	})

	// Schedule transaction sync every 30 minutes
	s.scheduler.AddIntervalJob("transaction_sync", 30*time.Minute, func() {
		ctx := context.Background()
		s.logger.Info("Running scheduled transaction sync")
		
		// First ensure league exists
		if err := s.syncer.SyncLeague(ctx, s.config.Sleeper.PrimaryLeagueID); err != nil {
			s.logger.Error("Failed to sync league before transactions", zap.Error(err))
			return
		}
		
		// Get current NFL week
		nflState, err := s.syncer.GetNFLState(ctx)
		if err != nil {
			s.logger.Error("Failed to get NFL state", zap.Error(err))
			return
		}
		
		err = s.syncer.SyncTransactions(ctx, s.config.Sleeper.PrimaryLeagueID, nflState.Week)
		if err != nil {
			s.logger.Error("Scheduled transaction sync failed", zap.Error(err))
		}
	})

	s.logger.Info("Scheduled jobs configured")
}

// customErrorHandler handles errors in a consistent way
func customErrorHandler(c *fiber.Ctx, err error, logger *zap.Logger) error {
	// Default to 500 Internal Server Error
	code := fiber.StatusInternalServerError
	message := "Internal Server Error"

	// Check if it's a Fiber error
	if e, ok := err.(*fiber.Error); ok {
		code = e.Code
		message = e.Message
	}

	// Log error
	logger.Error("Request error",
		zap.Error(err),
		zap.String("request_id", c.Locals("requestid").(string)),
		zap.String("method", c.Method()),
		zap.String("path", c.Path()),
		zap.Int("status", code),
	)

	// Return JSON error response
	return c.Status(code).JSON(fiber.Map{
		"error": fiber.Map{
			"message": message,
			"code":    code,
		},
		"request_id": c.Locals("requestid"),
	})
}