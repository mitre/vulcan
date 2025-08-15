# Recovery Prompt - Vulcan Rails 7 + Ruby 3.1 Upgrade
## Date: January 12, 2025
## Context Level at Compact: 0%

### CRITICAL: First Actions After Compact
1. **READ /Users/alippold/.claude/CLAUDE.md** - User's global preferences and rules
2. **READ /Users/alippold/github/mitre/vulcan/CLAUDE.md** - Vulcan project-specific context
3. **READ this file completely** before taking any actions
4. **CHECK MCP memory**: `mcp__server-memory__open_nodes` with name "Vulcan Rails 7 Upgrade"

### Current Working Directory
`/Users/alippold/github/mitre/vulcan`

### Current Git Status
- **Branch**: upgrade-settingslogic-ruby31
- **Status**: Uncommitted changes from Rails 7 upgrade
- **Key Changes**: Rails 6.1→7.0, Ruby 2.7.5→3.1.6, settingslogic→mitre-settingslogic

### What We Accomplished Today
1. **Started with goal**: Upgrade to latest Ruby + Rails possible
2. **Discovered blocker**: settingslogic incompatible with Ruby 3.1+ (Psych 4 issue)
3. **Fixed settingslogic**: Replaced with mitre-settingslogic 3.0.3
4. **Upgraded Ruby**: 2.7.5 → 3.1.6
5. **Upgraded Rails**: 6.1.4 → 7.0.8.7
6. **Fixed Rails 7.0 issues**:
   - Pinned concurrent-ruby to 1.3.4 (Rails 7.0 Logger bug)
   - Upgraded Audited gem to 5.8.0
   - Configured Audited with string class name: 'VulcanAudit'
7. **Handled RuboCop**:
   - Version jumped 1.25.1 → 1.79.2
   - Auto-corrected 133 offenses
   - Documented 33 pre-existing offenses in RUBOCOP-TECH-DEBT.md
8. **Rails app:update**: Completed successfully, created ActiveStorage migrations

### Critical Context
- **Rails 7.0 + Ruby 3.1 + concurrent-ruby 1.3.5 = BROKEN** (Logger issue)
- **Solution**: Pin concurrent-ruby to 1.3.4 in Gemfile (already done)
- **Audited gem**: Must use string class name 'VulcanAudit' not constant
- **config.load_defaults**: Still at 6.0, needs update to 7.0
- **Tests**: Not run yet - need database (docker-compose.dev.yml)

### Files Modified (Key ones)
- `Gemfile`: Rails 7.0, concurrent-ruby 1.3.4, mitre-settingslogic 3.0.3, audited 5.8.0
- `Gemfile.lock`: Updated with all new versions
- `config/application.rb`: Rails 7 updates (Logger workaround can be removed)
- `config/initializers/audited.rb`: String class name configuration
- `.rubocop.yml`: Pre-existing offenses excluded
- `RUBOCOP-TECH-DEBT.md`: Documentation of 33 offenses to fix later
- Config files updated by `rails app:update`
- New migrations in `db/migrate/` for ActiveStorage

### Immediate Next Steps
```bash
# 1. Check current status
git status
git diff --stat

# 2. Update config.load_defaults in config/application.rb
# Change from: config.load_defaults 6.0
# To: config.load_defaults 7.0

# 3. Remove Logger workaround from config/application.rb (no longer needed)
# Delete these lines:
# require 'logger' if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.1.0')

# 4. Test Rails boots
bundle exec rails runner "puts 'Rails 7.0 + Ruby 3.1.6 working!'"

# 5. Run migrations (start postgres first)
docker-compose -f docker-compose.dev.yml up -d
bundle exec rails db:migrate

# 6. Run tests
bundle exec rspec

# 7. Commit everything
git add -A
git commit -m "Upgrade to Rails 7.0 + Ruby 3.1.6 + mitre-settingslogic

- Upgrade Rails from 6.1.4 to 7.0.8.7
- Upgrade Ruby from 2.7.5 to 3.1.6
- Replace settingslogic with mitre-settingslogic 3.0.3
- Pin concurrent-ruby to 1.3.4 (Rails 7.0 compatibility)
- Upgrade Audited gem to 5.8.0
- Update all related dependencies
- Auto-correct 133 RuboCop offenses
- Document 33 pre-existing RuboCop offenses

Authored by: Aaron Lippold<lippold@gmail.com>"

# 8. Push and create PR
git push origin upgrade-settingslogic-ruby31
```

### User Preferences & Context
- **HATES workarounds** - wants proper fixes
- **No `git add -A`** normally but okay for this big upgrade
- **No Claude signatures** in commits
- **Fix root causes** not symptoms
- Gets frustrated with repeated mistakes
- Prefers clear, direct communication

### Other Branches for Reference
- **origin/upgrade-rails**: Has Rails 7 work but uses Ruby 3.0.6 and old settingslogic
- **master**: Original starting point

### Why This Matters
This upgrade unblocks future Ruby versions (3.2, 3.3) and Rails versions (7.1, 7.2) for Vulcan. The settingslogic fix was critical as it was blocking all Ruby 3.1+ upgrades due to Psych 4 incompatibility.

### REMEMBER
- Rails 7.0 + Ruby 3.1 works but needs concurrent-ruby pinned
- Audited gem needs string class configuration
- Tests haven't been run yet
- config.load_defaults needs update to 7.0
- This is a big upgrade - expect some issues but foundation is solid