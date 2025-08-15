# Vulcan Post-Merge Recovery - January 14, 2025

## CRITICAL - Read These First
1. **FIRST**: Read /Users/alippold/.claude/CLAUDE.md for user's strict preferences
2. **SECOND**: Read /Users/alippold/github/mitre/vulcan/CLAUDE.md for project context
3. **THIRD**: Check MCP memory for current state

## Current State (January 14, 2025 - Post PR #680 Merge)
- **PR #680 MERGED**: Rails 7.0.8.7 + Ruby 3.3.9 + Node 22 LTS
- **Branch merged**: upgrade-rails7-ruby33 → master
- **Merge type**: Regular merge (preserved full history)
- **Both staging AND production deployed** (BUG - production shouldn't auto-deploy)

## What Was Accomplished in PR #680
### Major Upgrades
- Rails 6.1 → 7.0.8.7
- Ruby 2.7.5 → 3.3.9 (via 3.1.6 → 3.3.6 → 3.3.9)
- Node 16 → 22 LTS
- Webpacker → jsbundling-rails with esbuild
- MDI Icons → Bootstrap Icons (all 84 converted)

### Infrastructure Improvements
- Docker image: 6.5GB → 1.76GB (73% reduction)
- Added jemalloc for 20-40% memory reduction
- Heroku stack: heroku-20 → heroku-24
- Environment files: 11 → 1 (.env consolidation)
- SonarCloud issues: 13 → 0

## CRITICAL ISSUES TO FIX

### 1. Heroku Pipeline Configuration BUG 🚨
- **Problem**: Production auto-deployed from master (should NOT)
- **Evidence**: Both staging and prod deployed within 9 seconds
- **Fix needed**: Disable auto-deploy on production, use manual promotion only
- **Deployed commits**: c95480da (both staging v295 and prod v179)

### 2. Docker/CI Workflows Failing
- **Anchore SBOM scan**: Failing - curl not found (exit code 127)
- **Docker Hub push**: Failing - same curl issue
- **Root cause**: Ruby 3.3.9 base image doesn't include curl
- **Fix needed**: Add `apt-get install curl` before using curl in Dockerfile

### 3. Dockerfile Discrepancy
- Dockerfile on master still shows `FROM ruby:2.7` (should be 3.3.9)
- Need to verify which Dockerfile is actually on master

## Known Remaining Bugs (Not Blockers)
1. **Overlaid components**: Show 0 controls (seed data issue)
2. **Test suite**: Can wipe development database if run in dev mode
3. **Flaky test**: spec/features/local_login_spec.rb:27 (skipped)

## Test Credentials
- **Test Okta**: trial-8371755.okta.com
- **Dev admin**: admin@example.com / 1234567ab!
- **Heroku review app**: https://vulcan-pr-680.herokuapp.com/

## Recovery Commands
```bash
# Check current branch and state
git status
git branch --show-current

# Verify master is up to date
git checkout master
git pull origin master

# Check Heroku deployments
heroku releases --app mitre-vulcan-staging -n 2
heroku releases --app mitre-vulcan-prod -n 2

# Check failed workflows
gh run list --branch master --limit 5

# Check MCP memory
# Use: mcp__server-memory__open_nodes
# With: ["Vulcan Post-Merge Issues", "Vulcan PR 680 Status", "Vulcan Rails 7 Upgrade"]
```

## Next Steps Priority
1. **URGENT**: Fix Heroku production auto-deploy
2. **HIGH**: Fix Docker workflows (add curl to Dockerfile)
3. **MEDIUM**: Update release process documentation
4. **LOW**: Fix overlaid component counts in seed data

## File Locations
- **Main Dockerfile**: /Users/alippold/github/mitre/vulcan/Dockerfile
- **Production Dockerfile**: /Users/alippold/github/mitre/vulcan/Dockerfile.production
- **Heroku config**: /Users/alippold/github/mitre/vulcan/app.json
- **Procfile**: /Users/alippold/github/mitre/vulcan/Procfile

## Git Configuration
- **NEVER use Claude signatures** in commits
- Always use: `Authored by: Aaron Lippold<lippold@gmail.com>`
- Never use `git add -A` or `git add .`

## Important Context
- User prefers direct communication about technical limitations
- User wants root cause fixes, not workarounds
- Currently at 0% context, preparing for compact
- Rollback point if needed: v2.1.9 tag