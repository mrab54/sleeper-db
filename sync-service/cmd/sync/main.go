package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/mrab54/sleeper-db/internal/config"
	"github.com/mrab54/sleeper-db/internal/server"
	"github.com/mrab54/sleeper-db/pkg/logger"
	"github.com/rs/zerolog/log"
)

var (
	version = "dev"
	commit  = "none"
	date    = "unknown"
)

func main() {
	// Print version info
	fmt.Printf("Sleeper Sync Service\n")
	fmt.Printf("Version: %s, Commit: %s, Built: %s\n", version, commit, date)

	// Handle command line arguments
	if len(os.Args) > 1 && os.Args[1] == "health" {
		// Quick health check for Docker
		os.Exit(0)
	}

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to load configuration: %v\n", err)
		os.Exit(1)
	}

	// Initialize logger
	logger.Init(cfg.Server.Environment, cfg.Server.LogLevel)
	
	log.Info().
		Str("version", version).
		Str("commit", commit).
		Str("built", date).
		Str("environment", cfg.Server.Environment).
		Msg("Starting Sleeper Sync Service")

	// Create context that listens for the interrupt signal
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle shutdown gracefully
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	
	go func() {
		<-sigChan
		log.Info().Msg("Shutdown signal received")
		cancel()
	}()

	// Initialize and start server
	srv, err := server.New(cfg)
	if err != nil {
		log.Fatal().Err(err).Msg("Failed to create server")
	}

	// Start server in goroutine
	serverErr := make(chan error, 1)
	go func() {
		if err := srv.Start(ctx); err != nil {
			serverErr <- err
		}
	}()

	// Wait for context cancellation or server error
	select {
	case <-ctx.Done():
		log.Info().Msg("Context cancelled, shutting down...")
	case err := <-serverErr:
		log.Error().Err(err).Msg("Server error")
		cancel()
	}

	// Graceful shutdown with timeout
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Error().Err(err).Msg("Error during shutdown")
	}

	log.Info().Msg("Service stopped")
}