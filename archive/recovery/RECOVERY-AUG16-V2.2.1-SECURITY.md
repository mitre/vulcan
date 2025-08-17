# Recovery Context - August 16, 2025 - v2.2.1 Security Release

## 🔴 CRITICAL - READ FIRST
**MUST READ**:
1. `/Users/alippold/.claude/CLAUDE.md` - Global Claude settings
2. `/Users/alippold/github/mitre/vulcan/CLAUDE.md` - Project-specific Claude settings

**Key Rules**:
- **NEVER use `git add -A` or `git add .`** - ALWAYS add files individually
- **WE DO NOT COMMIT BROKEN CODE EVER** - all tests and linting must pass
- **Use YARN for JavaScript, NOT npm**
- **Git commits use**: `Authored by: Aaron Lippold<lippold@gmail.com>` - NO Claude signatures
- **SonarCloud API**: Use `$SONAR_CURRENT` environment variable (NOT $SONAR_CLOUD_API)

## 📍 CURRENT STATE (August 16, 2025 - Evening)
- **Location**: `/Users/alippold/github/mitre/vulcan`
- **Current Branch**: `master`
- **Latest Release**: v2.2.1 (security patch) - Just released
- **Previous Release**: v2.2.0 (major modernization) - Released earlier today
- **Status**: Two successful releases completed today, security issues resolved

## ✅ TODAY'S ACCOMPLISHMENTS

### v2.2.0 Release (Morning)
- Rails 8.0.2.1, Ruby 3.3.9, Node.js 22 LTS upgrades
- Docker image reduced to 1.76GB (73% reduction)
- All 190 tests passing
- Fixed issue #681 (Applicable-Configurable field display)
- MDI to Bootstrap Icons migration completed
- Comprehensive documentation overhaul

### v2.2.1 Security Release (Afternoon)
- **CRITICAL SECURITY FIX**: Removed admin@example.com from production
  - Account had been created April 17, 2024
  - Had 11 project memberships, 33 logins
  - Transferred all memberships to alippold@mitre.org before deletion
- Fixed app.json to prevent seeding in Review Apps
- Added environment checks to create_admin.rb
- Fixed Kubernetes security (automountServiceAccountToken: false)
- Fixed email template accessibility issues
- Fixed version comparison bug (was showing 2.1.8 > 2.2.0)

## 🔐 SECURITY FIXES DETAILS
- **Root Cause**: app.json line 53 had `DISABLE_DATABASE_ENVIRONMENT_CHECK=1` in postdeploy
- **Impact**: Heroku Review Apps were creating admin@example.com with password `1234567ab!`
- **Resolution**: Removed db:seed from postdeploy, added Rails.env.local? checks
- **Production Cleanup**: Used `heroku pg:psql --app mitre-vulcan-prod` to delete account
- **Heroku Apps**: mitre-vulcan-prod, mitre-vulcan-staging, mitre-vulcan-training (team: mitre-saf)

## 🎯 NEXT PRIORITIES

### Immediate (Vue 3 Migration - Phase 1)
```bash
git checkout master
git pull origin master
git checkout feature/vue3-bootstrap5-migration
# OR create sub-branch:
git checkout -b feature/vue3-bootstrap5-migration/remove-turbolinks
```
- Remove Turbolinks completely (4-8 hours)
- All JavaScript using `turbolinks:load` needs updating
- vue-turbolinks is dead, no Vue 3 support

### Short Term
- Address Issue #651: User deletion with Reviews breaks Components
- Review 63 Dependabot alerts (many false positives)
- Fix remaining SonarCloud bugs (7) if critical

### Long Term
- Complete Vue 3 + Bootstrap 5 migration (7-9 weeks total)
- Modernize release process (Issue #678)
- Enterprise configuration management (Issue #673)
- Document supported Postgres versions (Issue #657)

## 🔧 TECHNICAL NOTES
- SonarCloud only analyzes master branch by default
- SonarCloud API token is in `$SONAR_CURRENT` env var
- Heroku CLI can be slow - use `heroku pg:psql` for database work
- ESLint CI mode fails on ANY warnings (`--max-warnings 0`)
- Rails.env.local? returns true for development AND test
- Release notes in docs/release-notes/ with symlink at root

## 📂 PROJECT STRUCTURE
- Release notes: `/docs/release-notes/RELEASE_NOTES_v*.md`
- Latest release symlink: `/RELEASE_NOTES.md -> docs/release-notes/RELEASE_NOTES_v2.2.1.md`
- Recovery files: Various in root and `/docs/archive/recovery/`
- Migration plans: `VUE3-*.md` files in root

## 🔍 MCP MEMORY KEYS
```ruby
mcp__server-memory__open_nodes with names:
["Vulcan Technical Learnings", "Next Steps Vulcan",
 "Vue 3 Migration Plan", "Vue 3 Migration Progress",
 "Vulcan v2.2.0 Release", "Vulcan v2.2.1 Release",
 "Security Fixes Applied"]
```

## ⚠️ KNOWN ISSUES
1. SonarCloud shows 881 code smells (not critical)
2. 63 Dependabot vulnerabilities (many false positives)
3. Issue #651: User deletion with Reviews breaks Components

## 💭 CONTEXT
Completed two major releases in one day. v2.2.0 was a massive modernization (Rails 8, Ruby 3.3.9, Node 22). v2.2.1 was an urgent security patch after discovering admin@example.com in production with a known password. The account has been removed and the vulnerability fixed. Ready to start Vue 3 migration next.

## 🔮 RECOVERY COMMANDS
```bash
# Check current status
git status
git log --oneline -5

# Check CI/deployment status
gh run list --branch master --limit 3
heroku apps --team mitre-saf

# Check for security issues
heroku pg:psql --app mitre-vulcan-prod -c "SELECT email FROM users WHERE email LIKE '%@example.com';"

# Start Vue 3 migration
git checkout feature/vue3-bootstrap5-migration
```