package repositories

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// RawRepository handles storing raw API responses
type RawRepository struct {
	db *pgxpool.Pool
}

// NewRawRepository creates a new raw repository
func NewRawRepository(db *pgxpool.Pool) *RawRepository {
	return &RawRepository{db: db}
}

// APIResponse represents a raw API response
type APIResponse struct {
	ID                int64                  `json:"id"`
	Endpoint          string                 `json:"endpoint"`
	EndpointType      string                 `json:"endpoint_type"`
	RequestMethod     string                 `json:"request_method"`
	RequestParams     map[string]interface{} `json:"request_params"`
	RequestHeaders    map[string]interface{} `json:"request_headers"`
	ResponseStatus    int                    `json:"response_status"`
	ResponseHeaders   map[string]interface{} `json:"response_headers"`
	ResponseTimeMs    int                    `json:"response_time_ms"`
	ResponseBody      json.RawMessage        `json:"response_body"`
	ResponseHash      string                 `json:"response_hash"`
	ResponseSizeBytes int                    `json:"response_size_bytes"`
	ProcessingStatus  string                 `json:"processing_status"`
	ProcessedAt       *time.Time             `json:"processed_at"`
	ProcessingNotes   string                 `json:"processing_notes"`
	FetchedAt         time.Time              `json:"fetched_at"`
	CreatedAt         time.Time              `json:"created_at"`
}

// SyncRun represents a sync operation
type SyncRun struct {
	ID            int64     `json:"id"`
	RunType       string    `json:"run_type"`
	Status        string    `json:"status"`
	StartedAt     time.Time `json:"started_at"`
	CompletedAt   *time.Time `json:"completed_at"`
	TotalEndpoints int      `json:"total_endpoints"`
	SuccessCount  int       `json:"success_count"`
	ErrorCount    int       `json:"error_count"`
	SkippedCount  int       `json:"skipped_count"`
	ErrorDetails  json.RawMessage `json:"error_details"`
	Metadata      json.RawMessage `json:"metadata"`
}

// SyncEndpoint represents an individual endpoint sync within a run
type SyncEndpoint struct {
	ID              int64      `json:"id"`
	SyncRunID       int64      `json:"sync_run_id"`
	Endpoint        string     `json:"endpoint"`
	Status          string     `json:"status"`
	ResponseStatus  int        `json:"response_status"`
	ResponseTimeMs  int        `json:"response_time_ms"`
	ResponseSize    int        `json:"response_size"`
	ErrorMessage    string     `json:"error_message"`
	APIResponseID   *int64     `json:"api_response_id"`
	ProcessedAt     time.Time  `json:"processed_at"`
}

// calculateHash computes SHA256 hash of response body
func calculateHash(data []byte) string {
	hash := sha256.Sum256(data)
	return hex.EncodeToString(hash[:])
}

// StoreAPIResponse stores a raw API response
func (r *RawRepository) StoreAPIResponse(ctx context.Context, endpoint, endpointType string, responseBody json.RawMessage, status int, responseTimeMs int) (*APIResponse, error) {
	hash := calculateHash(responseBody)
	sizeBytes := len(responseBody)

	// Check if we already have this exact response
	var existingID int64
	checkQuery := `
		SELECT id FROM raw.api_responses 
		WHERE endpoint = $1 AND response_hash = $2
		ORDER BY fetched_at DESC
		LIMIT 1
	`
	err := r.db.QueryRow(ctx, checkQuery, endpoint, hash).Scan(&existingID)
	if err == nil {
		// We already have this exact response, skip storing
		return &APIResponse{ID: existingID}, nil
	}

	query := `
		INSERT INTO raw.api_responses (
			endpoint, endpoint_type, response_status, response_time_ms,
			response_body, response_hash, response_size_bytes
		) VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, fetched_at, created_at
	`
	
	var response APIResponse
	err = r.db.QueryRow(ctx, query,
		endpoint, endpointType, status, responseTimeMs,
		responseBody, hash, sizeBytes,
	).Scan(&response.ID, &response.FetchedAt, &response.CreatedAt)
	
	if err != nil {
		return nil, fmt.Errorf("failed to store API response: %w", err)
	}

	response.Endpoint = endpoint
	response.EndpointType = endpointType
	response.ResponseStatus = status
	response.ResponseTimeMs = responseTimeMs
	response.ResponseBody = responseBody
	response.ResponseHash = hash
	response.ResponseSizeBytes = sizeBytes
	response.ProcessingStatus = "new"

	return &response, nil
}

// CreateSyncRun creates a new sync run record
func (r *RawRepository) CreateSyncRun(ctx context.Context, runType string, metadata json.RawMessage) (*SyncRun, error) {
	query := `
		INSERT INTO raw.sync_runs (run_type, status, metadata)
		VALUES ($1, 'running', $2)
		RETURNING id, run_type, status, started_at
	`
	
	var run SyncRun
	err := r.db.QueryRow(ctx, query, runType, metadata).Scan(
		&run.ID, &run.RunType, &run.Status, &run.StartedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create sync run: %w", err)
	}

	run.Metadata = metadata
	return &run, nil
}

// UpdateSyncRun updates a sync run with completion status
func (r *RawRepository) UpdateSyncRun(ctx context.Context, runID int64, status string, successCount, errorCount, skippedCount int, errorDetails json.RawMessage) error {
	now := time.Now()
	query := `
		UPDATE raw.sync_runs SET
			status = $2,
			completed_at = $3,
			total_endpoints = $4,
			success_count = $5,
			error_count = $6,
			skipped_count = $7,
			error_details = $8
		WHERE id = $1
	`
	
	totalEndpoints := successCount + errorCount + skippedCount
	_, err := r.db.Exec(ctx, query,
		runID, status, now, totalEndpoints,
		successCount, errorCount, skippedCount, errorDetails,
	)
	
	if err != nil {
		return fmt.Errorf("failed to update sync run: %w", err)
	}
	
	return nil
}

// RecordEndpointSync records the sync of an individual endpoint
func (r *RawRepository) RecordEndpointSync(ctx context.Context, syncRunID int64, endpoint string, status string, responseStatus, responseTimeMs, responseSize int, errorMessage string, apiResponseID *int64) error {
	query := `
		INSERT INTO raw.sync_endpoints (
			sync_run_id, endpoint, status, response_status,
			response_time_ms, response_size, error_message, api_response_id
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`
	
	_, err := r.db.Exec(ctx, query,
		syncRunID, endpoint, status, responseStatus,
		responseTimeMs, responseSize, errorMessage, apiResponseID,
	)
	
	if err != nil {
		return fmt.Errorf("failed to record endpoint sync: %w", err)
	}
	
	return nil
}

// StoreLeagueResponse stores a league API response
func (r *RawRepository) StoreLeagueResponse(ctx context.Context, leagueID string, responseBody json.RawMessage, fetchedAt time.Time) error {
	hash := calculateHash(responseBody)
	
	query := `
		INSERT INTO raw.leagues (league_id, data, data_hash, fetched_at)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (league_id) DO UPDATE SET
			data = EXCLUDED.data,
			data_hash = EXCLUDED.data_hash,
			fetched_at = EXCLUDED.fetched_at,
			updated_at = NOW()
		WHERE raw.leagues.data_hash != EXCLUDED.data_hash
	`
	
	_, err := r.db.Exec(ctx, query, leagueID, responseBody, hash, fetchedAt)
	if err != nil {
		return fmt.Errorf("failed to store league response: %w", err)
	}
	
	return nil
}

// StoreRostersResponse stores rosters API response for a league
func (r *RawRepository) StoreRostersResponse(ctx context.Context, leagueID string, responseBody json.RawMessage, fetchedAt time.Time) error {
	hash := calculateHash(responseBody)
	
	query := `
		INSERT INTO raw.rosters (league_id, data, data_hash, fetched_at)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (league_id) DO UPDATE SET
			data = EXCLUDED.data,
			data_hash = EXCLUDED.data_hash,
			fetched_at = EXCLUDED.fetched_at,
			updated_at = NOW()
		WHERE raw.rosters.data_hash != EXCLUDED.data_hash
	`
	
	_, err := r.db.Exec(ctx, query, leagueID, responseBody, hash, fetchedAt)
	if err != nil {
		return fmt.Errorf("failed to store rosters response: %w", err)
	}
	
	return nil
}

// StoreUsersResponse stores users API response for a league
func (r *RawRepository) StoreUsersResponse(ctx context.Context, leagueID string, responseBody json.RawMessage, fetchedAt time.Time) error {
	// For users, we store each user individually
	var users []map[string]interface{}
	if err := json.Unmarshal(responseBody, &users); err != nil {
		return fmt.Errorf("failed to unmarshal users response: %w", err)
	}
	
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)
	
	for _, user := range users {
		userID, ok := user["user_id"].(string)
		if !ok {
			continue
		}
		
		userData, err := json.Marshal(user)
		if err != nil {
			continue
		}
		
		hash := calculateHash(userData)
		
		query := `
			INSERT INTO raw.users (user_id, data, data_hash, fetched_at)
			VALUES ($1, $2, $3, $4)
			ON CONFLICT (user_id) DO UPDATE SET
				data = EXCLUDED.data,
				data_hash = EXCLUDED.data_hash,
				fetched_at = EXCLUDED.fetched_at,
				updated_at = NOW()
			WHERE raw.users.data_hash != EXCLUDED.data_hash
		`
		
		if _, err := tx.Exec(ctx, query, userID, userData, hash, fetchedAt); err != nil {
			return fmt.Errorf("failed to store user %s: %w", userID, err)
		}
	}
	
	return tx.Commit(ctx)
}

// StoreMatchupsResponse stores matchups API response for a league and week
func (r *RawRepository) StoreMatchupsResponse(ctx context.Context, leagueID string, week int, responseBody json.RawMessage, fetchedAt time.Time) error {
	hash := calculateHash(responseBody)
	
	query := `
		INSERT INTO raw.matchups (league_id, week, data, data_hash, fetched_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (league_id, week) DO UPDATE SET
			data = EXCLUDED.data,
			data_hash = EXCLUDED.data_hash,
			fetched_at = EXCLUDED.fetched_at,
			updated_at = NOW()
		WHERE raw.matchups.data_hash != EXCLUDED.data_hash
	`
	
	_, err := r.db.Exec(ctx, query, leagueID, week, responseBody, hash, fetchedAt)
	if err != nil {
		return fmt.Errorf("failed to store matchups response: %w", err)
	}
	
	return nil
}

// StoreTransactionsResponse stores transactions API response for a league and week
func (r *RawRepository) StoreTransactionsResponse(ctx context.Context, leagueID string, week int, responseBody json.RawMessage, fetchedAt time.Time) error {
	hash := calculateHash(responseBody)
	
	query := `
		INSERT INTO raw.transactions (league_id, week, data, data_hash, fetched_at)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (league_id, week) DO UPDATE SET
			data = EXCLUDED.data,
			data_hash = EXCLUDED.data_hash,
			fetched_at = EXCLUDED.fetched_at,
			updated_at = NOW()
		WHERE raw.transactions.data_hash != EXCLUDED.data_hash
	`
	
	_, err := r.db.Exec(ctx, query, leagueID, week, responseBody, hash, fetchedAt)
	if err != nil {
		return fmt.Errorf("failed to store transactions response: %w", err)
	}
	
	return nil
}

// StorePlayersResponse stores the full NFL players database
func (r *RawRepository) StorePlayersResponse(ctx context.Context, responseBody json.RawMessage, fetchedAt time.Time) error {
	hash := calculateHash(responseBody)
	
	// Check if data has changed
	var existingHash string
	checkQuery := `SELECT data_hash FROM raw.players ORDER BY fetched_at DESC LIMIT 1`
	err := r.db.QueryRow(ctx, checkQuery).Scan(&existingHash)
	
	if err == nil && existingHash == hash {
		// Data hasn't changed, skip storing
		return nil
	}
	
	query := `
		INSERT INTO raw.players (data, data_hash, fetched_at)
		VALUES ($1, $2, $3)
	`
	
	_, err = r.db.Exec(ctx, query, responseBody, hash, fetchedAt)
	if err != nil {
		return fmt.Errorf("failed to store players response: %w", err)
	}
	
	return nil
}

// GetUnprocessedResponses retrieves unprocessed API responses
func (r *RawRepository) GetUnprocessedResponses(ctx context.Context, limit int) ([]*APIResponse, error) {
	query := `
		SELECT id, endpoint, endpoint_type, response_body, response_hash, 
		       fetched_at, created_at
		FROM raw.api_responses
		WHERE processing_status = 'new'
		ORDER BY fetched_at ASC
		LIMIT $1
	`
	
	rows, err := r.db.Query(ctx, query, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get unprocessed responses: %w", err)
	}
	defer rows.Close()
	
	var responses []*APIResponse
	for rows.Next() {
		var r APIResponse
		err := rows.Scan(
			&r.ID, &r.Endpoint, &r.EndpointType, &r.ResponseBody,
			&r.ResponseHash, &r.FetchedAt, &r.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan response: %w", err)
		}
		r.ProcessingStatus = "new"
		responses = append(responses, &r)
	}
	
	return responses, nil
}

// MarkResponseProcessed marks an API response as processed
func (r *RawRepository) MarkResponseProcessed(ctx context.Context, responseID int64, status string, notes string) error {
	query := `
		UPDATE raw.api_responses
		SET processing_status = $2,
		    processed_at = NOW(),
		    processing_notes = $3
		WHERE id = $1
	`
	
	_, err := r.db.Exec(ctx, query, responseID, status, notes)
	if err != nil {
		return fmt.Errorf("failed to mark response as processed: %w", err)
	}
	
	return nil
}

// BeginTx starts a new transaction
func (r *RawRepository) BeginTx(ctx context.Context) (pgx.Tx, error) {
	return r.db.Begin(ctx)
}