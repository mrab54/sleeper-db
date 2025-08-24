package config

import (
	"fmt"
	"strings"
	"time"

	"github.com/spf13/viper"
)

// Config represents the application configuration
type Config struct {
	Server   ServerConfig   `mapstructure:"server"`
	Database DatabaseConfig `mapstructure:"database"`
	Redis    RedisConfig    `mapstructure:"redis"`
	Sleeper  SleeperConfig  `mapstructure:"sleeper"`
	Hasura   HasuraConfig   `mapstructure:"hasura"`
	Metrics  MetricsConfig  `mapstructure:"metrics"`
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

// RedisConfig contains Redis cache settings
type RedisConfig struct {
	Host         string        `mapstructure:"host"`
	Port         int           `mapstructure:"port"`
	Password     string        `mapstructure:"password"`
	Database     int           `mapstructure:"database"`
	MaxRetries   int           `mapstructure:"max_retries"`
	DialTimeout  time.Duration `mapstructure:"dial_timeout"`
	ReadTimeout  time.Duration `mapstructure:"read_timeout"`
	WriteTimeout time.Duration `mapstructure:"write_timeout"`
	PoolSize     int           `mapstructure:"pool_size"`
	MinIdleConns int           `mapstructure:"min_idle_conns"`
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
	viper.AddConfigPath("/etc/sleeper/")
	viper.AddConfigPath("$HOME/.sleeper")
	viper.AddConfigPath(".")
	viper.AddConfigPath("./config")

	// Environment variable overrides
	viper.SetEnvPrefix("SLEEPER")
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	viper.AutomaticEnv()

	// Set defaults
	setDefaults()

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

	// Database defaults
	viper.SetDefault("database.host", "localhost")
	viper.SetDefault("database.port", 5432)
	viper.SetDefault("database.ssl_mode", "disable")
	viper.SetDefault("database.max_connections", 25)
	viper.SetDefault("database.min_connections", 5)
	viper.SetDefault("database.max_conn_lifetime", time.Hour)
	viper.SetDefault("database.max_conn_idle_time", 30*time.Minute)

	// Redis defaults
	viper.SetDefault("redis.host", "localhost")
	viper.SetDefault("redis.port", 6379)
	viper.SetDefault("redis.database", 0)
	viper.SetDefault("redis.max_retries", 3)
	viper.SetDefault("redis.dial_timeout", 5*time.Second)
	viper.SetDefault("redis.read_timeout", 3*time.Second)
	viper.SetDefault("redis.write_timeout", 3*time.Second)
	viper.SetDefault("redis.pool_size", 10)
	viper.SetDefault("redis.min_idle_conns", 5)

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
	if cfg.Database.User == "" {
		return fmt.Errorf("database user is required")
	}
	if cfg.Database.Database == "" {
		return fmt.Errorf("database name is required")
	}
	if cfg.Sleeper.PrimaryLeagueID == "" {
		return fmt.Errorf("primary league ID is required")
	}
	return nil
}

// GetDSN returns the PostgreSQL connection string
func (c *DatabaseConfig) GetDSN() string {
	return fmt.Sprintf("postgres://%s:%s@%s:%d/%s?sslmode=%s",
		c.User, c.Password, c.Host, c.Port, c.Database, c.SSLMode)
}

// GetRedisAddr returns the Redis address
func (c *RedisConfig) GetAddr() string {
	return fmt.Sprintf("%s:%d", c.Host, c.Port)
}