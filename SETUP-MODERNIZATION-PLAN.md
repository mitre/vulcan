# Vulcan Setup & Startup Modernization - Complete Plan

**Created:** 2025-11-16
**Branch:** v2.3.0
**Status:** Planning Complete, Ready for Implementation

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Problem Statement](#problem-statement)
3. [Research & Standards](#research--standards)
4. [Architecture Design](#architecture-design)
5. [Implementation Plan](#implementation-plan)
6. [Testing Strategy](#testing-strategy)
7. [Task Checklist](#task-checklist)
8. [Migration & Rollout](#migration--rollout)

---

## Executive Summary

**Goal:** Modernize Vulcan's startup and setup processes to follow Rails 8 best practices, eliminate manual scripts, and provide a seamless "it just works" experience for developers, CI/CD, Docker deployments, and Helm chart integration.

**Key Changes:**
- Replace `setup-docker-secrets.sh` with intelligent `bin/setup`
- Enhance `bin/dev` for automatic database management
- Support both interactive (developer) and non-interactive (CI/CD) modes
- Integrate with Helm chart via `bin/helm-setup`
- Follow Rails 8 and Foreman community standards
- Add reset/cleanup functionality

**Expected Outcomes:**
- ✅ Single command setup: `bin/setup`
- ✅ Single command daily dev: `bin/dev`
- ✅ CI/CD ready with `--non-interactive` flag
- ✅ Helm chart testing integrated
- ✅ Beautiful UX with tty-toolkit
- ✅ Eliminates 14+ documentation references to manual scripts

---

## Problem Statement

### Current Issues

1. **Too Many Setup Methods:**
   - Manual `setup-docker-secrets.sh` script
   - Separate database startup: `docker-compose -f docker-compose.dev.yml up -d`
   - Separate app startup: `foreman start -f Procfile.dev`
   - Current `bin/dev` only runs `rails server` (ignores JS builds!)
   - Different processes for dev/test/production

2. **Poor Developer Experience:**
   - 3-4 manual steps to start development
   - No guidance on which method to use when
   - Confusion between local development vs Docker deployment
   - Manual secret generation required

3. **CI/CD Friction:**
   - GitHub Actions manually duplicate setup logic
   - No reusable setup command
   - Database setup repeated in multiple workflow files

4. **Docker Complexity:**
   - Users must choose between building locally or pulling images
   - No integration with Helm chart for testing
   - Manual docker-compose.yml creation

5. **Missing Features:**
   - No reset/cleanup command
   - No test-only setup path
   - Test environment not clearly documented

### Current File Structure

```
vulcan-clean/
├── Procfile                      # Production (Heroku/Docker)
├── Procfile.dev                  # Development processes
├── setup-docker-secrets.sh       # Manual secret generation (TO BE REMOVED)
├── docker-compose.dev.yml        # Dev database
├── docker-compose.yml            # Full Docker setup (optional)
├── Dockerfile                    # Simple production build
├── Dockerfile.production         # Optimized multi-stage build
├── bin/
│   ├── dev                      # Current: just runs rails server (BROKEN)
│   ├── setup                    # Current: basic Rails setup
│   └── ... (other bin scripts)
├── .env.example                 # Development template
├── .env.production.example      # Production template
└── docs/
    └── deployment/
        └── ... (14+ references to setup-docker-secrets.sh)
```

---

## Research & Standards

### Rails 8 Community Standards

**Sources:**
- [railsnotes.xyz - Procfile.dev Guide](https://railsnotes.xyz/blog/procfile-bin-dev-rails7) (Updated 2025)
- [procfile.dev](https://procfile.dev/) - Community documentation
- [Matt Brickson - Better bin/dev](https://mattbrictson.com/blog/better-bin-dev-script)
- [rails/rails GitHub](https://github.com/rails/rails) - Official templates

**Key Findings:**

1. **Procfile Naming Convention:**
   - `Procfile` (no extension) = Production standard (Heroku/Docker/K8s)
   - `Procfile.dev` = De facto community standard for development
   - **No official Foreman naming standard**, only `-f` flag convention

2. **bin/dev Standard:**
   - Rails 8 simplified to `exec "./bin/rails", "server", *ARGV`
   - Community extends with Foreman/Overmind for multi-process management
   - Can include database auto-start (best practice per Matt Brickson)

3. **bin/setup Standard:**
   - Idempotent setup script
   - Should handle all first-time setup
   - Rails 8 template: bundle, db:prepare, cleanup
   - Community extends with interactive prompts (tty-toolkit)

### Foreman Documentation

**Source:** [ddollar.github.io/foreman](https://ddollar.github.io/foreman/)

**Key Findings:**
- Procfile format: `<process type>: <command>`
- Process types are alphanumeric names (web, worker, js, etc.)
- Use `-f` flag for alternate Procfiles
- No built-in environment-specific file support
- Community adopted `.dev` suffix convention

### Test Environment in Rails

**Source:** Rails guides, current codebase analysis

**Key Findings:**
- `ENV['RAILS_ENV'] ||= 'test'` in `spec/rails_helper.rb` (line 6)
- `ActiveRecord::Migration.maintain_test_schema!` auto-manages test DB
- Test database configured in `database.yml` (separate from development)
- RSpec works automatically with test environment
- **No special setup needed** - just ensure test DB exists

**Current Test Setup (Working):**
```ruby
# spec/rails_helper.rb line 6
ENV['RAILS_ENV'] ||= 'test'

# Lines 48-53
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end
```

### TTY-Toolkit Research

**Source:** [ttytoolkit.org](https://ttytoolkit.org/)

**Key Findings:**
- Industry standard for Ruby CLI tools
- `tty-prompt` - Beautiful interactive prompts
- `tty-spinner` - Progress indicators
- Graceful fallback when not available
- Non-interactive mode via environment detection

**Benefits:**
- Professional UX comparable to modern CLI tools
- Multi-select, confirmations, menus
- Better than `gets.chomp` or `ARGV` parsing
- Widely adopted in Ruby community

### CI/CD Patterns

**Current Implementation:** `.github/workflows/release.yml`

**Analysis:**
```yaml
# Lines 115-127 - Manual database setup
- name: Setup database
  env:
    RAILS_ENV: test
    DATABASE_URL: postgresql://postgres:postgres@localhost:5432/vulcan_vue_test
  run: |
    bundle exec rails db:create
    bundle exec rails db:migrate
```

**Problems:**
- Duplicated setup logic across workflows
- No reusability
- Manual steps repeated in run-tests.yml

**Solution:**
- Single `bin/setup --non-interactive --mode test` command
- Auto-detects CI environment via `ENV['CI']`
- Respects GitHub Actions service containers

### Docker Workflows

**Current Implementation:** `.github/workflows/push-to-docker.yml`

**Analysis:**
```yaml
# Lines 34-41 - Docker build
- name: Build and push
  uses: docker/build-push-action@v6
  with:
    context: .
    push: true
    tags: mitre/vulcan:${{ env.TAG }}
    platforms: linux/amd64,linux/arm64
```

**Integration Points:**
- Uses `Dockerfile.production` (not specified, should be explicit)
- Multi-platform builds (amd64 + arm64)
- Pushed to Docker Hub as `mitre/vulcan:TAG`

### Helm Chart Integration

**Related Project:** `vulcan-helm` (coordinated v0.3.0 release)

**Requirements:**
- Test local builds before pushing
- Validate health check endpoints work
- Support pulling official releases
- Easy developer testing workflow

---

## Architecture Design

### High-Level Flow

```
┌─────────────────────────────────────────────────────────┐
│                   Entry Points                          │
├─────────────────────────────────────────────────────────┤
│  bin/setup      │  bin/dev      │  bin/helm-setup       │
│  (first-time)   │  (daily use)  │  (helm testing)       │
└────────┬────────┴───────┬───────┴──────────┬────────────┘
         │                │                   │
    ┌────▼─────┐    ┌────▼─────┐       ┌────▼─────┐
    │Interactive│    │Auto-start│       │ Helm     │
    │   Mode    │    │ Database │       │Integration│
    └────┬─────┘    └────┬─────┘       └────┬─────┘
         │                │                   │
    ┌────▼──────────┬────▼─────┬──────────┬──▼────┐
    │               │          │          │       │
  Local Dev   Docker Build  Docker Pull  Prod  Test
```

### Setup Modes Matrix

| Mode | Interactive | Non-Interactive | Use Case |
|------|-------------|-----------------|----------|
| **Local Dev** | ✅ Full wizard | `--mode local` | Daily development from source |
| **Docker Build** | ✅ Build options | `--mode docker_build --docker-tag TAG` | Test containerization locally |
| **Docker Pull** | ✅ Version choice | `--mode docker_pull --docker-tag TAG` | Quick evaluation, demos |
| **Production** | ✅ Auth config | `--mode production` | Deploy to servers/cloud |
| **Test** | ❌ Auto-only | `--mode test` | CI/CD, RSpec setup |

### File Structure Changes

**New Files:**
```
bin/
├── setup              # Enhanced with dual-mode support
├── dev                # Enhanced with auto-database
└── helm-setup         # NEW - Helm chart integration

.setup-markers/        # NEW - Track setup state
├── .local-dev
├── .docker-build
└── .docker-pull
```

**Modified Files:**
```
bin/setup              # Complete rewrite
bin/dev                # Enhanced for auto-start
Gemfile                # Add tty-prompt, tty-spinner
```

**Removed Files:**
```
setup-docker-secrets.sh  # DEPRECATED (keep for one release with warning)
```

**Documentation Updates:**
```
README.md                                    # Remove setup-docker-secrets.sh
docs/deployment/docker.md                    # Update with bin/setup
docs/deployment/kubernetes.md                # Update references
docs/getting-started/installation.md         # New setup instructions
docs/getting-started/quick-start.md          # Simplify to bin/setup
docs/getting-started/environment-variables.md # Update .env generation
```

### Command-Line Interface Design

#### bin/setup

**Interactive Mode (default):**
```bash
bin/setup

# Output:
🚀 Vulcan Setup Wizard
============================================================
? How would you like to run Vulcan?
  ❯ Local Development (from source)
    Docker Container (build locally)
    Docker Container (pull from registry)
    Production Deployment
    Test Environment Only
```

**Non-Interactive Mode (Auto-Detected):**
```bash
# Auto-detected via isatty (POSIX standard)
CI=true bin/setup                  # CI environment detected

# Any flags = non-interactive
bin/setup --mode local             # Has flags, non-interactive

# Piped or redirected = non-interactive
bin/setup < answers.txt            # Piped stdin
bin/setup > log.txt                # Redirected stdout

# With options (automatically non-interactive)
bin/setup --mode docker_build \
  --docker-tag v2.3.0-test \
  --skip-yarn
```

**Reset Mode:**
```bash
# Interactive with confirmation
bin/setup --reset

# Non-interactive (requires --force)
bin/setup --reset --force

# Selective reset
bin/setup --reset --keep-env  # Keep .env file
```

**Available Flags:**
- `--mode MODE` - Setup mode: local, docker_build, docker_pull, production, test
- `--docker-tag TAG` - Docker image tag
- `--env ENV` - Environment: development, test, production
- `--skip-db` - Skip database setup
- `--skip-seed` - Skip database seeding
- `--skip-yarn` - Skip yarn install
- `--reset` - Clean up and start fresh
- `--force` - Skip confirmations (dangerous!)
- `--keep-env` - Preserve .env during reset
- `-h, --help` - Show help

**Note:** Interactive mode is automatically detected via POSIX `isatty()`. Presence of any flags (except `--help`) automatically enables non-interactive mode. No explicit `--non-interactive` flag needed.

#### bin/dev

**Enhanced with Auto-Start:**
```bash
bin/dev

# Output:
🐘 Starting PostgreSQL... ✅
🚀 Starting Vulcan development server...

web | Puma starting in development on http://0.0.0.0:3000
js  | esbuild watching for changes...
```

**Smart Detection:**
- Detects if Docker database is running
- Auto-starts if needed
- Waits for health check
- Falls back gracefully if Docker unavailable

#### bin/helm-setup

**New Helper Script:**
```bash
# Quick test with latest
bin/helm-setup pull-and-test

# Test local build
bin/helm-setup build-and-test --image-tag v2.3.0-test

# Install with custom values
bin/helm-setup install --values custom.yaml

# Cleanup
bin/helm-setup clean
```

**Available Commands:**
- `install` - Install/upgrade via Helm
- `test` - Run Helm tests
- `build-and-test` - Build local image and test
- `pull-and-test` - Pull registry image and test
- `clean` - Uninstall and cleanup

### Environment Detection Logic (POSIX Standard)

Following POSIX/GNU best practices, interactive mode is auto-detected without requiring explicit flags:

```ruby
# POSIX standard: Use isatty() to detect terminal
# Interactive if ALL conditions are true:
# 1. stdin is a terminal (not piped)
# 2. stdout is a terminal (not redirected)
# 3. Not in CI environment
# 4. No flags provided (or only --help)

ci_environment = ENV['CI'] ||
                 ENV['GITHUB_ACTIONS'] ||
                 ENV['GITLAB_CI'] ||
                 ENV['CIRCLECI'] ||
                 ENV['JENKINS_HOME']

has_flags = ARGV.any? { |arg| arg.start_with?('--') && arg != '--help' }

interactive = $stdin.tty? &&      # POSIX isatty check
              $stdout.tty? &&     # POSIX isatty check
              !ci_environment &&  # Not in CI
              !has_flags          # No flags provided

# This matches behavior of: git, apt, yum, and other GNU/POSIX tools
```

**Examples:**
- `bin/setup` → Interactive (tty detected, no flags)
- `bin/setup --mode local` → Non-interactive (flags present)
- `bin/setup > log.txt` → Non-interactive (stdout redirected)
- `CI=true bin/setup` → Non-interactive (CI environment)
- `echo "input" | bin/setup` → Non-interactive (stdin piped)

### Reset Functionality Design

**Safety First:**
1. Always confirm in interactive mode
2. Require `--force` in non-interactive mode
3. Show what will be deleted before proceeding
4. Offer `--keep-env` to preserve secrets

**What Gets Reset:**
```bash
# Files removed
.env (unless --keep-env)
docker-compose.yml
.setup-markers/*

# Docker cleanup
docker-compose down -v  # Removes volumes
docker images prune     # Optional, with prompt

# Database cleanup
DROP DATABASE (with confirmation)

# Build artifacts
tmp/
log/
node_modules/ (optional, with prompt)
```

**Reset Workflow:**
```ruby
def reset_setup(options)
  items_to_remove = []

  # Collect items
  items_to_remove << ".env" unless options[:keep_env]
  items_to_remove << "docker-compose.yml" if File.exist?("docker-compose.yml")
  items_to_remove << ".setup-markers" if Dir.exist?(".setup-markers")

  # Database volumes
  if system("docker ps -a | grep -q vulcan")
    items_to_remove << "Docker containers and volumes"
  end

  # Show plan
  puts "🧹 The following will be removed:"
  items_to_remove.each { |item| puts "  - #{item}" }
  puts ""

  # Confirm
  unless options[:force]
    prompt = TTY::Prompt.new
    return unless prompt.yes?("Are you sure you want to reset?", default: false)

    if items_to_remove.include?(".env") && !options[:keep_env]
      puts "⚠️  WARNING: This will delete your .env file including secrets!"
      return unless prompt.yes?("Continue?", default: false)
    end
  end

  # Execute cleanup
  cleanup_items(items_to_remove, options)

  puts "✅ Reset complete. Run 'bin/setup' to start fresh."
end
```

---

## Implementation Plan

### Phase 1: Preparation (Complete)

**Tasks:**
- [x] Research Rails 8 standards
- [x] Research Foreman best practices
- [x] Analyze current GitHub Actions workflows
- [x] Design dual-mode architecture
- [x] Design reset functionality
- [x] Create implementation plan

### Phase 2: Core Implementation

#### 2.1: Update Gemfile

**File:** `Gemfile`

```ruby
group :development do
  gem 'foreman'
  gem 'tty-prompt'  # Interactive prompts
  gem 'tty-spinner' # Progress indicators
end
```

**Tasks:**
- [ ] Add tty-prompt gem
- [ ] Add tty-spinner gem
- [ ] Run `bundle install`
- [ ] Verify gems load correctly

#### 2.2: Implement Enhanced bin/setup

**File:** `bin/setup`

**Features:**
- Interactive mode with tty-toolkit
- Non-interactive mode for CI/CD
- Auto-detection of CI environment
- All setup modes (local, docker_build, docker_pull, production, test)
- Reset functionality with safety checks
- Comprehensive flag support

**Tasks:**
- [ ] Implement option parsing with OptionParser
- [ ] Implement environment detection logic
- [ ] Implement interactive mode dispatcher
- [ ] Implement non-interactive mode dispatcher
- [ ] Implement setup_local_development (interactive)
- [ ] Implement setup_local_non_interactive
- [ ] Implement setup_docker_build (interactive)
- [ ] Implement setup_docker_build_non_interactive
- [ ] Implement setup_docker_pull (interactive)
- [ ] Implement setup_docker_pull_non_interactive
- [ ] Implement setup_production (interactive)
- [ ] Implement setup_production_non_interactive
- [ ] Implement setup_test (auto-only)
- [ ] Implement reset_setup with safety checks
- [ ] Implement helper functions (create_docker_compose, etc.)
- [ ] Add progress spinners for long operations
- [ ] Add error handling and rollback
- [ ] Make script executable: `chmod +x bin/setup`

#### 2.3: Implement Enhanced bin/dev

**File:** `bin/dev`

**Features:**
- Auto-detect and start Docker database
- Health check waiting
- Smart mode detection (prevent use in Docker setup modes)
- Foreman integration with Procfile.dev

**Tasks:**
- [ ] Implement database detection logic
- [ ] Implement auto-start with health check
- [ ] Implement mode detection (check marker files)
- [ ] Implement Foreman startup
- [ ] Add helpful error messages
- [ ] Make script executable: `chmod +x bin/dev`

#### 2.4: Create bin/helm-setup

**File:** `bin/helm-setup` (NEW)

**Features:**
- Install/upgrade Vulcan via Helm
- Build local image and test
- Pull registry image and test
- Run Helm tests
- Cleanup

**Tasks:**
- [ ] Create bin/helm-setup script
- [ ] Implement install command
- [ ] Implement test command
- [ ] Implement build-and-test command
- [ ] Implement pull-and-test command
- [ ] Implement clean command
- [ ] Add kind cluster detection
- [ ] Add kind image loading for local builds
- [ ] Make script executable: `chmod +x bin/helm-setup`

#### 2.5: Update Procfile.dev

**File:** `Procfile.dev`

**Tasks:**
- [ ] Review current processes (web, js)
- [ ] Add optional prometheus process (commented)
- [ ] Document process purposes
- [ ] Test with foreman

#### 2.6: Deprecate setup-docker-secrets.sh

**File:** `setup-docker-secrets.sh`

**Tasks:**
- [ ] Add deprecation warning at top of script
- [ ] Redirect users to `bin/setup`
- [ ] Keep file for one release cycle
- [ ] Document removal in CHANGELOG

### Phase 3: Documentation Updates

#### 3.1: Update Core Documentation

**Files:**
- `README.md`
- `docs/getting-started/quick-start.md`
- `docs/getting-started/installation.md`
- `docs/getting-started/environment-variables.md`

**Tasks:**
- [ ] Remove all setup-docker-secrets.sh references
- [ ] Add bin/setup documentation
- [ ] Add bin/dev documentation
- [ ] Add bin/helm-setup documentation
- [ ] Update quick start to single command
- [ ] Add troubleshooting section
- [ ] Add reset/cleanup instructions

#### 3.2: Update Deployment Documentation

**Files:**
- `docs/deployment/docker.md`
- `docs/deployment/kubernetes.md`
- `docs/deployment/monitoring.md`

**Tasks:**
- [ ] Update Docker deployment with bin/setup
- [ ] Add Docker build vs pull guidance
- [ ] Update Kubernetes deployment
- [ ] Add Helm chart integration docs
- [ ] Update monitoring setup

#### 3.3: Create New Documentation

**New Files:**
- `docs/development/setup-modes.md`
- `docs/development/troubleshooting-setup.md`

**Tasks:**
- [ ] Document all setup modes
- [ ] Create flag reference
- [ ] Add troubleshooting guide
- [ ] Add examples for common scenarios

### Phase 4: GitHub Actions Integration

#### 4.1: Update release.yml

**File:** `.github/workflows/release.yml`

**Tasks:**
- [ ] Replace manual db:create/migrate with bin/setup
- [ ] Add `--non-interactive --mode test` flags
- [ ] Test workflow runs successfully
- [ ] Verify time savings

#### 4.2: Update run-tests.yml

**File:** `.github/workflows/run-tests.yml`

**Tasks:**
- [ ] Replace manual setup with bin/setup
- [ ] Add `--skip-yarn` flag (already in cache)
- [ ] Test workflow runs successfully

#### 4.3: Update push-to-docker.yml

**File:** `.github/workflows/push-to-docker.yml`

**Tasks:**
- [ ] Explicitly set `file: Dockerfile.production`
- [ ] Document why using production Dockerfile
- [ ] Test multi-platform builds still work

---

## Testing Strategy

### Test Scenarios Matrix

| # | Scenario | Command | Expected Outcome | Status |
|---|----------|---------|------------------|--------|
| **Interactive Mode (Auto-Detected via isatty)** |
| 1 | First-time local dev setup | `bin/setup` | Interactive wizard, creates .env, starts DB, prepares DBs | ⏳ |
| 2 | Docker build interactive | `bin/setup` | Interactive wizard, prompts for options, builds image | ⏳ |
| 3 | Docker pull interactive | `bin/setup` | Interactive wizard, prompts for version, pulls image | ⏳ |
| 4 | Production setup | `bin/setup` | Interactive wizard, generates .env with secrets | ⏳ |
| 5 | Help is interactive | `bin/setup --help` | Shows help with nice formatting (interactive allowed) | ⏳ |
| **Non-Interactive Mode (Auto-Detected via isatty + flags)** |
| 6 | CI auto-detection | `CI=true bin/setup` | Runs in non-interactive mode, uses defaults | ⏳ |
| 7 | Flags trigger non-interactive | `bin/setup --mode local` | Sets up local dev without prompts | ⏳ |
| 8 | Test mode for CI | `bin/setup --mode test` | Creates test DB only, no prompts | ⏳ |
| 9 | Docker build non-interactive | `bin/setup --mode docker_build --docker-tag test` | Builds image without prompts | ⏳ |
| 10 | Docker pull non-interactive | `bin/setup --mode docker_pull --docker-tag latest` | Pulls image without prompts | ⏳ |
| 11 | Production non-interactive | `bin/setup --mode production` | Generates .env with secrets, no prompts | ⏳ |
| 12 | Piped stdin | `echo "" \| bin/setup` | Non-interactive (stdin not tty) | ⏳ |
| 13 | Redirected stdout | `bin/setup > log.txt` | Non-interactive (stdout not tty) | ⏳ |
| **Reset Functionality** |
| 14 | Reset interactive | `bin/setup --reset` | Non-interactive (has flags), requires --force | ⏳ |
| 15 | Reset with force | `bin/setup --reset --force` | Cleans up without confirmation | ⏳ |
| 16 | Reset keep env | `bin/setup --reset --force --keep-env` | Cleans up but preserves .env | ⏳ |
| **bin/dev** |
| 15 | First run (no DB) | `bin/dev` | Auto-starts DB, waits for health, starts processes | ⏳ |
| 16 | Daily run (DB running) | `bin/dev` | Detects running DB, starts processes | ⏳ |
| 17 | Docker pull mode detection | `bin/dev` (after docker pull setup) | Shows error, suggests docker-compose up | ⏳ |
| 18 | Docker build mode detection | `bin/dev` (after docker build setup) | Shows error, suggests docker-compose up | ⏳ |
| **bin/helm-setup** |
| 19 | Helm install | `bin/helm-setup install` | Installs via Helm chart | ⏳ |
| 20 | Helm build and test | `bin/helm-setup build-and-test --image-tag test` | Builds, loads to kind, installs, tests | ⏳ |
| 21 | Helm pull and test | `bin/helm-setup pull-and-test` | Pulls latest, installs, tests | ⏳ |
| 22 | Helm cleanup | `bin/helm-setup clean` | Uninstalls and cleans namespace | ⏳ |
| **GitHub Actions** |
| 23 | Release workflow | Trigger release workflow | Uses bin/setup, tests pass | ⏳ |
| 24 | Run tests workflow | Push to master | Uses bin/setup, tests pass | ⏳ |
| 25 | Docker push workflow | After test success | Builds and pushes correctly | ⏳ |
| **Edge Cases** |
| 26 | .env already exists | `bin/setup` (local mode) | Skips .env creation, continues | ⏳ |
| 27 | Database already running | `bin/setup` (local mode) | Detects running DB, continues | ⏳ |
| 28 | No Docker installed | `bin/dev` | Graceful error message | ⏳ |
| 29 | No Helm installed | `bin/helm-setup install` | Graceful error message | ⏳ |
| 30 | Interrupted setup | Ctrl-C during bin/setup | Cleans up gracefully | ⏳ |
| **Compatibility** |
| 31 | macOS (Intel) | All scenarios | Works correctly | ⏳ |
| 32 | macOS (Apple Silicon) | All scenarios | Works correctly | ⏳ |
| 33 | Linux (Ubuntu) | All scenarios | Works correctly | ⏳ |
| 34 | GitHub Actions (ubuntu-24.04) | CI scenarios | Works correctly | ⏳ |

### Testing Checklist by Phase

**Phase 1: Local Development**
- [ ] Test bin/setup interactive mode (local dev)
- [ ] Test bin/setup non-interactive mode (local dev)
- [ ] Test bin/dev auto-start database
- [ ] Test bin/dev with running database
- [ ] Test reset functionality
- [ ] Test with .env already existing
- [ ] Test with database already running

**Phase 2: Docker Workflows**
- [ ] Test bin/setup docker build (interactive)
- [ ] Test bin/setup docker build (non-interactive)
- [ ] Test bin/setup docker pull (interactive)
- [ ] Test bin/setup docker pull (non-interactive)
- [ ] Test generated docker-compose.yml works
- [ ] Test bin/dev rejects Docker modes

**Phase 3: CI/CD**
- [ ] Test CI auto-detection
- [ ] Test GitHub Actions with bin/setup
- [ ] Test release workflow end-to-end
- [ ] Test run-tests workflow
- [ ] Verify time improvements

**Phase 4: Helm Integration**
- [ ] Test bin/helm-setup install
- [ ] Test bin/helm-setup build-and-test
- [ ] Test bin/helm-setup pull-and-test
- [ ] Test kind cluster integration
- [ ] Test bin/helm-setup clean

**Phase 5: Production**
- [ ] Test production .env generation
- [ ] Test secret strength (randomness)
- [ ] Test file permissions (0600)
- [ ] Verify no secrets in git
- [ ] Test production deployment

---

## Task Checklist

### Prerequisites
- [x] Create SETUP-MODERNIZATION-PLAN.md
- [ ] Review plan with team
- [ ] Create feature branch: `feature/setup-modernization`
- [ ] Update memcord with plan

### Implementation Tasks

#### Gemfile & Dependencies
- [ ] Add tty-prompt to Gemfile (development group)
- [ ] Add tty-spinner to Gemfile (development group)
- [ ] Run bundle install
- [ ] Verify gems load: `bundle exec ruby -e "require 'tty-prompt'; puts 'OK'"`
- [ ] Test tty-prompt basic functionality
- [ ] Test tty-spinner basic functionality

#### bin/setup Implementation
- [ ] Backup current bin/setup to bin/setup.old
- [ ] Create new bin/setup with option parsing
- [ ] Implement environment detection logic
- [ ] Implement interactive mode dispatcher
- [ ] Implement non-interactive mode dispatcher
- [ ] Implement setup_local_development (interactive)
- [ ] Implement setup_local_non_interactive
- [ ] Implement setup_docker_build (interactive)
- [ ] Implement setup_docker_build_non_interactive
- [ ] Implement setup_docker_pull (interactive)
- [ ] Implement setup_docker_pull_non_interactive
- [ ] Implement setup_production (interactive)
- [ ] Implement setup_production_non_interactive
- [ ] Implement setup_test_environment
- [ ] Implement reset_setup with confirmations
- [ ] Implement helper: create_docker_compose_for_built_image
- [ ] Implement helper: create_docker_compose_for_pulled_image
- [ ] Implement helper: generate_docker_env
- [ ] Add progress spinners for long operations
- [ ] Add error handling for all operations
- [ ] Add --help flag with usage documentation
- [ ] Make executable: chmod +x bin/setup
- [ ] Test all interactive modes
- [ ] Test all non-interactive modes
- [ ] Test reset functionality
- [ ] Test CI auto-detection

#### bin/dev Implementation
- [ ] Backup current bin/dev to bin/dev.old
- [ ] Create new bin/dev with database detection
- [ ] Implement check_database function
- [ ] Implement auto-start database with health check
- [ ] Implement mode detection (marker files)
- [ ] Implement foreman startup with Procfile.dev
- [ ] Add error messages for Docker modes
- [ ] Add .env existence check
- [ ] Make executable: chmod +x bin/dev
- [ ] Test first-time run (no database)
- [ ] Test with running database
- [ ] Test Docker mode detection
- [ ] Test .env missing scenario

#### bin/helm-setup Implementation
- [ ] Create bin/helm-setup script
- [ ] Implement usage function with examples
- [ ] Implement option parsing
- [ ] Implement install command
- [ ] Implement test command
- [ ] Implement build-and-test command
- [ ] Implement pull-and-test command
- [ ] Implement clean command
- [ ] Add kind cluster detection
- [ ] Add kind image loading for local builds
- [ ] Make executable: chmod +x bin/helm-setup
- [ ] Test install command
- [ ] Test build-and-test workflow
- [ ] Test pull-and-test workflow
- [ ] Test clean command
- [ ] Test with kind cluster
- [ ] Test without kind (should work)

#### Procfile.dev Updates
- [ ] Review current Procfile.dev
- [ ] Add prometheus process (commented)
- [ ] Add process descriptions as comments
- [ ] Test with foreman start -f Procfile.dev
- [ ] Verify web process starts correctly
- [ ] Verify js process watches correctly

#### Marker Files System
- [ ] Create .gitignore entry for .setup-markers/
- [ ] Implement marker file creation in bin/setup
- [ ] Implement marker file detection in bin/dev
- [ ] Test marker file workflow

#### Deprecation
- [ ] Add deprecation warning to setup-docker-secrets.sh
- [ ] Add redirect message to bin/setup
- [ ] Update CHANGELOG.md with deprecation notice
- [ ] Plan removal for next major version

### Documentation Tasks

#### Core Documentation
- [ ] Update README.md - remove setup-docker-secrets.sh
- [ ] Update README.md - add bin/setup quick start
- [ ] Update README.md - add bin/dev usage
- [ ] Update docs/getting-started/quick-start.md
- [ ] Update docs/getting-started/installation.md
- [ ] Update docs/getting-started/environment-variables.md
- [ ] Create docs/development/setup-modes.md
- [ ] Create docs/development/troubleshooting-setup.md

#### Deployment Documentation
- [ ] Update docs/deployment/docker.md
- [ ] Update docs/deployment/kubernetes.md
- [ ] Add bin/helm-setup documentation
- [ ] Update docs/deployment/monitoring.md

#### CLAUDE.md
- [ ] Update CLAUDE.md with new setup commands
- [ ] Remove setup-docker-secrets.sh references
- [ ] Add bin/helm-setup to critical commands

### GitHub Actions Updates
- [ ] Update .github/workflows/release.yml
- [ ] Update .github/workflows/run-tests.yml
- [ ] Verify push-to-docker.yml uses Dockerfile.production
- [ ] Test release workflow
- [ ] Test run-tests workflow
- [ ] Measure time improvements

### Testing Tasks (Comprehensive)
- [ ] Test Scenario 1: First-time local dev (interactive)
- [ ] Test Scenario 2: Docker build (interactive)
- [ ] Test Scenario 3: Docker pull (interactive)
- [ ] Test Scenario 4: Production setup (interactive)
- [ ] Test Scenario 5: Test-only setup
- [ ] Test Scenario 6: Reset with confirmation
- [ ] Test Scenario 7: Reset keep env
- [ ] Test Scenario 8: CI auto-detection
- [ ] Test Scenario 9: Explicit non-interactive
- [ ] Test Scenario 10: Test mode for CI
- [ ] Test Scenario 11: Docker build CI
- [ ] Test Scenario 12: Docker pull CI
- [ ] Test Scenario 13: Production non-interactive
- [ ] Test Scenario 14: Reset with force
- [ ] Test Scenario 15: bin/dev first run
- [ ] Test Scenario 16: bin/dev daily run
- [ ] Test Scenario 17: bin/dev Docker pull mode
- [ ] Test Scenario 18: bin/dev Docker build mode
- [ ] Test Scenario 19: Helm install
- [ ] Test Scenario 20: Helm build and test
- [ ] Test Scenario 21: Helm pull and test
- [ ] Test Scenario 22: Helm cleanup
- [ ] Test Scenario 23: Release workflow
- [ ] Test Scenario 24: Run tests workflow
- [ ] Test Scenario 25: Docker push workflow
- [ ] Test Scenario 26: .env already exists
- [ ] Test Scenario 27: Database already running
- [ ] Test Scenario 28: No Docker installed
- [ ] Test Scenario 29: No Helm installed
- [ ] Test Scenario 30: Interrupted setup
- [ ] Test Scenario 31: macOS Intel
- [ ] Test Scenario 32: macOS Apple Silicon
- [ ] Test Scenario 33: Linux Ubuntu
- [ ] Test Scenario 34: GitHub Actions

### Pre-Commit Checklist
- [ ] All tests passing (bundle exec rspec)
- [ ] RuboCop clean (bundle exec rubocop --autocorrect-all)
- [ ] ESLint clean (yarn lint)
- [ ] Brakeman clean (bundle exec brakeman)
- [ ] No secrets in commits
- [ ] All marker files in .gitignore
- [ ] Documentation complete
- [ ] CHANGELOG.md updated

### Commit and PR Tasks
- [ ] Commit Gemfile changes
- [ ] Commit bin/setup
- [ ] Commit bin/dev
- [ ] Commit bin/helm-setup
- [ ] Commit Procfile.dev updates
- [ ] Commit .gitignore updates
- [ ] Commit setup-docker-secrets.sh deprecation
- [ ] Commit documentation updates
- [ ] Commit GitHub Actions updates
- [ ] Push feature branch
- [ ] Create PR
- [ ] Link PR to issues
- [ ] Request review
- [ ] Address review comments
- [ ] Merge to v2.3.0

### Post-Merge Tasks
- [ ] Test on clean machine
- [ ] Update helm chart documentation
- [ ] Announce in team chat/email
- [ ] Monitor for issues
- [ ] Collect feedback
- [ ] Create follow-up issues if needed

---

## Migration & Rollout

### Backward Compatibility

**During v2.3.0 Release:**
- ✅ Keep `setup-docker-secrets.sh` with deprecation warning
- ✅ Old documentation still works (redirects to new commands)
- ✅ GitHub Actions updated but backward compatible

**Deprecation Warning in setup-docker-secrets.sh:**
```bash
#!/bin/bash
echo "⚠️  DEPRECATION WARNING"
echo ""
echo "This script is deprecated and will be removed in v2.4.0"
echo "Please use the new setup command instead:"
echo ""
echo "  bin/setup"
echo ""
echo "The new command provides:"
echo "  - Interactive setup wizard"
echo "  - CI/CD support"
echo "  - Better error handling"
echo "  - Automatic database management"
echo ""
read -p "Press Enter to continue with legacy script (not recommended)..."
echo ""

# ... rest of old script
```

### Rollout Strategy

**Week 1: Soft Launch**
1. Merge to v2.3.0 branch
2. Internal team testing
3. Documentation preview
4. Collect initial feedback

**Week 2: Beta Testing**
1. Announce in README (beta feature)
2. Add migration guide
3. Monitor GitHub issues
4. Fix critical bugs

**Week 3: Full Release**
1. Release v2.3.0
2. Update all documentation
3. Announce in release notes
4. Deprecate old script

**v2.4.0: Cleanup**
1. Remove setup-docker-secrets.sh
2. Remove old bin/setup.old backup
3. Archive old documentation

### Migration Guide for Users

**For Developers:**
```bash
# Old way (3-4 commands)
./setup-docker-secrets.sh
docker-compose -f docker-compose.dev.yml up -d
foreman start -f Procfile.dev

# New way (1 command first time, 1 daily)
bin/setup  # First time
bin/dev    # Daily
```

**For CI/CD:**
```yaml
# Old way
- run: bundle install
- run: yarn install
- run: bundle exec rails db:create
- run: bundle exec rails db:migrate

# New way (auto-detects CI environment, flags trigger non-interactive)
- run: bin/setup --mode test
```

**For Docker Users:**
```bash
# Old way
docker pull mitre/vulcan:latest
./setup-docker-secrets.sh
# Edit .env manually
docker-compose up

# New way
bin/setup  # Choose "Docker pull"
# Interactive prompts guide you
docker-compose up
```

### Success Metrics

**Developer Experience:**
- [ ] Setup time reduced from 5-10 minutes to 2-3 minutes
- [ ] Commands reduced from 3-4 to 1-2
- [ ] Positive feedback from new developers

**CI/CD:**
- [ ] GitHub Actions runtime improvement
- [ ] Reduced workflow file complexity
- [ ] Fewer CI failures due to setup issues

**Documentation:**
- [ ] setup-docker-secrets.sh references: 14 → 0
- [ ] Quick start: 10 steps → 3 steps
- [ ] Support issues reduced

**Adoption:**
- [ ] 80% of developers using new commands within 2 weeks
- [ ] 0 critical bugs in first month
- [ ] Positive community feedback

---

## Appendix

### Command Reference

#### bin/setup Flags

| Flag | Values | Description | Example |
|------|--------|-------------|---------|
| `--mode` | local, docker_build, docker_pull, production, test | Setup mode (triggers non-interactive) | `--mode local` |
| `--docker-tag` | TAG | Docker image tag | `--docker-tag v2.3.0` |
| `--env` | development, test, production | Environment | `--env test` |
| `--skip-db` | - | Skip database setup | `--skip-db` |
| `--skip-seed` | - | Skip database seeding | `--skip-seed` |
| `--skip-yarn` | - | Skip yarn install | `--skip-yarn` |
| `--reset` | - | Reset and cleanup | `--reset` |
| `--force` | - | Skip confirmations | `--reset --force` |
| `--keep-env` | - | Keep .env during reset | `--reset --keep-env` |
| `-h, --help` | - | Show help | `bin/setup -h` |

#### bin/helm-setup Commands

| Command | Description | Example |
|---------|-------------|---------|
| `install` | Install/upgrade via Helm | `bin/helm-setup install` |
| `test` | Run Helm tests | `bin/helm-setup test` |
| `build-and-test` | Build local + test | `bin/helm-setup build-and-test --image-tag test` |
| `pull-and-test` | Pull registry + test | `bin/helm-setup pull-and-test` |
| `clean` | Uninstall and cleanup | `bin/helm-setup clean` |

### Environment Variables

| Variable | Purpose | Detection |
|----------|---------|-----------|
| `CI` | CI environment detection | `ENV['CI']` |
| `GITHUB_ACTIONS` | GitHub Actions | `ENV['GITHUB_ACTIONS']` |
| `DATABASE_URL` | Database connection | `ENV['DATABASE_URL']` |
| `SETUP_MODE` | Override mode | `SETUP_MODE=test bin/setup` |

### File Marker System

| File | Purpose | Created By |
|------|---------|------------|
| `.setup-markers/.local-dev` | Local dev mode | `bin/setup --mode local` |
| `.setup-markers/.docker-build` | Docker build mode | `bin/setup --mode docker_build` |
| `.setup-markers/.docker-pull` | Docker pull mode | `bin/setup --mode docker_pull` |

### Resources

**Rails 8:**
- [Official Guide](https://guides.rubyonrails.org/)
- [Rails 8 Release Notes](https://rubyonrails.org/2024/11/7/rails-8-0-has-been-released)

**TTY Toolkit:**
- [Official Site](https://ttytoolkit.org/)
- [tty-prompt Documentation](https://github.com/piotrmurach/tty-prompt)
- [tty-spinner Documentation](https://github.com/piotrmurach/tty-spinner)

**Foreman:**
- [Official Documentation](https://ddollar.github.io/foreman/)
- [Procfile Format](https://devcenter.heroku.com/articles/procfile)

**Helm:**
- [Helm Documentation](https://helm.sh/docs/)
- [vulcan-helm Repository](https://github.com/mitre/vulcan-helm)

---

## Document History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-11-16 | 1.0 | Aaron Lippold | Initial comprehensive plan |

---

**Next Steps:**
1. Review this plan
2. Create feature branch
3. Start with Phase 2: Core Implementation
4. Update task checklist as we progress

**DO NOT COMMIT THIS FILE** - Internal documentation only
