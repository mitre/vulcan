# Recovery Context - January 14, 2025 - Rails 8 Upgrade Complete

## CRITICAL - READ FIRST
**ALWAYS READ**: `/Users/alippold/.claude/CLAUDE.md` - User's STRICT preferences including:
- **NEVER use `git add -A` or `git add .`** - ALWAYS add files individually
- **WE DO NOT COMMIT BROKEN CODE EVER** - all tests and linting must pass
- Git commits use: `Authored by: Aaron Lippold<lippold@gmail.com>` - NO Claude signatures
- Find and fix ROOT CAUSES, never work around problems

## Current State
- **Location**: `/Users/alippold/github/mitre/vulcan`
- **Branch**: `master` (Rails 8.0.2.1 merged via PR #682)
- **Rails**: 8.0.2.1 ✅
- **Ruby**: 3.3.9 ✅
- **Tests**: All 198 passing, 0 failures ✅
- **Security**: 0 Brakeman warnings (fixed SQL injection) ✅
- **SonarCloud**: Passing (fixed with .sonarcloud.properties) ✅

## What Just Happened
Successfully upgraded Rails from 7.0.8.7 → 7.1.5.2 → 7.2.2.2 → 8.0.2.1:
1. Fixed test failures by finding root causes (Settings mocks, cache store, ActionMailer config)
2. Fixed SQL injection in Component#duplicate_rules using parameterized queries
3. Migrated to Rails 8 `expect` API for strong parameters
4. Fixed SonarCloud duplication issues with .sonarcloud.properties
5. Merged PR #682 to master

## Key Technical Details

### Test Environment (config/environments/test.rb)
**CRITICAL**: Rails app:update overwrites this file - always restore:
```ruby
config.action_controller.perform_caching = true
config.cache_store = :memory_store
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

### SQL Injection Fix
Changed from string interpolation to parameterized queries:
```ruby
# OLD (vulnerable):
Arel.sql("UPDATE base_rules SET created_at = '#{orig_rule.created_at}'...")

# NEW (secure):
ActiveRecord::Base.connection.exec_query(
  'UPDATE base_rules SET created_at = ?, updated_at = ? WHERE id = ?',
  'SQL',
  [[nil, orig_rule.created_at], [nil, orig_rule.updated_at], [nil, new_rule.id]]
)
```

### SonarCloud Configuration
- File: `.sonarcloud.properties` (NOT sonar-project.properties)
- No wildcards allowed in automatic analysis
- Property: `sonar.cpd.exclusions=public/404.html,public/422.html,public/500.html`

## Immediate Tasks Needed
1. **Update README.md** - Document Rails 8.0.2.1 requirement
2. **Update CHANGELOG.md** - Add Rails 8 upgrade entry
3. **Check VERSION file** - Ensure version bump if needed
4. **Update documentation** - Any references to Rails 7 need updating

## Next Major Task: Bootstrap 5 Migration
- Current: Bootstrap 4.4.1 + Bootstrap-Vue 2.13.0 + Vue 2.x
- Challenge: Bootstrap-Vue only works with Bootstrap 4 and Vue 2
- Plan documented in: `BOOTSTRAP-5-MIGRATION-PLAN.md`
- Reference project: github.com/dangkhoa2016/Rails-8-Authentication

## MCP Memory Keys
Check memory with:
```
mcp__server-memory__open_nodes with names:
["Rails 8 Upgrade Success", "Vulcan Technical Learnings", "Bootstrap 5 Migration Plan", "Vulcan Post-Merge Issues"]
```

## Default Credentials
- Admin seed: `admin@example.com` / `1234567ab!`
- Regular users: `1234567ab!`

## Critical Files to Remember
- `/Users/alippold/.claude/CLAUDE.md` - User's strict preferences
- `/Users/alippold/github/mitre/vulcan/CLAUDE.md` - Project-specific guidelines
- `BOOTSTRAP-5-MIGRATION-PLAN.md` - Next major task details
- `.sonarcloud.properties` - SonarCloud exclusions config