# Sleeper API Documentation Viewer

This directory contains the Sleeper API documentation in OpenAPI/Swagger format and tools to view it.

## Files

- `sleeper-api-swagger.yaml` - OpenAPI specification for the Sleeper API
- `sleeper-api-swagger.html` - HTML viewer for the Swagger documentation
- `serve.go` - Go HTTP server to serve the documentation

## Viewing the Documentation

### Option 1: Using Go directly
```bash
cd docs
go run serve.go
# Open http://localhost:8080/sleeper-api-swagger.html
```

### Option 2: Using Make
```bash
cd docs
make serve
# Open http://localhost:8080/sleeper-api-swagger.html
```

### Option 3: Using Docker
```bash
cd docs
docker build -t sleeper-docs .
docker run -p 8080:8080 sleeper-docs
# Open http://localhost:8080/sleeper-api-swagger.html
```

### Option 4: Using Docker Compose (from project root)
```bash
docker-compose up docs
# Open http://localhost:8080/sleeper-api-swagger.html
```

## Custom Port

To run on a different port:
```bash
go run serve.go 3000
# Open http://localhost:3000/sleeper-api-swagger.html
```

## Note

The documentation must be served through an HTTP server (not opened directly as a file) due to browser security restrictions (CORS).