# RECOVERY - Vulcan Docker SSL & Environment Setup
## Date: January 14, 2025
## Context at Compact: 11%

## 🚨 CRITICAL - READ FIRST
1. **READ**: `/Users/alippold/.claude/CLAUDE.md` - User's strict preferences (NO Claude signatures in commits!)
2. **READ**: `/Users/alippold/github/mitre/vulcan/CLAUDE.md` - Project context  
3. **CHECK MCP**: `mcp__server-memory__open_nodes` with names: `["Vulcan Rails 7 Upgrade", "Vulcan Bugs to Fix Post-Rails7", "Vulcan Docker Environment Cleanup"]`

## Current Status
- **Branch**: `upgrade-rails7-ruby33`
- **PR**: #680 - Tests passing, ready for Docker/env cleanup
- **Rails**: 7.0.8.7 + Ruby 3.3.9 + Node 22 LTS ✅
- **Docker**: SSL issue FIXED, production image optimized (1.76GB vs 6.5GB)

## What We Just Completed

### 1. Docker SSL Certificate Solution ✅
- Created `certs/` directory for corporate SSL certificates
- Updated Dockerfile to install certs from this directory
- Removed all `curl -k` flags (SonarCloud happy now)
- Added instructions to README for SSL setup
- Test with: `cp ~/.aws/mitre-ca-bundle.pem ./certs/`

### 2. Production Dockerfile Optimization ✅
- Created `Dockerfile.production` with multi-stage build
- Using `ruby:3.3.9-slim` base image
- Added jemalloc for 20-40% memory reduction
- Image size: 6.5GB → 1.76GB (73% reduction!)
- Added `zlib1g-dev` for fast_excel gem compilation

### 3. Platform Support ✅
```bash
bundle lock --add-platform x86_64-linux     # Intel/AMD
bundle lock --add-platform aarch64-linux    # ARM64
bundle lock --add-platform x86_64-linux-musl # Alpine
bundle lock --add-platform ruby             # Generic
```

### 4. Docker Compose Updates ✅
- `docker-compose.yml` now uses `Dockerfile.production`
- Added jemalloc environment variables
- Updated health check to use `/up` endpoint

## The Environment File Mess 🔥

### Current State (11 files!):
```
.env                    # Mixed dev + Docker vars + OIDC
.env-prod              # Rails secrets (created by setup script)
.env.dev               # ?
.env.development       # ?
.env.development.local # ?
.env.okta.dev         # ?
.env.backup           # ?
+ more...
```

### How It Currently Works:
1. `./setup-docker-secrets.sh` creates:
   - `.env` with POSTGRES_PASSWORD
   - `.env-prod` with SECRET_KEY_BASE, CIPHER_PASSWORD, CIPHER_SALT

2. `docker-compose.yml` uses:
   - `.env` for variable substitution (`${POSTGRES_PASSWORD}`)
   - `.env-prod` via `env_file:` for Rails app

### Test Okta Configuration:
```bash
VULCAN_ENABLE_OIDC=true
VULCAN_OIDC_ISSUER_URL=https://trial-8371755.okta.com
VULCAN_OIDC_CLIENT_ID=0oas3uve5k2VeT8KV697
VULCAN_OIDC_CLIENT_SECRET=aqfejOc97hxqtp5xZmn46yZ-m00Mx_xs3KIOzrlJuSM_UY_qx8BwhSaWYhvuOEnH
VULCAN_OIDC_REDIRECT_URI=http://localhost:3000/users/auth/oidc/callback
```

## What Needs to Be Done

### 1. Environment File Cleanup
- [ ] Consolidate to single `.env` per environment
- [ ] Create clear `.env.example` with ALL variables documented
- [ ] Update setup script to generate single file
- [ ] Clean up the 11 existing env files

### 2. Docker Documentation
- [ ] Document the full deployment process
- [ ] Add docker-compose instructions to README
- [ ] Explain SSL certificate setup clearly

### 3. Final PR Tasks
- [ ] Commit all Docker changes
- [ ] Push to PR #680
- [ ] Ensure CI passes with new Dockerfile

## Files Changed But Not Committed
```
M .gitignore               # Fixed to ignore .env files
M CLAUDE.md               # Project documentation
M Dockerfile              # SSL cert support
M Gemfile.lock            # Platform support
M README.md               # Docker instructions
M docker-compose.yml      # Production setup
M docker-compose.dev.yml  # Dev setup
? Dockerfile.production   # New optimized Dockerfile
? certs/                  # SSL certificate directory
? .env.example           # Should be created
```

## Commands for Testing
```bash
# Build production image
docker buildx build -f Dockerfile.production -t vulcan:production --load .

# Run with docker-compose
./setup-docker-secrets.sh
docker-compose up -d

# Check logs
docker-compose logs -f web

# Database setup (first time)
docker-compose run --rm web rake db:create db:schema:load db:migrate
docker-compose run --rm web rake db:seed
```

## User Preferences (IMPORTANT)
- NO Claude signatures in commits
- Fix root causes, not workarounds
- Use `Authored by: Aaron Lippold<lippold@gmail.com>`
- User was getting tired, may take a break

## Next Session Focus
1. Clean up environment files (priority!)
2. Test full docker-compose deployment
3. Commit and push Docker changes
4. Merge PR #680