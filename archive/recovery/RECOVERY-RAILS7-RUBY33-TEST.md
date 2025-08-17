# RECOVERY PROMPT - Vulcan Rails 7 + Ruby 3.3 Testing
## Context at Compact: 9% - January 13, 2025, 4:00 PM PST
## Status: Rails 7 COMPLETE, Testing Ruby 3.3.6 compatibility

### 🚨 CRITICAL FIRST STEPS AFTER COMPACT
1. **MUST READ**: `/Users/alippold/.claude/CLAUDE.md` - User's STRICT preferences
   - NO Claude signatures in commits! Use: "Authored by: Aaron Lippold<lippold@gmail.com>"
   - Fix root causes, no workarounds
   - Prefer Python/Ruby over sed for text processing
2. **MUST READ**: `/Users/alippold/github/mitre/vulcan/CLAUDE.md` - Project context
3. **CHECK MCP**: `mcp__server-memory__open_nodes` with names:
   - "Vulcan Rails 7 Upgrade"
   - "Vulcan Bugs to Fix Post-Rails7"
4. **VERIFY**: On branch `upgrade-settingslogic-ruby31`

### 📍 CURRENT STATE
```bash
pwd: /Users/alippold/github/mitre/vulcan
branch: upgrade-settingslogic-ruby31
server: http://localhost:3000 (foreman start -f Procfile.dev)
login: admin@example.com / 1234567ab!
Ruby: 3.1.6 (testing upgrade to 3.3.6)
Rails: 7.0.8.7
Tests: ALL 198 PASSING
Node: 16.x (per .nvmrc)
```

### ✅ COMPLETED IN THIS SESSION
1. **Rails 7.0.8.7** - Fully upgraded from Rails 6.1.4
2. **Ruby 3.1.6** - Upgraded from Ruby 2.7.5
3. **Webpacker → jsbundling-rails** - Migration complete with esbuild
4. **84 MDI icons → Bootstrap Icons** - All replaced
5. **OIDC Cookie Overflow** - Fixed by moving to Rails.cache
6. **Component rules_count** - Fixed counter cache issue
7. **All tests passing** - Fixed ENV.fetch mocking and test environment cache
8. **Linting clean** - RuboCop and ESLint passing

### 🎯 IMMEDIATE NEXT STEP: Test Ruby 3.3.6

```bash
# 1. Update Ruby version
echo "3.3.6" > .ruby-version

# 2. Switch Ruby (with rvm)
rvm use 3.3.6

# 3. Reinstall gems
bundle install

# 4. Run tests
bundle exec rspec

# 5. Test the server
foreman start -f Procfile.dev

# 6. If all passes, update Gemfile:
# ruby "3.3.6"
```

### 📝 RECENT COMMITS (in order)
```
1b88359 fix: Fix component rules_count counter cache
3ef391c chore: Add trailing newline to esbuild.config.js
711ebee chore: Remove old Webpacker artifacts
0d93c2d fix: Improve ComponentCard UI and fix control count display
809608c style: Apply RuboCop auto-corrections
afb280c fix: Move OIDC discovery cache from session to Rails.cache
703c474 feat: Upgrade to Rails 7.0 + Ruby 3.1.6 + jsbundling-rails + Bootstrap Icons
```

### 🐛 BUGS TO FIX IN FUTURE PRs
1. **Test suite destructive** - Wipes dev database when tests run in dev mode
2. **Overlaid components** - Have 0 rules in seed data (should copy from parent)

### 🔧 KEY FILES MODIFIED

**OIDC Cookie Fix:**
- `app/controllers/concerns/oidc_discovery_helper.rb` - Uses Rails.cache
- `config/environments/test.rb` - Changed to memory_store from null_store
- `spec/controllers/sessions_controller_spec.rb` - Updated tests for Rails.cache

**Counter Cache Fix:**
- `app/models/rule.rb` - Added `counter_cache: true`
- `app/models/component.rb` - Reset counters after bulk import & duplication
- `db/migrate/20250813154605_fix_component_rules_counter_cache.rb` - Migration

**UI Improvements:**
- `app/javascript/components/components/ComponentCard.vue` - Fixed layout
- `app/views/components/show.html.haml` - Fixed v-bind error

### 🚀 AFTER RUBY 3.3 TESTING

**If Ruby 3.3.6 works:**
1. Update Gemfile with `ruby "3.3.6"`
2. Commit: "feat: Upgrade to Ruby 3.3.6 for better performance"
3. Consider renaming branch to `upgrade-rails7-ruby33`

**Create PR:**
```bash
git push -u origin upgrade-settingslogic-ruby31
gh pr create --title "feat: Upgrade to Rails 7.0 + Ruby 3.3 + jsbundling" \
  --body "Major upgrade including Rails 7, Ruby 3.3, and modern asset pipeline"
```

### ⚠️ ENVIRONMENT CHECKS
- Database: PostgreSQL 12 (docker-compose.dev.yml)
- Node: 16.x required (check with `node -v`)
- Test database separate from dev (check database.yml)

### 💡 KEY LEARNINGS
- Rails.cache in test env needs memory_store, not null_store
- Component.reset_counters needed after bulk import
- ENV.fetch requires separate mocking from ENV[]
- Bootstrap Icons replaces MDI icons in Vue components
- OIDC discovery documents can exceed 4KB cookie limit

### 🔍 QUICK VERIFICATION COMMANDS
```bash
# Check Ruby version
ruby -v

# Check all tests pass
bundle exec rspec

# Check linting
bundle exec rubocop && yarn lint:ci

# Check component counts are correct
echo "Component.pluck(:name, :rules_count)" | bundle exec rails console

# Check for uncommitted changes
git status
```

---
*Recovery document at 9% context for Ruby 3.3 testing phase*