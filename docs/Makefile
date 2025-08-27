.PHONY: serve build run clean

# Default target
serve: run

# Build the server
build:
	go build -o docs-server serve.go

# Run the server directly
run:
	go run serve.go

# Run on a different port
run-alt:
	go run serve.go 3000

# Clean build artifacts
clean:
	rm -f docs-server

# Install as a tool
install:
	go install serve.go