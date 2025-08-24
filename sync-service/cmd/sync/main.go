package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/mrab54/sleeper-db/sync-service/internal/config"
	"github.com/mrab54/sleeper-db/sync-service/internal/server"
	"github.com/mrab54/sleeper-db/sync-service/pkg/logger"
	"go.uber.org/zap"
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
	log := logger.New(cfg.Server.LogLevel)
	defer log.Sync()
	
	log.Info("Starting Sleeper Sync Service",
		zap.String("version", version),
		zap.String("commit", commit),
		zap.String("built", date),
		zap.String("environment", cfg.Server.Environment),
	)

	// Create context that listens for the interrupt signal
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle shutdown gracefully
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	
	go func() {
		<-sigChan
		log.Info("Shutdown signal received")
		cancel()
	}()

	// Initialize and start server
	srv, err := server.New(cfg, log)
	if err != nil {
		log.Fatal("Failed to create server", zap.Error(err))
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
		log.Info("Context cancelled, shutting down...")
	case err := <-serverErr:
		log.Error("Server error", zap.Error(err))
		cancel()
	}

	// Graceful shutdown with timeout
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer shutdownCancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Error("Error during shutdown", zap.Error(err))
	}

	log.Info("Service stopped")
}