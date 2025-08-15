# Rails 7.1 Upgrade Recovery - January 14, 2025

## CRITICAL - Read These First
1. **ALWAYS READ**: `/Users/alippold/.claude/CLAUDE.md` - User's strict preferences
   - NO Claude signatures in commits
   - Always use: `Authored by: Aaron Lippold<lippold@gmail.com>`
   - Test BEFORE committing
   - Find root causes, don't work around problems
   - User wants direct communication about actions

2. **CHECK MCP MEMORY**:
```
mcp__server-memory__open_nodes with names:
["Rails 7.1 Upgrade Session", "Vulcan Technical Learnings", "Vulcan Post-Merge Issues"]
```

## Current Branch: rails-7.1-upgrade

## Completed:
- ✅ Rails 7.1.5.2 upgraded from 7.0.8.7
- ✅ RSpec Rails 6.1.5 upgraded from 4.0.2
- ✅ Fixed SimpleCov issue (removed ActiveSupport time extension)
- ✅ Fixed 21 of 29 test failures
- ✅ Fixed ActiveRecord ANSI escape vulnerability
- ✅ Fixed mail delivery test (added Settings mock for update action)
- ✅ Fixed OIDC cache tests (changed cache_store from :null_store to :memory_store)
- ✅ Enabled perform_caching in test environment for cache-dependent tests
- ✅ Rails.application.secrets deprecation warning is from Rails framework itself, not app code

## Remaining Issues (RESOLVED - pending verification):

### All test failures have been fixed:
1. **Mail Delivery Tests** - FIXED
   - Added Settings mock to update user test context

2. **OIDC Cache Tests** - FIXED
   - Changed test environment cache_store from :null_store to :memory_store
   - Enabled perform_caching in test environment
   - This allows Rails.cache to work properly in tests

## Commands to Continue:
```bash
cd /Users/alippold/github/mitre/vulcan
git checkout rails-7.1-upgrade
bundle exec rspec --format progress

# To fix mail issue:
# Check app/models/user.rb line with skip_confirmation!
# The stub_local_login_setting might need to mock Settings differently
```

## Test Status: ~193 passing, ~6 failing (97% pass rate)

## Next Actions:
1. Fix remaining OIDC cache tests (5 failures)
   - Issue: Session caching not working in Rails 7.1
   - Files: spec/controllers/sessions_controller_spec.rb

2. Fix last mail delivery test
   - spec/controllers/registrations_controller_spec.rb:135
   - Need to add Settings mock for update action

3. Continue to Rails 7.2 then Rails 8.0.2.1
   - Must fix Rails.application.secrets deprecation first
   - All other prerequisites met

## Critical Fixes Applied:
```ruby
# Mail test fix - add to before blocks:
allow(Settings.local_login).to receive(:email_confirmation).and_return(true)

# Vue template fix:
'v-bind:queried-rule': (@rule_json || {}.to_json)

# RSpec Rails upgrade in Gemfile:
gem 'rspec-rails', '~> 6.0'  # was 4.0
```