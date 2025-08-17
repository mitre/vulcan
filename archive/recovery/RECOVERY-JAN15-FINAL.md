# Recovery Context - January 15, 2025 - Vulcan Dependency Updates & Rails 8 Spec Migration

## 🔴 CRITICAL - READ FIRST
**ALWAYS READ**: `/Users/alippold/.claude/CLAUDE.md` and `/Users/alippold/github/mitre/vulcan/CLAUDE.md`
- **NEVER use `git add -A` or `git add .`** - ALWAYS add files individually
- **WE DO NOT COMMIT BROKEN CODE EVER** - all tests and linting must pass
- **Use YARN for JavaScript, NOT npm**
- **Git commits use**: `Authored by: Aaron Lippold<lippold@gmail.com>` - NO Claude signatures
- **ALWAYS use `rm -f` when deleting files** to avoid prompts

## ✅ COMPLETED WORK

### Dependency Updates
- **axios**: 1.6.8 → 1.11.0 (fixes SSRF vulnerabilities) ✅
- **factory_bot**: 5.2.0 → 6.5.4 ✅
- **ESLint**: 8.x → 9.33.0 ✅
- **Prettier**: 2.8.8 → 3.6.2 ✅
- **bundler-audit**: Added for security scanning ✅
- **MDI icons**: Fully migrated to Bootstrap icons ✅

### Rails 8 Controller Spec Migration
- **Problem**: Rails 8 lazy route loading completely breaks controller specs
- **Solution**: Migrated all 4 controller specs to request specs
- **Result**: All 190 tests passing ✅

### Files Changed
```bash
# Deleted (old controller specs)
- spec/controllers/stigs_controller_spec.rb
- spec/controllers/registrations_controller_spec.rb
- spec/controllers/sessions_controller_spec.rb
- spec/controllers/project_access_requests_controller_spec.rb

# Created (new request specs)
+ spec/requests/stigs_spec.rb
+ spec/requests/registrations_spec.rb
+ spec/requests/sessions_spec.rb
+ spec/requests/project_access_requests_spec.rb

# Modified
- spec/rails_helper.rb (added IntegrationHelpers for request specs)
- Gemfile & Gemfile.lock (dependency updates)
- package.json & yarn.lock (JS dependency updates)
```

## 📍 CURRENT STATE
- **Branch**: `security/dependency-updates-jan2025`
- **Commits**: 4 commits ready, NOT pushed yet
- **Tests**: All 190 passing
- **Location**: `/Users/alippold/github/mitre/vulcan`

## 🔧 KEY TECHNICAL LEARNINGS

### Rails 8 Request Specs
1. **Must add in every request spec**:
   ```ruby
   before do
     Rails.application.reload_routes!
   end
   ```

2. **Use path strings not symbols**:
   ```ruby
   # OLD: post :create
   # NEW: post '/stigs'
   ```

3. **File uploads**:
   ```ruby
   file = Rack::Test::UploadedFile.new(temp_file.path, 'application/xml')
   post '/stigs', params: { file: file }
   ```

4. **Devise helpers**:
   ```ruby
   config.include Devise::Test::IntegrationHelpers, type: :request
   ```

## 📋 NEXT STEPS - Test Modernization

### Priority 1: Remove `any_instance_of` (4 occurrences)
- `spec/requests/sessions_spec.rb` lines 89, 133
- `spec/models/user_authentication_edge_cases_spec.rb` lines 35, 241

### Priority 2: Migrate Feature → System Specs
- `spec/features/local_login_spec.rb`
- `spec/features/ldap_login_spec.rb`
- `spec/features/oidc_discovery_spec.rb`
- `spec/integration/okta_discovery_integration_spec.rb`

### Priority 3: Replace DatabaseCleaner
- Consider using `config.use_transactional_fixtures = true`

## 🚀 READY TO SHIP
```bash
# The branch is ready to push and create PR:
git push -u origin security/dependency-updates-jan2025

# Create PR with message:
# "Update dependencies and migrate controller specs to request specs
#  - Critical security updates (axios, factory_bot, ESLint, Prettier)
#  - Rails 8 compatibility: migrate controller → request specs
#  - All 190 tests passing"
```

## 📝 DOCUMENTATION FILES (DO NOT COMMIT)
These files exist but should NOT be added to git:
- DEPENDENCY-UPDATE-STRATEGY.md
- RECOVERY-JAN15-DEPENDENCIES.md
- RECOVERY-JAN15-DEPS-SESSION2.md
- RECOVERY-JAN15-RAILS8-CONTROLLER-SPECS.md
- RECOVERY-JAN15-TEST-MODERNIZATION.md
- RECOVERY-JAN15-FINAL.md (this file)

## MCP Memory Keys
```
mcp__server-memory__open_nodes with names:
["Vulcan Technical Learnings", "Dependency Updates January 2025"]
```

## Context Percentage at Compact: 3%