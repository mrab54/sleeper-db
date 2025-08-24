package server

import (
	"context"
	"fmt"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/compress"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/gofiber/fiber/v2/middleware/requestid"
	"github.com/mrab54/sleeper-db/internal/config"
	"github.com/rs/zerolog/log"
)

// Server represents the HTTP server
type Server struct {
	app    *fiber.App
	config *config.Config
	// TODO: Add these when implemented
	// api      *api.Client
	// db       *database.DB
	// syncer   *sync.Syncer
	// scheduler *scheduler.Scheduler
}

// New creates a new server instance
func New(cfg *config.Config) (*Server, error) {
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
		ErrorHandler:          customErrorHandler,
	})

	// Setup middleware
	setupMiddleware(app, cfg)

	s := &Server{
		app:    app,
		config: cfg,
	}

	// Setup routes
	s.setupRoutes()

	// TODO: Initialize dependencies
	// s.api = api.NewClient(cfg.Sleeper)
	// s.db = database.New(cfg.Database)
	// s.syncer = sync.New(s.api, s.db)
	// s.scheduler = scheduler.New(s.syncer, cfg)

	return s, nil
}

// setupMiddleware configures all middleware
func setupMiddleware(app *fiber.App, cfg *config.Config) {
	// Recover from panics
	app.Use(recover.New(recover.Config{
		EnableStackTrace: cfg.Server.Environment == "development",
	}))

	// Request ID
	app.Use(requestid.New())

	// Logging
	if cfg.Server.Environment == "development" {
		app.Use(logger.New(logger.Config{
			Format:     "[${time}] ${status} - ${latency} ${method} ${path} ${error}\n",
			TimeFormat: "15:04:05.000",
		}))
	} else {
		// Production uses structured logging via zerolog
		app.Use(func(c *fiber.Ctx) error {
			start := time.Now()
			
			// Continue to next handler
			err := c.Next()
			
			// Log request
			log.Info().
				Str("request_id", c.Locals("requestid").(string)).
				Str("method", c.Method()).
				Str("path", c.Path()).
				Int("status", c.Response().StatusCode()).
				Dur("latency", time.Since(start)).
				Str("ip", c.IP()).
				Msg("HTTP Request")
			
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
	
	log.Info().
		Str("address", addr).
		Str("environment", s.config.Server.Environment).
		Msg("Starting HTTP server")

	// Start scheduler
	// TODO: s.scheduler.Start(ctx)

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
	log.Info().Msg("Shutting down server...")

	// TODO: Stop scheduler
	// s.scheduler.Stop()

	// TODO: Close database connections
	// s.db.Close()

	// Shutdown Fiber app
	return s.app.ShutdownWithContext(ctx)
}

// customErrorHandler handles errors in a consistent way
func customErrorHandler(c *fiber.Ctx, err error) error {
	// Default to 500 Internal Server Error
	code := fiber.StatusInternalServerError
	message := "Internal Server Error"

	// Check if it's a Fiber error
	if e, ok := err.(*fiber.Error); ok {
		code = e.Code
		message = e.Message
	}

	// Log error
	log.Error().
		Err(err).
		Str("request_id", c.Locals("requestid").(string)).
		Str("method", c.Method()).
		Str("path", c.Path()).
		Int("status", code).
		Msg("Request error")

	// Return JSON error response
	return c.Status(code).JSON(fiber.Map{
		"error": fiber.Map{
			"message": message,
			"code":    code,
		},
		"request_id": c.Locals("requestid"),
	})
}