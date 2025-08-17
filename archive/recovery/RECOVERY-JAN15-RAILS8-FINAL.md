# Recovery Context - January 15, 2025 - Vulcan Rails 8 Migration Status

## 🔴 CRITICAL - READ FIRST
**ALWAYS READ**: `/Users/alippold/.claude/CLAUDE.md` and `/Users/alippold/github/mitre/vulcan/CLAUDE.md`
- **NEVER use `git add -A` or `git add .`** - ALWAYS add files individually
- **WE DO NOT COMMIT BROKEN CODE EVER** - all tests and linting must pass
- **Use YARN for JavaScript, NOT npm**
- **Git commits use**: `Authored by: Aaron Lippold<lippold@gmail.com>` - NO Claude signatures

## ✅ COMPLETED WORK (January 15, 2025)

### Dependency Updates & Test Modernization
- **Branch**: `security/dependency-updates-jan2025` 
- **PR**: #683 (https://github.com/mitre/vulcan/pull/683)
- **Status**: 6 commits pushed, all 190 tests passing

### What We Accomplished:
1. **Security Updates**:
   - axios 1.6.8 → 1.11.0 (SSRF fix)
   - factory_bot 5.2.0 → 6.5.4
   - ESLint 8.x → 8.57.1 (downgraded from 9 for compatibility)
   - Prettier 2.8.8 → 3.6.2
   - eslint-plugin-prettier 4.2.1 → 5.2.1 (for Prettier 3 compatibility)

2. **Test Modernization**:
   - Migrated ALL controller specs → request specs (Rails 8 requirement)
   - Migrated ALL feature specs → system specs (Rails 5.1+ standard)
   - Removed `any_instance_of` anti-pattern (4 occurrences)
   - Fixed all Devise authentication issues in request specs

3. **Icon Migration**:
   - Complete MDI → Bootstrap icon migration
   - Removed @mdi/font package
   - Updated all icon references

## 📍 CURRENT STATE
- **Rails**: 8.0.2.1 ✅
- **Ruby**: 3.3.9 ✅
- **Location**: `/Users/alippold/github/mitre/vulcan`
- **Tests**: 190 passing ✅
- **Linting**: All passing ✅

## 🔴 CRITICAL RAILS 8 ISSUES FOUND

### 1. **Turbolinks Still In Use** (MAJOR ISSUE)
**Problem**: Turbolinks is deprecated, Rails 8 uses Turbo/Hotwire

**Current Usage**:
```ruby
# Gemfile
gem 'turbolinks', '~> 5'

# package.json
"turbolinks": "^5.2.0"
"vue-turbolinks": "^2.1.0"
```

**Affected Files**:
- ALL Vue components use `TurbolinksAdapter`
- ALL JavaScript packs use `turbolinks:load` event
- Application layout uses `data-turbolinks-track`
- 13+ JavaScript files import vue-turbolinks

**LOE**: 8-16 hours for full migration

### 2. **Spring Gem** (Should Remove)
```ruby
# Gemfile - these should be removed
gem 'spring'
gem 'spring-watcher-listen'
```
Rails 8 has built-in reloader, Spring is deprecated.
**LOE**: 1 hour

### 3. **Minor Deprecations**:
- `config.fixture_paths` → `config.fixture_path` (singular)
- Migration versions use [6.0]/[6.1] (backward compatible, no action needed)

## 📋 NEXT STEPS PRIORITY

### Priority 1: Turbolinks → Turbo Migration
1. Replace `turbolinks` gem with `turbo-rails`
2. Replace `vue-turbolinks` with Turbo-compatible solution
3. Update all `turbolinks:load` → `turbo:load`
4. Update `data-turbolinks-track` → `data-turbo-track`
5. Test all Vue components still work

### Priority 2: Remove Spring
```bash
# Remove from Gemfile:
# gem 'spring'
# gem 'spring-watcher-listen'
bundle install
```

### Priority 3: Fix Minor Deprecations
```ruby
# spec/rails_helper.rb
# Change: config.fixture_paths = [...]
# To: config.fixture_path = Rails.root.join('spec/fixtures')
```

## 🔧 KEY TECHNICAL CONTEXT

### Request Specs Pattern
```ruby
# Must have in every request spec:
before do
  Rails.application.reload_routes!
end

# Use paths not symbols:
post '/stigs', params: { file: file }  # NOT post :create

# File uploads:
file = Rack::Test::UploadedFile.new(temp_file.path, 'application/xml')
```

### System Specs Pattern
```ruby
# rails_helper.rb needs:
config.include Devise::Test::IntegrationHelpers, type: :system
config.before(:each, type: :system) do
  driven_by :chrome
end

# okta_test_config.rb needs:
config.include OktaTestHelpers, type: :system
```

## 📂 PROJECT STRUCTURE
```
spec/
  ├── system/          # NEW - migrated from features/
  ├── requests/        # NEW - migrated from controllers/
  ├── models/
  └── support/
```

## 🚫 DELETED DIRECTORIES
- `spec/controllers/` - completely removed
- `spec/features/` - migrated to system/
- `spec/integration/` - migrated to system/

## 📝 DOCUMENTATION FILES (DO NOT COMMIT)
- DEPENDENCY-UPDATE-STRATEGY.md
- RECOVERY-JAN15-*.md files
- These are for development reference only

## MCP Memory Keys
```
mcp__server-memory__open_nodes with names:
["Vulcan Technical Learnings", "Dependency Updates January 2025", "Rails 8 Migration TODO"]
```

## Commands to Continue
```bash
# Check out the branch
git checkout security/dependency-updates-jan2025

# Run tests
bundle exec rspec

# Run linting
bundle exec rubocop
yarn lint

# Check for Turbolinks usage
grep -r "turbolinks\|Turbolinks" --include="*.rb" --include="*.js" --include="*.vue"
```

## Context at Compact: 0%