package repositories

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/mrab54/sleeper-db/sync-service/internal/api"
	"github.com/mrab54/sleeper-db/sync-service/internal/database"
	"go.uber.org/zap"
)

// UserRepository handles user-related database operations
type UserRepository struct {
	db     *database.DB
	logger *zap.Logger
}

// NewUserRepository creates a new user repository
func NewUserRepository(db *database.DB, logger *zap.Logger) *UserRepository {
	return &UserRepository{
		db:     db,
		logger: logger,
	}
}

// UpsertUser inserts or updates a user
func (r *UserRepository) UpsertUser(ctx context.Context, user *api.User) error {
	query := `
		INSERT INTO sleeper.users (
			user_id, username, display_name, avatar, is_bot, metadata
		) VALUES (
			$1, $2, $3, $4, $5, $6
		)
		ON CONFLICT (user_id) DO UPDATE SET
			username = EXCLUDED.username,
			display_name = EXCLUDED.display_name,
			avatar = EXCLUDED.avatar,
			is_bot = EXCLUDED.is_bot,
			metadata = EXCLUDED.metadata,
			updated_at = CURRENT_TIMESTAMP
	`

	_, err := r.db.Exec(ctx, query,
		user.UserID,
		user.Username, // Will be *string, handles nil properly
		user.DisplayName,
		user.Avatar,
		user.IsBot,
		user.Metadata,
	)

	if err != nil {
		r.logger.Error("Failed to upsert user",
			zap.String("user_id", user.UserID),
			zap.Error(err),
		)
		return fmt.Errorf("failed to upsert user: %w", err)
	}

	return nil
}

// UpsertMinimalUser inserts or updates a user with minimal information
func (r *UserRepository) UpsertMinimalUser(ctx context.Context, userID string, displayName string) error {
	query := `
		INSERT INTO sleeper.users (
			user_id, username, display_name, is_bot, metadata
		) VALUES (
			$1, NULL, $2, false, '{}'::jsonb
		)
		ON CONFLICT (user_id) DO NOTHING
	`

	_, err := r.db.Exec(ctx, query, userID, displayName)
	if err != nil {
		r.logger.Error("Failed to upsert minimal user",
			zap.String("user_id", userID),
			zap.Error(err),
		)
		return fmt.Errorf("failed to upsert minimal user: %w", err)
	}

	return nil
}

// GetUser retrieves a user by ID
func (r *UserRepository) GetUser(ctx context.Context, userID string) (*api.User, error) {
	query := `
		SELECT user_id, username, display_name, avatar, is_bot, metadata
		FROM sleeper.users
		WHERE user_id = $1
	`

	var user api.User
	err := r.db.QueryRow(ctx, query, userID).Scan(
		&user.UserID,
		&user.Username,
		&user.DisplayName,
		&user.Avatar,
		&user.IsBot,
		&user.Metadata,
	)

	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get user: %w", err)
	}

	return &user, nil
}

// GetUsersByLeague retrieves all users in a league
func (r *UserRepository) GetUsersByLeague(ctx context.Context, leagueID string) ([]*api.User, error) {
	query := `
		SELECT DISTINCT u.user_id, u.username, u.display_name, u.avatar, u.is_bot, u.metadata
		FROM sleeper.users u
		JOIN sleeper.rosters r ON u.user_id = r.owner_id
		WHERE r.league_id = $1
		ORDER BY u.username
	`

	rows, err := r.db.Query(ctx, query, leagueID)
	if err != nil {
		return nil, fmt.Errorf("failed to query users: %w", err)
	}
	defer rows.Close()

	var users []*api.User
	for rows.Next() {
		var user api.User
		err := rows.Scan(
			&user.UserID,
			&user.Username,
			&user.DisplayName,
			&user.Avatar,
			&user.IsBot,
			&user.Metadata,
		)

		if err != nil {
			return nil, fmt.Errorf("failed to scan user: %w", err)
		}

		users = append(users, &user)
	}

	return users, nil
}