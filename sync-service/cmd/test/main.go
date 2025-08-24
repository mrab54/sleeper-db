package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/mrab54/sleeper-db/sync-service/internal/api"
	"github.com/mrab54/sleeper-db/sync-service/internal/database"
	"go.uber.org/zap"
)

const (
	leagueID = "1199102384316362752" // Your league ID
	baseURL  = "https://api.sleeper.app/v1"
)

func main() {
	// Create logger
	logger, _ := zap.NewDevelopment()
	defer logger.Sync()

	if len(os.Args) < 2 {
		fmt.Println("Usage: go run main.go [api|db|both]")
		os.Exit(1)
	}

	switch os.Args[1] {
	case "api":
		testAPI(logger)
	case "db":
		testDatabase(logger)
	case "both":
		testAPI(logger)
		testDatabase(logger)
	default:
		fmt.Println("Invalid option. Use: api, db, or both")
	}
}

func testAPI(logger *zap.Logger) {
	fmt.Println("\n=== Testing Sleeper API Client ===")
	
	// Create API client
	client := api.NewSleeperClient(baseURL, logger)
	ctx := context.Background()

	// Test 1: Get NFL State
	fmt.Println("\n1. Getting NFL State...")
	state, err := client.GetNFLState(ctx)
	if err != nil {
		log.Fatalf("Failed to get NFL state: %v", err)
	}
	fmt.Printf("   ✓ NFL Season: %s, Week: %d\n", state.Season, state.Week)

	// Test 2: Get League
	fmt.Println("\n2. Getting League Info...")
	league, err := client.GetLeague(ctx, leagueID)
	if err != nil {
		log.Fatalf("Failed to get league: %v", err)
	}
	fmt.Printf("   ✓ League: %s (Season: %s, Status: %s)\n", league.Name, league.Season, league.Status)

	// Test 3: Get Users
	fmt.Println("\n3. Getting League Users...")
	users, err := client.GetUsers(ctx, leagueID)
	if err != nil {
		log.Fatalf("Failed to get users: %v", err)
	}
	fmt.Printf("   ✓ Found %d users\n", len(users))
	for i, user := range users {
		if i < 3 { // Show first 3 users
			fmt.Printf("     - %s (ID: %s)\n", user.Username, user.UserID)
		}
	}

	// Test 4: Get Rosters
	fmt.Println("\n4. Getting Rosters...")
	rosters, err := client.GetRosters(ctx, leagueID)
	if err != nil {
		log.Fatalf("Failed to get rosters: %v", err)
	}
	fmt.Printf("   ✓ Found %d rosters\n", len(rosters))

	// Test 5: Get Matchups for current week
	fmt.Println("\n5. Getting Matchups...")
	matchups, err := client.GetMatchups(ctx, leagueID, 1) // Week 1
	if err != nil {
		fmt.Printf("   ⚠ Could not get matchups: %v\n", err)
	} else {
		fmt.Printf("   ✓ Found %d matchups for week 1\n", len(matchups))
	}

	// Test 6: Rate limiting
	fmt.Println("\n6. Testing Rate Limiting (5 rapid requests)...")
	start := time.Now()
	for i := 0; i < 5; i++ {
		_, err := client.GetLeague(ctx, leagueID)
		if err != nil {
			fmt.Printf("   ✗ Request %d failed: %v\n", i+1, err)
		} else {
			fmt.Printf("   ✓ Request %d succeeded\n", i+1)
		}
	}
	elapsed := time.Since(start)
	fmt.Printf("   Time taken: %v (rate limiting working if > 500ms)\n", elapsed)

	fmt.Println("\n✅ API Client tests completed successfully!")
}

func testDatabase(logger *zap.Logger) {
	fmt.Println("\n=== Testing Database Connection ===")
	
	// Get database config from environment
	dbConfig := &database.Config{
		Host:            getEnv("DATABASE_HOST", "localhost"),
		Port:            5432,
		User:            getEnv("DATABASE_USER", "sleeper_user"),
		Password:        getEnv("DATABASE_PASSWORD", "sleeper_password"),
		Database:        getEnv("DATABASE_NAME", "sleeper_db"),
		SSLMode:         getEnv("DATABASE_SSL_MODE", "disable"),
		MaxConns:        10,
		MinConns:        2,
		MaxConnLifetime: 1 * time.Hour,
		MaxConnIdleTime: 30 * time.Minute,
	}

	fmt.Printf("\nAttempting to connect to: %s@%s:%d/%s\n", 
		dbConfig.User, dbConfig.Host, dbConfig.Port, dbConfig.Database)

	ctx := context.Background()
	db, err := database.NewDB(ctx, dbConfig, logger)
	if err != nil {
		log.Fatalf("❌ Failed to connect to database: %v", err)
	}
	defer db.Close()

	fmt.Println("✓ Connected to database successfully!")

	// Test a simple query
	var schemaExists bool
	err = db.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'sleeper')").Scan(&schemaExists)
	if err != nil {
		log.Fatalf("Failed to check schema: %v", err)
	}

	if schemaExists {
		fmt.Println("✓ 'sleeper' schema exists")
		
		// Check for tables
		var tableCount int
		err = db.QueryRow(ctx, `
			SELECT COUNT(*) 
			FROM information_schema.tables 
			WHERE table_schema = 'sleeper'
		`).Scan(&tableCount)
		
		if err == nil {
			fmt.Printf("✓ Found %d tables in sleeper schema\n", tableCount)
		}
	} else {
		fmt.Println("⚠ 'sleeper' schema does not exist yet (run db-init)")
	}

	// Check pool stats
	stats := db.Stats()
	fmt.Printf("\nConnection Pool Stats:\n")
	fmt.Printf("  - Total connections: %d\n", stats.TotalConns())
	fmt.Printf("  - Idle connections: %d\n", stats.IdleConns())
	fmt.Printf("  - Max connections: %d\n", stats.MaxConns())

	fmt.Println("\n✅ Database tests completed successfully!")
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// Helper to pretty print JSON
func prettyPrint(v interface{}) {
	b, _ := json.MarshalIndent(v, "", "  ")
	fmt.Println(string(b))
}