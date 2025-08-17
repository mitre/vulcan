# Recovery Context - January 15, 2025 - Rails 8 Controller Spec Migration

## 🔴 CRITICAL - READ FIRST
**ALWAYS READ**: `/Users/alippold/.claude/CLAUDE.md` - User's STRICT preferences including:
- **NEVER use `git add -A` or `git add .`** - ALWAYS add files individually
- **WE DO NOT COMMIT BROKEN CODE EVER** - all tests and linting must pass
- Git commits use: `Authored by: Aaron Lippold<lippold@gmail.com>` - NO Claude signatures
- Find and fix ROOT CAUSES, never work around problems
- **Use YARN for JavaScript, NOT npm**

## Current State at Compact (1% Context)
- **Location**: `/Users/alippold/github/mitre/vulcan`
- **Branch**: `security/dependency-updates-jan2025` (3 commits, NOT pushed)
- **Base**: Rails 8.0.2.1, Ruby 3.3.9, Node.js 22 LTS
- **Tests**: 179 of 195 passing (16 controller spec failures due to Rails 8)
- **Root Issue**: Rails 8 lazy route loading completely breaks controller specs

## 🚨 The Rails 8 Controller Spec Problem

### What Happened
Rails 8 introduced **lazy route loading** via `Rails::Engine::LazyRouteSet` for performance. This fundamentally breaks controller specs when combined with:
- Devise authentication
- factory_bot 6
- File uploads or complex parameters

### The Error Pattern
```
ActionController::UrlGenerationError:
  No route matches {:action=>"create", :controller=>"stigs", ...}
# railties-8.0.2.1/lib/rails/engine/lazy_route_set.rb:59:in `generate_extras'
```

### Why It's Broken
1. Controller specs use different routing mechanism than request specs
2. Lazy loading doesn't properly initialize for controller test contexts
3. `generate_extras` in lazy_route_set.rb can't match routes that haven't loaded
4. Devise's test helpers compound the problem by wrapping the `process` method

### What We Tried (All Failed)
- ✗ Added `Rails.application.reload_routes!` to rails_helper.rb
- ✗ Created `config/initializers/devise_rails8_patch.rb` with Devise.mappings fix
- ✗ Added `include Users` module to specs
- ✗ Used `routes { Rails.application.routes }` in specs
- ✗ Tried `process` method directly instead of `post`/`delete`
- ✗ Attempted various file upload approaches (Rack::Test, ActionDispatch::Http)

## ✅ Successfully Updated Dependencies

### JavaScript (via yarn)
- axios: 1.6.8 → 1.11.0 (fixes 2 HIGH SSRF vulnerabilities!)
- eslint: 8.x → 9.33.0
- prettier: 2.8.8 → 3.6.2
- eslint-config-prettier: 8.x → 10.1.8
- @rails/actioncable & @rails/activestorage → 8.x
- esbuild → 0.25.0

### Ruby Gems
- factory_bot: 5.2.0 → 6.5.4
- factory_bot_rails: 5.2.0 → 6.5.0
- chef-config & chef-utils → 18.8.11
- multi_xml → 0.7.2
- bundler-audit: Added for security scanning
- Various other minor updates

### Completed Work
- ✅ MDI to Bootstrap icon migration (removed @mdi/font completely)
- ✅ Updated NavbarItem.vue to use `<b-icon>` component
- ✅ Removed dead code in ComponentCard.vue
- ✅ Created DEPENDENCY-UPDATE-STRATEGY.md with full plan

## 🔴 Failing Tests (16 Controller Specs)

All failing with `ActionController::UrlGenerationError`:
- `spec/controllers/stigs_controller_spec.rb` (3 failures)
- `spec/controllers/registrations_controller_spec.rb` (8 failures)
- `spec/controllers/sessions_controller_spec.rb` (4 failures)
- `spec/controllers/project_access_requests_controller_spec.rb` (4 failures)

## 📋 Next Steps After Compact

### Immediate Priority: Controller → Request Spec Migration
Controller specs are **effectively dead in Rails 8**. The Rails team's position: use request specs.

1. **Migrate all controller specs to request specs**:
   ```ruby
   # OLD (broken in Rails 8)
   RSpec.describe StigsController, type: :controller do
     post :create, params: { file: file }

   # NEW (Rails 8 compatible)
   RSpec.describe 'Stigs', type: :request do
     post '/stigs', params: { file: file }
   ```

2. **Key differences for migration**:
   - Use path strings instead of action symbols
   - Use `Devise::Test::IntegrationHelpers` not `ControllerHelpers`
   - File uploads use `fixture_file_upload` not mock objects
   - No direct controller access - test through HTTP interface

3. **After migration complete**:
   - Commit all dependency updates
   - Push `security/dependency-updates-jan2025` branch
   - Create PR with all updates

### Files Modified (Uncommitted)
```bash
# Core fixes
- config/initializers/devise_rails8_patch.rb (NEW - Devise Rails 8 fix)
- spec/rails_helper.rb (Rails 8 route loading fix)

# Dependency updates
- Gemfile & Gemfile.lock (gem updates)
- package.json & yarn.lock (JavaScript updates)

# Icon migration
- app/helpers/application_helper.rb
- app/javascript/components/navbar/NavbarItem.vue
- app/javascript/components/components/ComponentCard.vue

# Documentation
- DEPENDENCY-UPDATE-STRATEGY.md
- RECOVERY-JAN15-DEPENDENCIES.md
- RECOVERY-JAN15-DEPS-SESSION2.md
```

## Testing Commands
```bash
# Run tests excluding broken controller specs
bundle exec rspec --exclude-pattern "spec/controllers/**/*_spec.rb"

# Check vulnerabilities
bundle exec bundle-audit check
yarn audit

# Linting
bundle exec rubocop
yarn lint
```

## MCP Memory Keys
```
mcp__server-memory__open_nodes with names:
["Vulcan Technical Learnings", "Dependency Updates January 2025"]
```

## Key Learnings
1. **Rails 8 breaks controller specs** - This is not a bug, it's the new reality
2. Controller specs have been soft-deprecated since Rails 5
3. The community solution: migrate to request specs
4. Don't fight the framework - follow Rails patterns
5. factory_bot 6 + Devise + Rails 8 = incompatible with controller specs

## The Path Forward
The Rails community has moved on from controller specs. Rails 8 makes this migration mandatory. We need to follow the community pattern and migrate all controller specs to request specs to unblock our dependency updates.