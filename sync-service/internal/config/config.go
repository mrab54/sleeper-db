package config

import (
	"fmt"
	"time"

	"github.com/spf13/viper"
)

// Config represents the application configuration
type Config struct {
	Server      ServerConfig   `mapstructure:"server"`
	Database    DatabaseConfig `mapstructure:"database"`
	DatabaseRaw DatabaseConfig `mapstructure:"database_raw"`
	Sleeper     SleeperConfig  `mapstructure:"sleeper"`
	Hasura      HasuraConfig   `mapstructure:"hasura"`
	Metrics     MetricsConfig  `mapstructure:"metrics"`
}

// ServerConfig contains HTTP server settings
type ServerConfig struct {
	Port         int           `mapstructure:"port"`
	Host         string        `mapstructure:"host"`
	Environment  string        `mapstructure:"environment"`
	LogLevel     string        `mapstructure:"log_level"`
	ReadTimeout  time.Duration `mapstructure:"read_timeout"`
	WriteTimeout time.Duration `mapstructure:"write_timeout"`
	IdleTimeout  time.Duration `mapstructure:"idle_timeout"`
}

// DatabaseConfig contains PostgreSQL settings
type DatabaseConfig struct {
	Host            string        `mapstructure:"host"`
	Port            int           `mapstructure:"port"`
	User            string        `mapstructure:"user"`
	Password        string        `mapstructure:"password"`
	Database        string        `mapstructure:"database"`
	SSLMode         string        `mapstructure:"ssl_mode"`
	MaxConnections  int           `mapstructure:"max_connections"`
	MinConnections  int           `mapstructure:"min_connections"`
	MaxConnLifetime time.Duration `mapstructure:"max_conn_lifetime"`
	MaxConnIdleTime time.Duration `mapstructure:"max_conn_idle_time"`
}


// SleeperConfig contains Sleeper API settings
type SleeperConfig struct {
	BaseURL        string        `mapstructure:"base_url"`
	PrimaryLeagueID string       `mapstructure:"primary_league_id"`
	RateLimit      int           `mapstructure:"rate_limit"`
	RequestTimeout time.Duration `mapstructure:"request_timeout"`
	RetryAttempts  int           `mapstructure:"retry_attempts"`
	RetryDelay     time.Duration `mapstructure:"retry_delay"`
}

// HasuraConfig contains Hasura webhook settings
type HasuraConfig struct {
	AdminSecret string `mapstructure:"admin_secret"`
	Endpoint    string `mapstructure:"endpoint"`
}

// MetricsConfig contains Prometheus metrics settings
type MetricsConfig struct {
	Enabled bool   `mapstructure:"enabled"`
	Path    string `mapstructure:"path"`
}

// Load reads configuration from file and environment variables
func Load() (*Config, error) {
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath("/app/config")  // Docker volume mount
	viper.AddConfigPath("/etc/sleeper/")
	viper.AddConfigPath("$HOME/.sleeper")
	viper.AddConfigPath(".")
	viper.AddConfigPath("./config")

	// Set defaults first
	setDefaults()

	// Manual environment variable bindings to match docker-compose.yml
	viper.BindEnv("server.port", "SERVER_PORT")
	viper.BindEnv("server.host", "SERVER_HOST")
	viper.BindEnv("server.environment", "SERVER_ENVIRONMENT")
	viper.BindEnv("server.log_level", "SERVER_LOG_LEVEL")
	
	viper.BindEnv("database.host", "DATABASE_HOST")
	viper.BindEnv("database.port", "DATABASE_PORT")
	viper.BindEnv("database.user", "DATABASE_USER")
	viper.BindEnv("database.password", "DATABASE_PASSWORD")
	viper.BindEnv("database.database", "DATABASE_NAME")
	viper.BindEnv("database.ssl_mode", "DATABASE_SSL_MODE")
	
	// Raw database bindings
	viper.BindEnv("database_raw.host", "DATABASE_RAW_HOST")
	viper.BindEnv("database_raw.port", "DATABASE_RAW_PORT")
	viper.BindEnv("database_raw.user", "DATABASE_RAW_USER")
	viper.BindEnv("database_raw.password", "DATABASE_RAW_PASSWORD")
	viper.BindEnv("database_raw.database", "DATABASE_RAW_NAME")
	viper.BindEnv("database_raw.ssl_mode", "DATABASE_RAW_SSL_MODE")
	
	viper.BindEnv("sleeper.base_url", "SLEEPER_BASE_URL")
	viper.BindEnv("sleeper.primary_league_id", "SLEEPER_PRIMARY_LEAGUE_ID")
	
	viper.BindEnv("hasura.admin_secret", "HASURA_ADMIN_SECRET")
	viper.BindEnv("hasura.endpoint", "HASURA_ENDPOINT")

	// Read config file (optional)
	if err := viper.ReadInConfig(); err != nil {
		// It's okay if config file doesn't exist, we have defaults and env vars
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("error reading config file: %w", err)
		}
	}

	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("unable to decode config: %w", err)
	}

	// Validate configuration
	if err := validate(&config); err != nil {
		return nil, fmt.Errorf("invalid configuration: %w", err)
	}

	return &config, nil
}

// setDefaults sets default configuration values
func setDefaults() {
	// Server defaults
	viper.SetDefault("server.port", 8000)
	viper.SetDefault("server.host", "0.0.0.0")
	viper.SetDefault("server.environment", "development")
	viper.SetDefault("server.log_level", "info")
	viper.SetDefault("server.read_timeout", 30*time.Second)
	viper.SetDefault("server.write_timeout", 30*time.Second)
	viper.SetDefault("server.idle_timeout", 120*time.Second)

	// Analytics Database defaults
	viper.SetDefault("database.host", "localhost")
	viper.SetDefault("database.port", 5432)
	viper.SetDefault("database.ssl_mode", "disable")
	viper.SetDefault("database.max_connections", 25)
	viper.SetDefault("database.min_connections", 5)
	viper.SetDefault("database.max_conn_lifetime", time.Hour)
	viper.SetDefault("database.max_conn_idle_time", 30*time.Minute)

	// Raw Database defaults
	viper.SetDefault("database_raw.host", "localhost")
	viper.SetDefault("database_raw.port", 5434)
	viper.SetDefault("database_raw.ssl_mode", "disable")
	viper.SetDefault("database_raw.max_connections", 25)
	viper.SetDefault("database_raw.min_connections", 5)
	viper.SetDefault("database_raw.max_conn_lifetime", time.Hour)
	viper.SetDefault("database_raw.max_conn_idle_time", 30*time.Minute)

	// Sleeper API defaults
	viper.SetDefault("sleeper.base_url", "https://api.sleeper.app/v1")
	viper.SetDefault("sleeper.rate_limit", 500) // requests per minute
	viper.SetDefault("sleeper.request_timeout", 30*time.Second)
	viper.SetDefault("sleeper.retry_attempts", 3)
	viper.SetDefault("sleeper.retry_delay", 2*time.Second)

	// Metrics defaults
	viper.SetDefault("metrics.enabled", true)
	viper.SetDefault("metrics.path", "/metrics")
}

// validate checks if the configuration is valid
func validate(cfg *Config) error {
	// Analytics Database validation
	if cfg.Database.User == "" {
		return fmt.Errorf("analytics database user is required")
	}
	if cfg.Database.Database == "" {
		return fmt.Errorf("analytics database name is required")
	}
	if cfg.Database.Host == "" {
		return fmt.Errorf("analytics database host is required")
	}
	if cfg.Database.Port <= 0 || cfg.Database.Port > 65535 {
		return fmt.Errorf("invalid analytics database port: %d", cfg.Database.Port)
	}
	
	// Raw Database validation
	if cfg.DatabaseRaw.User == "" {
		return fmt.Errorf("raw database user is required")
	}
	if cfg.DatabaseRaw.Database == "" {
		return fmt.Errorf("raw database name is required")
	}
	if cfg.DatabaseRaw.Host == "" {
		return fmt.Errorf("raw database host is required")
	}
	if cfg.DatabaseRaw.Port <= 0 || cfg.DatabaseRaw.Port > 65535 {
		return fmt.Errorf("invalid raw database port: %d", cfg.DatabaseRaw.Port)
	}
	
	// Sleeper API validation
	if cfg.Sleeper.PrimaryLeagueID == "" {
		return fmt.Errorf("primary league ID is required")
	}
	if cfg.Sleeper.BaseURL == "" {
		return fmt.Errorf("Sleeper API base URL is required")
	}
	
	// Server validation
	if cfg.Server.Port <= 0 || cfg.Server.Port > 65535 {
		return fmt.Errorf("invalid server port: %d", cfg.Server.Port)
	}
	
	return nil
}

// GetDSN returns the PostgreSQL connection string for analytics database
func (c *DatabaseConfig) GetDSN() string {
	return fmt.Sprintf("postgres://%s:%s@%s:%d/%s?sslmode=%s&search_path=analytics",
		c.User, c.Password, c.Host, c.Port, c.Database, c.SSLMode)
}

// GetRawDSN returns the PostgreSQL connection string for raw database
func (c *DatabaseConfig) GetRawDSN() string {
	return fmt.Sprintf("postgres://%s:%s@%s:%d/%s?sslmode=%s&search_path=raw",
		c.User, c.Password, c.Host, c.Port, c.Database, c.SSLMode)
}
