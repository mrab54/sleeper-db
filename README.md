# Sleeper Fantasy Football Database

A high-performance, normalized PostgreSQL database for Sleeper Fantasy Football data with Hasura GraphQL API and automated data synchronization.

## Features

- 🚀 **High-Performance Go Sync Service** - Intelligent data synchronization with change detection
- 📊 **Normalized PostgreSQL Database** - 32 properly structured tables
- 🔄 **GraphQL API via Hasura** - Instant GraphQL queries and subscriptions
- 🐳 **Docker-based Deployment** - Easy setup with Docker Compose
- ⏰ **Scheduled Syncing** - Automated daily full sync and 5-minute incremental updates
- 🔒 **Idempotent Operations** - Safe retries and concurrent syncs
- 📈 **Prometheus Metrics** - Built-in monitoring support

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Make

### Setup

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/sleeper-db.git
cd sleeper-db
```

2. **Configure environment** (optional)
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. **Start all services**
```bash
make up       # Start PostgreSQL, Hasura, Sync Service, and Docs
```

4. **Access the services**
- Hasura Console: http://localhost:8080/console
- API Documentation: http://localhost:8081
- Sync Service Webhooks: http://localhost:8082
- Metrics: http://localhost:9090/metrics
- PostgreSQL: localhost:5432

5. **Initialize with data** (first time only)
```bash
# Sync a specific user's leagues
docker exec sleeper-sync /app/sleeper-sync sync user <username_or_user_id>

# Or trigger a full sync
docker exec sleeper-sync /app/sleeper-sync sync all
```

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌──────────────────────┐
│  Sleeper API    │◀────│  Sync Service   │────▶│     PostgreSQL       │
└─────────────────┘     │      (Go)       │     │    (sleeper_db)      │
                        └─────────────────┘     └──────────────────────┘
                                ▲                         │
                                │                         ▼
                        ┌───────────────┐       ┌─────────────────┐
                        │ Hasura Cron   │       │     Hasura      │
                        │   Scheduler   │       │   (GraphQL)     │
                        └───────────────┘       └─────────────────┘
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| PostgreSQL | 5432 | Main database (sleeper schema) |
| Hasura | 8080 | GraphQL API & Console |
| Docs | 8081 | API Documentation (Swagger) |
| Sync Service | 8082 | Data synchronization webhooks |
| Metrics | 9090 | Prometheus metrics endpoint |

## Development

### Available Commands

```bash
make help           # Show all available commands
make up             # Start all services
make down           # Stop all services
make clean          # Stop services and remove volumes
make logs           # Show all logs
make logs-db        # Show database logs
make logs-hasura    # Show Hasura logs
make ps             # Show running containers
make db-console     # Open PostgreSQL console
make hasura-console # Open Hasura console in browser
make rebuild        # Clean rebuild everything
```

### Project Structure

```
sleeper-db/
├── init/              # Database initialization SQL scripts
├── docs/              # API documentation and Swagger
├── hasura/            # Hasura metadata and cron triggers
├── sleeper-sync/      # Go sync service
│   ├── cmd/           # CLI commands
│   ├── internal/      # Business logic
│   │   ├── api/       # Sleeper API client
│   │   ├── database/  # Database operations
│   │   ├── sync/      # Sync orchestration
│   │   └── webhook/   # Webhook handlers
│   └── config.yaml    # Sync service configuration
├── docker-compose.yml # Main Docker configuration
├── .env.example       # Environment variables template
└── Makefile          # Development commands
```

## API Examples

### GraphQL Query (via Hasura)

```graphql
query GetLeagueStandings($league_id: String!) {
  rosters(
    where: {league_id: {_eq: $league_id}}
    order_by: {wins: desc, points_for: desc}
  ) {
    roster_id
    owner {
      display_name
    }
    wins
    losses
    points_for
  }
}
```

### Access Hasura Console

```bash
make hasura-console
# Or navigate to: http://localhost:8080/console
# Admin Secret: check your .env file (HASURA_ADMIN_SECRET)
```

## Access Points

- **Hasura Console**: http://localhost:8080/console
- **GraphQL Endpoint**: http://localhost:8080/v1/graphql
- **API Documentation**: http://localhost:8081

## Database Schema

The database contains 32+ normalized tables in the `sleeper` schema, including:
- Users and leagues
- Rosters and players
- Transactions and trades
- Matchups and scoring
- Drafts and picks
- And more...

## Documentation

- [Project Overview](CLAUDE.md)
- [Implementation Plan](PLAN.md)
- [Database Schema](database/schema/schema-v1.sql)
- [API Analysis](docs/research/api-analysis.md)
- [Go Tech Stack](docs/research/go-tech-stack-decisions.md)

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Acknowledgments

- [Sleeper API](https://docs.sleeper.com) for providing the fantasy football data
- [Hasura](https://hasura.io) for the instant GraphQL API
- [Go](https://golang.org) for the amazing performance

---

Built with ❤️ for the fantasy football community