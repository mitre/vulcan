# Vulcan Recovery - January 14, 2025 (Post-Fixes Session)

## CRITICAL - Read These First
1. **ALWAYS READ**: `/Users/alippold/.claude/CLAUDE.md` - User's strict preferences
   - NO Claude signatures in commits
   - Always use: `Authored by: Aaron Lippold<lippold@gmail.com>`
   - Test BEFORE committing
   - Be direct about what you're doing
   - No unnecessary operations (like stashing when not needed)

2. **PROJECT CONTEXT**: `/Users/alippold/github/mitre/vulcan/CLAUDE.md`

3. **CHECK MCP MEMORY**: 
```
mcp__server-memory__open_nodes with names:
["Vulcan Post-Merge Issues", "Vulcan Fixes Applied Jan 14", "Vulcan PR 680 Status"]
```

## Current State (January 14, 2025 - 4% Context)
- **PR #680 MERGED**: Rails 7.0.8.7 + Ruby 3.3.9 + Node 22 LTS
- **Working Directory**: `/Users/alippold/github/mitre/vulcan`
- **Current Branch**: master
- **Ruby/Node**: 3.3.9 / Node 22 LTS

## Fixes Applied Today

### 1. Docker Build Failures ✅ FIXED & PUSHED
- **Issue**: CI/CD workflows failing with "apt-key: not found" 
- **Root Cause**: Ruby 3.3.9 uses Debian Trixie which removed apt-key command
- **Additional Issue**: Dockerfile line 8 had comment in RUN command preventing SSL certs installation
- **Fix Applied**:
  - Removed comment from RUN command on line 8
  - Replaced `apt-key add` with `gpg --dearmor` and `signed-by`
  - Added ca-certificates, curl, gnupg installation first
- **Commit**: 17d760f (already pushed to master)
- **Result**: ✅ All workflows passing (Docker Hub push, Anchore SBOM)

### 2. Bundler Deprecation Warning ✅ FIXED
- **Issue**: `--without` flag deprecated in bundle install
- **Fix Applied**: 
  ```dockerfile
  RUN bundle config set --local without 'development test' && \
      bundle install
  ```
- **Commit**: 32f6075 (ready to push)
- **Tested**: Docker build successful, no deprecation warning

### 3. Overlay Component 0 Controls ✅ FIXED  
- **Issue**: Overlay components showing 0 controls in seed data
- **Fix Applied**: Added rule duplication in db/seeds.rb:
  ```ruby
  photon3_v1r1.rules.each do |orig_rule|
    photon3_v1r1_overlay.rules.create!(orig_rule.attributes.except('id', 'created_at', 'updated_at', 'component_id'))
  end
  ```
- **Commit**: 017ead2 (ready to push)
- **Tested**: Overlay now has 191 rules matching parent

### 4. config.load_defaults ✅ ALREADY FIXED
- Was already set to 7.0 in PR #680

## Pending Commits (Not Pushed Yet)
```bash
git log --oneline origin/master..HEAD
# 017ead2 fix: Fix overlay component having 0 controls in seed data
# 32f6075 fix: Replace deprecated bundle install --without flag
```

## Remaining Issues to Fix

### Critical Bug
1. **Vue Error on /stigs Endpoint** 🐛
   - Error: `v-bind:queried-rule` cannot be empty
   - Template compilation error in stig.html.haml
   - Affects STIG page functionality
   - Likely needs default value or conditional rendering

### High Priority
2. **Heroku Production Auto-Deploy** 🚨
   - Production is auto-deploying from master (security issue)
   - Should only deploy via manual promotion from staging
   - Requires Heroku dashboard access to fix

### Medium Priority  
2. **Dependabot Security Vulnerabilities**
   - 64 total: 5 critical, 12 high, 36 moderate, 11 low
   - Check with: `gh api /repos/mitre/vulcan/dependabot/alerts`

3. **Flaky Test**
   - `spec/features/local_login_spec.rb:27` - currently skipped

### Low Priority
4. **Documentation Updates**
   - Update release process documentation
   - Create release tag for Rails 7 upgrade (v2.2.0 or v3.0.0?)

5. **Cleanup**
   - Remove recovery documents (many RECOVERY-*.md files)
   - Move to docs/ or delete

## Development Environment

### Start Dev Environment
```bash
# Start PostgreSQL
docker-compose -f docker-compose.dev.yml up -d

# Start Rails + JS build
foreman start -f Procfile.dev
# OR separately:
# bundle exec rails s -p 3000
# yarn build:watch

# Access at http://localhost:3000
# Login: admin@example.com / 1234567ab!
```

### Test Commands
```bash
# Run tests
bundle exec rspec

# Check overlay component in console
bundle exec rails console
c = Component.find(4)  # Photon OS 3 overlay
puts "Rules: #{c.rules.count}"  # Should be 191

# Check workflows
gh run list --branch master --limit 5
```

## Git Configuration
- NEVER use Claude signatures
- Always use: `Authored by: Aaron Lippold<lippold@gmail.com>`
- Don't use `git add -A` or `git add .`
- Test changes before committing

## Next Actions
1. Push the two pending commits to master
2. Monitor CI/CD to ensure everything stays green
3. Address Heroku production auto-deploy issue (needs dashboard)
4. Review Dependabot alerts for critical vulnerabilities

## Recovery Command After Compact
When returning after compact, paste:
```
I need to continue work on Vulcan post-fixes. We just fixed Docker build issues,
bundler deprecation, and overlay component seed data.

CRITICAL: First read /Users/alippold/.claude/CLAUDE.md for my preferences.
Then read /Users/alippold/github/mitre/vulcan/RECOVERY-JAN14-POST-FIXES.md 
for current state.

Check MCP memory: mcp__server-memory__open_nodes with 
["Vulcan Post-Merge Issues", "Vulcan Fixes Applied Jan 14"]

We have 2 commits ready to push (32f6075 and 017ead2). 
Should we push them or work on other issues first?
```