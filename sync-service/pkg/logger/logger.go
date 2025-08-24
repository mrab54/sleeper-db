package logger

import (
	"os"
	"time"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

// Init initializes the global logger with the specified environment and level
func Init(environment, level string) {
	// Set time format
	zerolog.TimeFieldFormat = time.RFC3339Nano

	// Configure based on environment
	if environment == "development" {
		// Pretty console logging for development
		log.Logger = log.Output(zerolog.ConsoleWriter{
			Out:        os.Stdout,
			TimeFormat: "15:04:05.000",
			NoColor:    false,
		})
	} else {
		// JSON logging for production
		log.Logger = log.Output(os.Stdout)
	}

	// Set log level
	logLevel := parseLevel(level)
	zerolog.SetGlobalLevel(logLevel)

	// Add global context
	log.Logger = log.With().
		Str("service", "sleeper-sync").
		Str("environment", environment).
		Logger()
}

// parseLevel converts string log level to zerolog level
func parseLevel(level string) zerolog.Level {
	switch level {
	case "trace":
		return zerolog.TraceLevel
	case "debug":
		return zerolog.DebugLevel
	case "info":
		return zerolog.InfoLevel
	case "warn", "warning":
		return zerolog.WarnLevel
	case "error":
		return zerolog.ErrorLevel
	case "fatal":
		return zerolog.FatalLevel
	case "panic":
		return zerolog.PanicLevel
	default:
		return zerolog.InfoLevel
	}
}

// WithContext returns a logger with additional context fields
func WithContext(fields map[string]interface{}) zerolog.Logger {
	logger := log.Logger
	for key, value := range fields {
		logger = logger.With().Interface(key, value).Logger()
	}
	return logger
}

// WithRequestID returns a logger with request ID
func WithRequestID(requestID string) zerolog.Logger {
	return log.With().Str("request_id", requestID).Logger()
}