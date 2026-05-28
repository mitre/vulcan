# Vulcan Command Runner
# Install just: https://github.com/casey/just#installation
# Usage: just <recipe>

# Default recipe - show available commands
default:
    @just --list

# ============================================================================
# Setup & Installation
# ============================================================================

# Run interactive setup wizard
setup *args:
    @just cli-build
    ./bin/vulcan setup {{args}}

# Quick development setup
setup-dev:
    @just cli-build
    ./bin/vulcan setup dev

# Production setup wizard
setup-prod:
    @just cli-build
    ./bin/vulcan setup production

# Install all dependencies
deps:
    bundle install
    pnpm install

# ============================================================================
# Development
# ============================================================================

# Start development server
dev:
    foreman start -f Procfile.dev

# Start Vulcan (detects environment)
start *args:
    ./bin/vulcan start {{args}}

# Stop all services
stop *args:
    ./bin/vulcan stop {{args}}

# Show service status
status:
    ./bin/vulcan status

# View logs
logs *args:
    ./bin/vulcan logs {{args}}

# Open Rails console
console:
    bin/rails console

# Show routes
routes *args:
    bin/rails routes {{args}}

# ============================================================================
# Testing
# ============================================================================

# Run all tests
test: test-frontend test-backend

# Run frontend tests (Vitest)
test-frontend:
    pnpm vitest run

# Run backend tests (RSpec parallel)
test-backend:
    bundle exec parallel_rspec spec/

# Run frontend tests in watch mode
test-watch:
    pnpm vitest

# ============================================================================
# Linting & Quality
# ============================================================================

# Run all linters
lint: lint-ruby lint-js

# Run RuboCop
lint-ruby:
    bundle exec rubocop --autocorrect-all

# Run ESLint
lint-js:
    pnpm lint

# Run security scans
security:
    bundle exec brakeman
    bundle exec bundler-audit check --update

# ============================================================================
# Database
# ============================================================================

# Run database migrations
db-migrate:
    bin/rails db:migrate

# Seed the database
db-seed:
    bin/rails db:seed

# Reset database (drop, create, migrate, seed)
db-reset:
    bin/rails db:reset

# Open database console
db-console:
    ./bin/vulcan db console

# ============================================================================
# Build
# ============================================================================

# Build all (frontend + CLI)
build: build-frontend cli-build

# Build frontend assets
build-frontend:
    pnpm build

# Build Docker image
build-docker *args:
    ./bin/vulcan build {{args}}

# Build multi-arch Docker images
build-docker-multiarch *args:
    ./bin/vulcan build --platform linux/amd64,linux/arm64 {{args}}

# Build and push to registry
build-docker-push *args:
    ./bin/vulcan build --push {{args}}

# ============================================================================
# CLI
# ============================================================================

# Build the Vulcan CLI
cli-build:
    cd cli && go build -ldflags="-s -w" -o ../bin/vulcan .

# Install CLI globally
cli-install:
    cd cli && go install .

# Run CLI in development mode
cli-dev *args:
    cd cli && go run . {{args}}

# ============================================================================
# Docker
# ============================================================================

# Start production Docker stack
docker-up:
    docker compose up -d

# Stop production Docker stack
docker-down:
    docker compose down

# Start dev database
docker-dev-up:
    docker compose -f docker-compose.dev.yml up -d

# Stop dev database
docker-dev-down:
    docker compose -f docker-compose.dev.yml down

# View Docker logs
docker-logs *args:
    docker compose logs -f {{args}}

# ============================================================================
# Utilities
# ============================================================================

# Clean build artifacts
clean:
    rm -rf bin/vulcan
    rm -rf tmp/cache
    rm -rf node_modules/.cache

# Update all dependencies
update:
    bundle update
    pnpm update
