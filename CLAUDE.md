# Sleeper Fantasy Football Data Project

## Project Overview

This project provides a normalized PostgreSQL database and GraphQL API for Sleeper fantasy football league data. It fetches data from the Sleeper API and stores it in a structured format, making it easy to query and analyze fantasy football statistics, transactions, and league history.

**Core Functionality:**
- Fetch and store Sleeper fantasy football league data from API
- Provide GraphQL API via Hasura for querying data

**Technology Stack:**
- PostgreSQL 17 (primary data store)
- Hasura GraphQL Engine (API layer)
- Go programming language for all backend services and scripts
- Docker & Docker Compose (containerization)
- Sleeper API v1 (data source)

## Architecture & Structure

### Directory Organization
```
sleeper-db/
├── database/          # Database schemas and migrations
│   └── init/         # SQL initialization scripts
├── docs/             # Documentation and API specs
│   └── sleeper-api-swagger.yaml  # Sleeper API documentation
├── hasura/           # Hasura metadata and configurations
└── docker-compose files for different environments
```

### Key Design Decisions
- **Single Database**: Using one PostgreSQL instance with proper schema organization
- **GraphQL First**: All data access through Hasura's auto-generated GraphQL API
- **Normalized Schema**: Properly normalized relational database design
- **Docker-Based**: Everything runs in containers for consistency

## Coding Standards

### Database
- **Naming**: Use snake_case for all database objects
- **Primary Keys**: Use natural keys where possible (e.g., league_id, user_id from Sleeper)
- **Foreign Keys**: Always define relationships with proper constraints
- **Indexes**: Create indexes on foreign keys and commonly queried fields
- **Timestamps**: Include created_at and updated_at on all tables

### SQL Style
- Use uppercase for SQL keywords
- One constraint per line in CREATE TABLE statements
- Meaningful table and column names
- Add comments for complex logic

## Project-Specific Context

### Important Constraints
- Sleeper API is read-only (no writes)
- No authentication required for API access
- Rate limit: 1000 requests per minute
- Player data endpoint returns large response (~5MB)

## Development Guidelines

### Data Fetching Strategy
- Fetch conservatively - Sleeper has no official rate limits but be respectful

### Error Handling
- API failures should not crash the system
- Log all errors with context
- Implement retry logic with exponential backoff
- Handle missing/null data gracefully

### Performance Considerations
- Use database indexes effectively

## Current Focus

### Active Development Areas
- Setting up initial database schema
- Establishing Hasura GraphQL API
- Planning data synchronization strategy

### Known Issues
- No data synchronization implemented yet
- Schema design needs validation against actual API responses
- Need to determine optimal update frequency

### Areas to Avoid Modifying
- Don't add complex business logic to the database
- Keep Hasura configuration minimal - use its defaults where possible

## Future Considerations

### Potential Enhancements

### Technical Debt
- Need proper testing strategy
- Monitoring and alerting not configured
- No backup strategy defined yet
- There will be no python in this entire project.
- do not ever try to do a recursive directory delete "rm -rf" NEVER or I will cut off your nuts