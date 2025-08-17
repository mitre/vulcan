# Test Modernization Recommendations - Rails 8 - January 15, 2025

## Current State
- ✅ All controller specs migrated to request specs
- ✅ All 190 tests passing
- ✅ Dependencies updated
- Branch: `security/dependency-updates-jan2025` (4 commits, ready to push)

## Test Modernization TODO for Next Session

### 1. Remove `any_instance_of` Anti-pattern (Priority: HIGH)
**Files to fix:**
- `spec/requests/sessions_spec.rb` (lines 89, 133)
- `spec/models/user_authentication_edge_cases_spec.rb` (lines 35, 241)

**Example fix:**
```ruby
# Instead of:
allow_any_instance_of(SessionsController).to receive(:session).and_return({ id_token: 'fake-id-token' })

# Use instance double or more specific stubbing
```

### 2. Migrate Feature Specs to System Specs (Priority: MEDIUM)
**Files to migrate:**
- `spec/features/local_login_spec.rb`
- `spec/features/ldap_login_spec.rb`
- `spec/features/oidc_discovery_spec.rb`
- `spec/integration/okta_discovery_integration_spec.rb`

System specs use real browser (headless Chrome) and are the Rails 5.1+ standard.

### 3. Replace DatabaseCleaner (Priority: LOW)
Current setup uses DatabaseCleaner gem. Rails 5.1+ has better built-in transaction handling.
- Consider using `config.use_transactional_fixtures = true`
- Remove DatabaseCleaner dependency

### 4. Add Rails 8 Test Helpers (Priority: MEDIUM)
- `assert_enqueued_email_with` for ActionMailer
- `assert_no_changes` for data integrity
- Better parallel testing support

### 5. Update WebMock Configuration (Priority: LOW)
Move from global WebMock to test-specific enabling for performance.

### 6. Future: Turbo/Stimulus Testing
If adopting Hotwire, will need proper Turbo frame/stream test coverage.

## Commands to Continue
```bash
# Check out the branch
git checkout security/dependency-updates-jan2025

# Run tests
bundle exec rspec

# When ready to push
git push -u origin security/dependency-updates-jan2025
```

## Key Files Modified in This Session
- Deleted: `spec/controllers/*` (4 files)
- Created: `spec/requests/*` (4 files)
- Modified: `spec/rails_helper.rb` (added reload_routes!)
- Updated: `Gemfile`, `package.json` (dependencies)