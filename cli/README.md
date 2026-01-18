# Vulcan CLI

A command-line interface for managing Vulcan deployments, built with Go and the [Charm](https://charm.sh/) stack.

## Installation

### Pre-built Binary

Download the latest binary from the releases page or use the pre-built binary in the repository:

```bash
# From the Vulcan project root
./bin/vulcan --help
```

### Build from Source

```bash
cd cli
go build -o ../bin/vulcan .
```

## Quick Start

```bash
# Setup a new development environment
vulcan setup dev

# Start Vulcan services
vulcan start

# Check service status
vulcan status

# View logs
vulcan logs
```

## Commands

### Service Management

| Command | Description |
|---------|-------------|
| `vulcan start` | Start Vulcan services (dev or production) |
| `vulcan start -d` | Start in background (daemon mode) |
| `vulcan stop` | Stop running services |
| `vulcan status` | Show status of all services |
| `vulcan logs` | View service logs |
| `vulcan logs -f` | Follow logs in real-time |
| `vulcan test` | Run the test suite |

### Docker Builds

| Command | Description |
|---------|-------------|
| `vulcan build` | Build production Docker image |
| `vulcan build --info` | Show build configuration (versions, tags, etc.) |
| `vulcan build --target dev` | Build development image |
| `vulcan build --push` | Build and push to registry |
| `vulcan build -p linux/amd64,linux/arm64 --push` | Multi-arch build |
| `vulcan build --registry ghcr.io/myorg` | Use custom registry |
| `vulcan build --version v2.3.0` | Build with specific version tag |

The build command reads versions from `.ruby-version` and `.nvmrc` files for single source of truth.

### Setup & Configuration

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

### Database Management

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

### Database Backup & Restore

| Command | Description |
|---------|-------------|
| `vulcan db backup` | Create timestamped backup |
| `vulcan db backup -o backup.sql` | Backup to specific file |
| `vulcan db backup -o -` | Stream backup to stdout |
| `vulcan db restore backup.sql` | Restore from file |
| `vulcan db restore -f -` | Restore from stdin |

### Database Snapshots

Quick local snapshots for development workflows:

| Command | Description |
|---------|-------------|
| `vulcan db snapshot` | Create auto-named snapshot |
| `vulcan db snapshot before-migration` | Create named snapshot |
| `vulcan db snapshot --list` | List all snapshots |
| `vulcan db snapshot --restore latest` | Restore most recent snapshot |
| `vulcan db snapshot --restore before-migration` | Restore by name |

Snapshots are stored in `.vulcan/snapshots/` within the project directory.

### User Management

| Command | Description |
|---------|-------------|
| `vulcan user list` | List all users |
| `vulcan user create-admin` | Create an admin user |
| `vulcan user reset-password` | Reset a user's password |
| `vulcan user confirm` | Confirm a user's email |

### Authentication Configuration

| Command | Description |
|---------|-------------|
| `vulcan auth status` | Show authentication status |
| `vulcan auth setup-oidc` | Configure OIDC provider |
| `vulcan auth setup-ldap` | Configure LDAP |
| `vulcan auth test` | Test authentication settings |
| `vulcan auth disable` | Disable external auth |

## Examples

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

## Environment Detection

The CLI automatically detects whether you're in a development or production environment:

- **Development**: Uses `bundle exec rails` commands, connects to local Docker PostgreSQL
- **Production**: Uses Docker Compose exec, connects to production database container

Detection is based on:
1. Presence of `/.dockerenv` (running inside Docker)
2. `BUNDLE_PATH` environment variable
3. `RAILS_ENV=production` in `.env` file

## Configuration Files

| File | Purpose |
|------|---------|
| `.env` | Environment configuration |
| `.vulcan/snapshots/` | Local database snapshots |
| `docker-compose.yml` | Production Docker config |
| `docker-compose.dev.yml` | Development Docker config |

## Security

- All backup and snapshot files are created with `0600` permissions (owner read/write only)
- Snapshot directories are created with `0700` permissions
- Secret rotation uses cryptographically secure random generation
- Passwords are validated for strength before acceptance

## Development

### Requirements

- Go 1.21+
- [Task](https://taskfile.dev) (optional, recommended)

### Setup

```bash
cd cli

# 1. Install Task runner (choose one for your platform)

# macOS
brew install go-task

# Linux (Debian/Ubuntu)
sudo snap install task --classic
# or: sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

# Windows
choco install go-task
# or: scoop install task

# Any platform with Go installed
go install github.com/go-task/task/v3/cmd/task@latest

# 2. Install all dev tools (linters, security scanners)
task tools:install

# 3. Verify everything is installed
task tools:check
```

### Task Commands

This project uses [Taskfile](https://taskfile.dev) for task automation (similar to npm scripts):

```bash
task              # List all available tasks
task build        # Build the CLI binary
task test         # Run tests
task ci           # Run all CI checks
```

#### Build Tasks

| Command | Description |
|---------|-------------|
| `task build` | Build CLI binary |
| `task build:all` | Build for all platforms (Linux, macOS, Windows) |
| `task run -- --help` | Build and run with arguments |

#### Test Tasks

| Command | Description |
|---------|-------------|
| `task test` | Run all tests |
| `task test:coverage` | Run tests with coverage report |
| `task test:race` | Run tests with race detector |

#### Lint & Format Tasks

| Command | Description |
|---------|-------------|
| `task lint` | Run golangci-lint |
| `task lint:fix` | Run linter with auto-fix |
| `task fmt` | Format code with gofmt |
| `task fmt:check` | Check if code is formatted |
| `task vet` | Run go vet |

#### Security Tasks

| Command | Description |
|---------|-------------|
| `task sec` | Run gosec security scanner |
| `task sec:full` | Full security scan with JSON report |
| `task secrets` | Scan for hardcoded secrets (gitleaks) |
| `task secrets:baseline` | Generate baseline for false positives |
| `task vuln` | Check for known vulnerabilities |
| `task security` | Run all security checks |

#### CI Tasks

| Command | Description |
|---------|-------------|
| `task ci` | Run all CI checks (format, lint, security, test, build) |
| `task ci:quick` | Quick CI (no security scans) |

### Alternative: Make

If you prefer Make over Task:

```bash
make build        # Build binary
make test         # Run tests
make ci           # Run CI checks
make secrets      # Scan for secrets
```

### Manual Build

```bash
# Build for current platform
go build -o ../bin/vulcan .

# Run tests
go test ./... -v

# Cross-compile
GOOS=linux GOARCH=amd64 go build -o ../bin/vulcan-linux-amd64 .
GOOS=darwin GOARCH=arm64 go build -o ../bin/vulcan-darwin-arm64 .
GOOS=windows GOARCH=amd64 go build -o ../bin/vulcan-windows-amd64.exe .
```

## Dependencies

The CLI is built with the [Charm](https://charm.sh/) stack:

- **[Cobra](https://github.com/spf13/cobra)** - CLI framework
- **[Lip Gloss](https://github.com/charmbracelet/lipgloss)** - Terminal styling
- **[Huh](https://github.com/charmbracelet/huh)** - Interactive forms

### Dev Tools

- **[golangci-lint](https://golangci-lint.run/)** - Linter aggregator
- **[gosec](https://github.com/securego/gosec)** - Security scanner
- **[gitleaks](https://github.com/gitleaks/gitleaks)** - Secret detection
- **[govulncheck](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck)** - Vulnerability scanner

## License

Apache 2.0 - See [LICENSE](../LICENSE) for details.
