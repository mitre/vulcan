# Vulcan Procfile & Startup Modernization - Context Recovery

## Problem Statement

**Current Issue:** Vulcan has too many ways to start and configure the application across different environments (dev, test, production). This creates confusion, maintenance overhead, and inconsistency.

**Goal:** Unify and centralize startup processes using modern Rails 8 standards.

## Current State Analysis

### Existing Startup Methods

**Development:**
```bash
# Database
docker-compose -f docker-compose.dev.yml up -d

# Application
foreman start -f Procfile.dev
```

**Current Procfiles:**

`Procfile` (production):
```
web: bundle exec puma -C config/puma.rb
release: bundle exec rails db:migrate
```

`Procfile.dev` (development):
```
web: bundle exec rails s -p 3000
js: yarn build:watch
```

### Project Context

- **Branch:** `v2.3.0`
- **Rails Version:** 8.0.2.1
- **Current Work:** Coordinated release with vulcan-helm v0.3.0
- **Application:** STIG-ready security guidance documentation platform

### Recent Accomplishments (v2.3.0)

Already committed:
1. ✅ Comprehensive health check endpoints (`/up`, `/health_check/database`)
2. ✅ Configurable SSL enforcement (FORCE_SSL)
3. ✅ Production email validation
4. ✅ Release automation (rails_app_version gem)
5. ✅ Prometheus metrics integration (port 9394)
6. ✅ Multi-platform Docker support (amd64 + arm64)

Uncommitted work:
- Dockerfile fixes + Prometheus metrics
- prometheus_exporter integration

Test Status: ✅ 267 examples, 0 failures, 3 pending

## Rails 8 Modern Standards

### What Rails 8 Provides Out of the Box

1. **`bin/dev`** - Single command to start development environment
   - Uses Foreman or Overmind
   - Manages all processes (web, js, css, workers, etc.)
   - Consistent across projects

2. **`bin/setup`** - Automated environment setup
   - Installs dependencies
   - Creates databases
   - Seeds data
   - Runs migrations
   - One command for new developers

3. **Procfile.dev** - Single development process file
   - Web server
   - Asset compilation (js/css)
   - Background workers (if needed)
   - Other development services

4. **Environment-specific configuration**
   - `config/environments/development.rb`
   - `config/environments/test.rb`
   - `config/environments/production.rb`

## Modernization Goals

### 1. Consolidate Process Management

**Current Problems:**
- Two separate Procfiles (`Procfile`, `Procfile.dev`)
- Manual Docker Compose commands for database
- No standardized startup script
- Different processes for dev vs production

**Desired State:**
```bash
# Development (everything in one command)
bin/dev

# First-time setup
bin/setup

# Production (handled by Docker/Kubernetes)
# Uses Procfile or direct commands
```

### 2. Unified Procfile.dev Structure

Consolidate all development processes:
```procfile
web: bundle exec rails s -p 3000
js: yarn build:watch
prometheus: bundle exec prometheus_exporter -p 9394  # if needed in dev
# database: could be managed here or via docker-compose
```

### 3. Create bin/dev Script

Standard Rails 8 approach:
```bash
#!/usr/bin/env sh

if ! gem list foreman -i --silent; then
  echo "Installing foreman..."
  gem install foreman
fi

exec foreman start -f Procfile.dev "$@"
```

### 4. Create/Update bin/setup Script

Comprehensive setup for new developers:
```bash
#!/usr/bin/env ruby
require "fileutils"

# Setup environment
# Install dependencies
# Database setup
# Asset compilation
# etc.
```

### 5. Docker & Production Considerations

**Production Dockerfile:**
- Should use production-optimized Procfile
- Health checks on ports 3000 and 9394
- Multi-platform support (already done)

**Docker Compose for Development:**
- Could be started as part of `bin/dev` or separately
- PostgreSQL service
- Redis (if needed)
- Other backing services

## Current File Structure to Review

Key files that need attention:

```
vulcan-clean/
├── Procfile              # Production process file
├── Procfile.dev          # Development process file (exists)
├── bin/
│   ├── dev              # TO CREATE - Main dev startup
│   ├── setup            # TO REVIEW/UPDATE - First-time setup
│   └── docker-entrypoint # Production Docker startup
├── docker-compose.dev.yml  # Development services
├── Dockerfile           # Production image
├── Dockerfile.production # Production-specific
├── config/
│   ├── environments/
│   │   ├── development.rb
│   │   ├── test.rb
│   │   └── production.rb
│   └── puma.rb         # Web server config
└── docs/
    └── deployment/      # Need to update with new processes
```

## Implementation Plan

### Phase 1: Analysis & Planning
1. ✅ Document current state (THIS FILE)
2. Review existing `bin/setup` script
3. Identify all processes needed for dev/test/prod
4. Map out environment-specific requirements

### Phase 2: Create bin/dev
1. Create `bin/dev` script (Rails 8 standard)
2. Add foreman/overmind detection and installation
3. Test that it properly starts Procfile.dev

### Phase 3: Consolidate Procfile.dev
1. Review all development processes
2. Add database startup (or document docker-compose requirement)
3. Add Prometheus exporter if needed in dev
4. Add any background workers (Sidekiq, etc.)
5. Test full development startup with `bin/dev`

### Phase 4: Update bin/setup
1. Review existing setup script
2. Add Docker Compose database startup
3. Add asset compilation
4. Add seed data if needed
5. Test clean setup on new machine

### Phase 5: Production Procfile
1. Keep production `Procfile` simple and focused
2. Ensure it works with Docker/Kubernetes
3. Document production-specific processes
4. Test in container environment

### Phase 6: Documentation
1. Update README.md with new startup instructions
2. Update docs/deployment/ with process changes
3. Document differences between dev/test/prod
4. Create troubleshooting guide

### Phase 7: Testing
1. Test `bin/setup` from scratch
2. Test `bin/dev` in development
3. Test production builds
4. Test in Kubernetes/Docker environments
5. Verify Prometheus metrics still work

## Success Criteria

- [ ] Single command startup for development: `bin/dev`
- [ ] Single command setup for new developers: `bin/setup`
- [ ] Clear separation between dev and production processes
- [ ] Documentation updated and clear
- [ ] All tests still passing
- [ ] Health checks working (ports 3000 and 9394)
- [ ] Prometheus metrics accessible in all environments
- [ ] Docker builds work with new structure
- [ ] Kubernetes deployment unaffected

## Important Constraints

From project CLAUDE.md and git policies:

- **Never use** `git add -A` or `git add .`
- All tests must pass before committing
- No Claude signatures in commits
- Use "Authored by: Aaron Lippold<lippold@gmail.com>"
- Follow Rails 8 best practices
- Maintain backward compatibility during transition

## Related Work

### Current PR Status
- **PR #699** - v2.3.0 features (health checks, Prometheus, etc.)
- Needs update with Procfile modernization changes

### Helm Chart Coordination
- vulcan-helm v0.3.0 waiting for Vulcan v2.3.0
- Health probes depend on /up and /health_check endpoints
- Coordinated release required

### Memcord Context
- **Slot:** `vulcan-2.3.0-helm-0.3.0-coordinated-release`
- Contains context about coordinated release
- May need update with Procfile modernization work

## Next Steps for Claude Session

1. **Read this file** to understand full context
2. **Review existing files:**
   - `bin/setup` (if exists)
   - Current Procfile and Procfile.dev
   - docker-compose.dev.yml
   - Dockerfile and Dockerfile.production
3. **Create implementation plan** with specific tasks
4. **Start with Phase 1**: Analysis and detailed planning
5. **Get user approval** before making changes

## Questions to Answer

1. Do we need Prometheus exporter running in development?
2. Should database be part of Procfile.dev or keep docker-compose?
3. Are there background workers (Sidekiq, etc.) to include?
4. Do we need separate test environment startup?
5. How to handle Prometheus metrics port in different environments?
6. Asset compilation strategy (live reload vs precompile)?

## Resources

- Rails 8 guides: https://guides.rubyonrails.org/
- Procfile format: https://ddollar.github.io/foreman/
- Docker best practices for Rails
- Prometheus exporter gem documentation

---

**File Created:** 2025-11-16
**Purpose:** Context recovery for Procfile modernization work
**DO NOT COMMIT** this file to git (internal documentation only)
