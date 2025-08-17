# Recovery Context - January 15, 2025 - Dependency Updates in Progress

## CRITICAL - READ FIRST
**ALWAYS READ**: `/Users/alippold/.claude/CLAUDE.md` - User's STRICT preferences including:
- **NEVER use `git add -A` or `git add .`** - ALWAYS add files individually
- **WE DO NOT COMMIT BROKEN CODE EVER** - all tests and linting must pass
- Git commits use: `Authored by: Aaron Lippold<lippold@gmail.com>` - NO Claude signatures
- Find and fix ROOT CAUSES, never work around problems
- **ALWAYS use rm -f flag** when deleting files to avoid prompts

## Current State
- **Location**: `/Users/alippold/github/mitre/vulcan`
- **Branch**: `security/dependency-updates-jan2025` (not pushed yet)
- **Base**: Rails 8.0.2.1, Ruby 3.3.9, Node.js 22 LTS
- **Tests**: All 198 passing
- **Main Issue**: 63 vulnerabilities reported by GitHub (5 critical, 12 high)

## What Just Happened

### Documentation Cleanup (COMPLETED - pushed to master)
- Cleaned project root from 39 to 6 essential markdown files
- Created tag `v2.2.0-rails8-deployed` on commit e0c0eca (production deployment)
- Reorganized docs into logical folders (archive/, technical/, planning/, migrations/)
- 9 commits pushed to master on January 15, 2025

### Dependency Updates (IN PROGRESS)
On branch `security/dependency-updates-jan2025`:

**Ruby Gems Updated:**
- regexp_parser: 2.11.1 → 2.11.2
- mime-types-data: 3.2025.0805 → 3.2025.0812
- selenium-webdriver: 4.32.0 → 4.35.0

**JavaScript Packages Updated (using YARN, not npm!):**
- @rails/actioncable: 7.2.201 → 8.0.201
- @rails/activestorage: 7.2.201 → 8.0.201
- @rails/ujs: 7.1.501 → 7.1.3-4
- esbuild: 0.25.8 → 0.25.9
- eslint-config-prettier: 8.10.0 → 8.10.2

**Status**: 2 commits ready, not pushed yet

## Key Technical Context

### Package Management
- **JavaScript**: Use `yarn`, NOT `npm`!
- **Ruby**: Use `bundle` for gems
- Files: `yarn.lock` (tracked), NO `package-lock.json`

### Vulnerability Context
Most remaining vulnerabilities are:
- Vue 2 related (planned for Vue 3 migration - Phase 2)
- Bootstrap 4 related (planned for Bootstrap 5 migration - Phase 1)
- Cannot update these until their respective migration phases

### Testing Commands
```bash
# Ruby tests
bundle exec rspec --format progress

# Build JavaScript
yarn build

# Check outdated packages
bundle outdated
yarn outdated
```

## Next Steps
1. Push the dependency updates branch
2. Create PR for dependency updates
3. Consider addressing non-Vue/Bootstrap vulnerabilities
4. Plan Phase 1: Bootstrap 5 migration (next major task)

## MCP Memory Keys
Check memory with:
```
mcp__server-memory__open_nodes with names:
["Rails 8 Upgrade Success", "Vulcan Technical Learnings", "Bootstrap 5 Migration Plan", "Dependency Updates January 2025"]
```

## Important Files
- `/Users/alippold/.claude/CLAUDE.md` - User's strict preferences
- `/Users/alippold/github/mitre/vulcan/SESSION_RECOVERY.md` - Previous session
- `docs/migrations/BOOTSTRAP-5-MIGRATION-PLAN.md` - Next major task
- `ROADMAP.md` - Project roadmap with phases

## Git Status
- Master is up to date with all documentation changes
- On branch `security/dependency-updates-jan2025` with 2 unpushed commits
- Ready to create PR for dependency updates