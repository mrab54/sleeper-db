package api

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/go-resty/resty/v2"
	"go.uber.org/zap"
	"golang.org/x/time/rate"
)

// SleeperClient is the main client for interacting with the Sleeper API
type SleeperClient struct {
	client      *resty.Client
	baseURL     string
	rateLimiter *rate.Limiter
	logger      *zap.Logger
}

// NewSleeperClient creates a new Sleeper API client
func NewSleeperClient(baseURL string, logger *zap.Logger) *SleeperClient {
	client := resty.New().
		SetTimeout(30 * time.Second).
		SetRetryCount(3).
		SetRetryWaitTime(1 * time.Second).
		SetRetryMaxWaitTime(10 * time.Second).
		AddRetryCondition(func(r *resty.Response, err error) bool {
			return r.StatusCode() >= 500 || r.StatusCode() == 429
		})

	return &SleeperClient{
		client:      client,
		baseURL:     baseURL,
		rateLimiter: rate.NewLimiter(rate.Every(100*time.Millisecond), 10), // 10 requests per second burst
		logger:      logger,
	}
}

// doRequest performs a rate-limited HTTP request
func (c *SleeperClient) doRequest(ctx context.Context, method, endpoint string, result interface{}) error {
	// Wait for rate limiter
	if err := c.rateLimiter.Wait(ctx); err != nil {
		return fmt.Errorf("rate limiter error: %w", err)
	}

	url := c.baseURL + endpoint
	c.logger.Debug("Making API request",
		zap.String("method", method),
		zap.String("url", url),
	)

	resp, err := c.client.R().
		SetContext(ctx).
		SetHeader("Accept", "application/json").
		Execute(method, url)

	if err != nil {
		c.logger.Error("API request failed",
			zap.String("url", url),
			zap.Error(err),
		)
		return fmt.Errorf("request failed: %w", err)
	}

	if resp.StatusCode() != http.StatusOK {
		c.logger.Error("API returned non-200 status",
			zap.String("url", url),
			zap.Int("status", resp.StatusCode()),
			zap.String("body", string(resp.Body())),
		)
		return fmt.Errorf("API returned status %d: %s", resp.StatusCode(), resp.Status())
	}

	if result != nil {
		if err := json.Unmarshal(resp.Body(), result); err != nil {
			c.logger.Error("Failed to unmarshal response",
				zap.String("url", url),
				zap.Error(err),
			)
			return fmt.Errorf("failed to unmarshal response: %w", err)
		}
	}

	return nil
}

// GetLeague fetches league information
func (c *SleeperClient) GetLeague(ctx context.Context, leagueID string) (*League, error) {
	var league League
	endpoint := fmt.Sprintf("/league/%s", leagueID)
	err := c.doRequest(ctx, http.MethodGet, endpoint, &league)
	return &league, err
}

// GetUsers fetches all users in a league
func (c *SleeperClient) GetUsers(ctx context.Context, leagueID string) ([]User, error) {
	var users []User
	endpoint := fmt.Sprintf("/league/%s/users", leagueID)
	err := c.doRequest(ctx, http.MethodGet, endpoint, &users)
	return users, err
}

// GetRosters fetches all rosters in a league
func (c *SleeperClient) GetRosters(ctx context.Context, leagueID string) ([]Roster, error) {
	var rosters []Roster
	endpoint := fmt.Sprintf("/league/%s/rosters", leagueID)
	err := c.doRequest(ctx, http.MethodGet, endpoint, &rosters)
	return rosters, err
}

// GetMatchups fetches matchups for a specific week
func (c *SleeperClient) GetMatchups(ctx context.Context, leagueID string, week int) ([]Matchup, error) {
	var matchups []Matchup
	endpoint := fmt.Sprintf("/league/%s/matchups/%d", leagueID, week)
	err := c.doRequest(ctx, http.MethodGet, endpoint, &matchups)
	return matchups, err
}

// GetTransactions fetches transactions for a specific week
func (c *SleeperClient) GetTransactions(ctx context.Context, leagueID string, week int) ([]Transaction, error) {
	var transactions []Transaction
	endpoint := fmt.Sprintf("/league/%s/transactions/%d", leagueID, week)
	err := c.doRequest(ctx, http.MethodGet, endpoint, &transactions)
	return transactions, err
}

// GetPlayers fetches all NFL players
func (c *SleeperClient) GetPlayers(ctx context.Context) (map[string]Player, error) {
	var players map[string]Player
	endpoint := "/players/nfl"
	err := c.doRequest(ctx, http.MethodGet, endpoint, &players)
	return players, err
}

// GetNFLState fetches current NFL state (week, season, etc.)
func (c *SleeperClient) GetNFLState(ctx context.Context) (*NFLState, error) {
	var state NFLState
	endpoint := "/state/nfl"
	err := c.doRequest(ctx, http.MethodGet, endpoint, &state)
	return &state, err
}

// GetDraftPicks fetches draft picks for a league
func (c *SleeperClient) GetDraftPicks(ctx context.Context, draftID string) ([]DraftPick, error) {
	var picks []DraftPick
	endpoint := fmt.Sprintf("/draft/%s/picks", draftID)
	err := c.doRequest(ctx, http.MethodGet, endpoint, &picks)
	return picks, err
}

// GetTradedPicks fetches traded draft picks for a league
func (c *SleeperClient) GetTradedPicks(ctx context.Context, leagueID string) ([]TradedPick, error) {
	var picks []TradedPick
	endpoint := fmt.Sprintf("/league/%s/traded_picks", leagueID)
	err := c.doRequest(ctx, http.MethodGet, endpoint, &picks)
	return picks, err
}