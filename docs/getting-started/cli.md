# Vulcan CLI

Vulcan includes a command-line interface for managing deployments, built with Go and the [Charm](https://charm.sh/) stack.

## Quick Start

```bash
# Run from project root
./bin/vulcan --help

# Or add to PATH
export PATH="$PATH:$(pwd)/bin"
vulcan --help
```

## Service Management

| Command | Description |
|---------|-------------|
| `vulcan start` | Start services (auto-detects dev/prod) |
| `vulcan start -d` | Start in background (daemon mode) |
| `vulcan stop` | Stop running services |
| `vulcan status` | Show status of all services |
| `vulcan logs` | View service logs |
| `vulcan logs -f` | Follow logs in real-time |
| `vulcan test` | Run the test suite |

## Docker Builds

| Command | Description |
|---------|-------------|
| `vulcan build` | Build production Docker image |
| `vulcan build --info` | Show build configuration |
| `vulcan build --target dev` | Build development image |
| `vulcan build --push` | Build and push to registry |
| `vulcan build -p linux/amd64,linux/arm64 --push` | Multi-arch build |
| `vulcan build --registry ghcr.io/myorg` | Use custom registry |
| `vulcan build --version v2.3.0` | Build with specific version tag |

The build command reads versions from `.ruby-version` and `.nvmrc` files for single source of truth.

## Setup & Configuration

| Command | Description |
|---------|-------------|
| `vulcan setup` | Interactive setup wizard |
| `vulcan setup dev` | Setup development environment |
| `vulcan setup production` | Setup production environment |
| `vulcan setup --dry-run` | Preview setup without executing |
| `vulcan config show` | Display current configuration |
| `vulcan config edit` | Edit configuration interactively |
| `vulcan config rotate` | Rotate secret keys |
| `vulcan config validate` | Validate configuration |

## Database Management

| Command | Description |
|---------|-------------|
| `vulcan db migrate` | Run pending migrations |
| `vulcan db rollback` | Rollback last migration |
| `vulcan db rollback -s 3` | Rollback 3 migrations |
| `vulcan db seed` | Seed the database |
| `vulcan db reset` | Reset database (drop, create, migrate, seed) |
| `vulcan db create` | Create the database |
| `vulcan db drop` | Drop the database |
| `vulcan db status` | Show migration status |
| `vulcan db console` | Open database console (psql) |

## Database Backup & Restore

| Command | Description |
|---------|-------------|
| `vulcan db backup` | Create timestamped backup |
| `vulcan db backup -o backup.sql` | Backup to specific file |
| `vulcan db backup -o -` | Stream backup to stdout |
| `vulcan db restore backup.sql` | Restore from file |
| `vulcan db restore -f -` | Restore from stdin |

## Database Snapshots

Quick local snapshots for development workflows:

| Command | Description |
|---------|-------------|
| `vulcan db snapshot` | Create auto-named snapshot |
| `vulcan db snapshot before-migration` | Create named snapshot |
| `vulcan db snapshot --list` | List all snapshots |
| `vulcan db snapshot --restore latest` | Restore most recent snapshot |
| `vulcan db snapshot --restore before-migration` | Restore by name |

Snapshots are stored in `.vulcan/snapshots/` within the project directory.

## User Management

| Command | Description |
|---------|-------------|
| `vulcan user list` | List all users |
| `vulcan user create-admin` | Create an admin user |
| `vulcan user reset-password` | Reset a user's password |
| `vulcan user confirm` | Confirm a user's email |

## Authentication Configuration

| Command | Description |
|---------|-------------|
| `vulcan auth status` | Show authentication status |
| `vulcan auth setup-oidc` | Configure OIDC provider |
| `vulcan auth setup-ldap` | Configure LDAP |
| `vulcan auth test` | Test authentication settings |
| `vulcan auth disable` | Disable external auth |

## Example Workflows

### Development Workflow

```bash
# Initial setup
vulcan setup dev

# Start services
vulcan start

# Make database changes
vulcan db snapshot before-changes
vulcan db migrate

# If something goes wrong
vulcan db snapshot --restore before-changes

# Run tests
vulcan test
```

### Production Deployment

```bash
# Setup production environment
vulcan setup production

# Configure authentication
vulcan auth setup-oidc

# Start in daemon mode
vulcan start -d

# Monitor logs
vulcan logs -f

# Create backup before maintenance
vulcan db backup -o pre-maintenance.sql
```

### Backup Pipeline

```bash
# Stream backup through compression
vulcan db backup -o - | gzip > backup-$(date +%Y%m%d).sql.gz

# Restore from compressed backup
gunzip -c backup-20241201.sql.gz | vulcan db restore -f -
```

## Configuration

The CLI loads configuration from multiple sources (lowest to highest priority):

1. Built-in defaults
2. `.ruby-version` and `.nvmrc` files (for version info)
3. `vulcan.yaml` (or `.json`, `.toml`) in project root
4. `.env` file
5. Environment variables (`VULCAN_*` prefix)
6. Command-line flags

### Configuration Files

| File | Purpose |
|------|---------|
| `.env` | Environment configuration |
| `.ruby-version` | Ruby version (read by CLI) |
| `.nvmrc` | Node.js version (read by CLI) |
| `.vulcan/snapshots/` | Local database snapshots |
| `docker-compose.yml` | Production Docker config |
| `docker-compose.dev.yml` | Development Docker config |

## Environment Detection

The CLI automatically detects whether you're in a development or production environment:

- **Development**: Uses `bundle exec rails` commands, connects to local Docker PostgreSQL
- **Production**: Uses Docker Compose exec, connects to production database container

Detection is based on:
1. Presence of `/.dockerenv` (running inside Docker)
2. `BUNDLE_PATH` environment variable
3. `RAILS_ENV=production` in `.env` file

## Building from Source

```bash
cd cli
go build -o ../bin/vulcan .
```

Requirements: Go 1.21+

## Security

- All backup and snapshot files are created with `0600` permissions
- Snapshot directories are created with `0700` permissions
- Secret rotation uses cryptographically secure random generation
- Passwords are validated for strength before acceptance
