package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

// HealthResponse is the response structure for health check
type HealthResponse struct {
	Status    string    `json:"status"`
	Service   string    `json:"service"`
	Version   string    `json:"version"`
	Timestamp time.Time `json:"timestamp"`
	Uptime    string    `json:"uptime"`
}

// ActionRequest represents the standard Hasura Action request format
type ActionRequest struct {
	Action struct {
		Name string `json:"name"`
	} `json:"action"`
	Input           json.RawMessage        `json:"input"`
	SessionVars     map[string]string      `json:"session_variables"`
	RequestQuery    string                 `json:"request_query"`
}

// ActionHealthResponse is the response for the Hasura Action health check
type ActionHealthResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Service string `json:"service"`
	Version string `json:"version"`
}

var (
	startTime = time.Now()
	version   = "1.0.0"
)

func main() {
	// Get port from environment or default to 8080
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// Create Chi router
	r := chi.NewRouter()

	// Middleware
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.RealIP)
	r.Use(middleware.RequestID)

	// Regular health check endpoint (for Docker health checks, etc.)
	r.Get("/health", regularHealthHandler)

	// Hasura Action health check endpoint
	r.Post("/actions-health", hasuraActionHealthHandler)

	// Start server
	log.Printf("Starting actions service on port %s", port)
	if err := http.ListenAndServe(":"+port, r); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

// regularHealthHandler handles regular health check requests
func regularHealthHandler(w http.ResponseWriter, r *http.Request) {
	response := HealthResponse{
		Status:    "healthy",
		Service:   "sleeper-actions",
		Version:   version,
		Timestamp: time.Now(),
		Uptime:    time.Since(startTime).String(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// hasuraActionHealthHandler handles Hasura Action health check requests
func hasuraActionHealthHandler(w http.ResponseWriter, r *http.Request) {
	// Parse the Hasura action request
	var actionReq ActionRequest
	if err := json.NewDecoder(r.Body).Decode(&actionReq); err != nil {
		// Even if parsing fails, return a valid response for Hasura
		log.Printf("Error parsing action request: %v", err)
	}

	// Log the action name if provided
	if actionReq.Action.Name != "" {
		log.Printf("Handling action: %s", actionReq.Action.Name)
	}

	// Check for action secret (if configured)
	actionSecret := os.Getenv("ACTION_SECRET")
	if actionSecret != "" {
		headerSecret := r.Header.Get("X-Action-Secret")
		if headerSecret != actionSecret {
			log.Printf("Invalid action secret")
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			json.NewEncoder(w).Encode(map[string]interface{}{
				"message": "Unauthorized",
			})
			return
		}
	}

	// Return success response
	response := ActionHealthResponse{
		Success: true,
		Message: "Actions service is healthy",
		Service: "sleeper-actions",
		Version: version,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}