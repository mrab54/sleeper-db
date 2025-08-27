package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	port := "8080"
	if len(os.Args) > 1 {
		port = os.Args[1]
	}

	// Create file server for current directory
	fs := http.FileServer(http.Dir("."))
	
	// Wrap with CORS middleware
	handler := corsMiddleware(fs)
	
	fmt.Printf("🚀 Swagger documentation server running!\n")
	fmt.Printf("📄 View the API docs at: http://localhost:%s/sleeper-api-swagger.html\n", port)
	fmt.Printf("🛑 Press Ctrl+C to stop the server\n\n")
	
	// Handle graceful shutdown
	go func() {
		sigint := make(chan os.Signal, 1)
		signal.Notify(sigint, os.Interrupt, syscall.SIGTERM)
		<-sigint
		fmt.Println("\n✅ Server stopped")
		os.Exit(0)
	}()
	
	// Start server
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatal("❌ Error starting server: ", err)
	}
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Set CORS headers
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "*")
		
		// Handle preflight requests
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		
		// Serve the file
		next.ServeHTTP(w, r)
	})
}