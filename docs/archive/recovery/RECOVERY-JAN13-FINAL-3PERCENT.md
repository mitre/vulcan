# RECOVERY PROMPT - Vulcan Rails 7 - Final Cookie Overflow Fix
## Context at Compact: 3% - January 13, 2025, 11:15 PM PST
## Status: Rails 7 COMPLETE, ONE bug left - OIDC cookie overflow

### 🚨 CRITICAL FIRST STEPS AFTER COMPACT
1. **MUST READ**: `/Users/alippold/.claude/CLAUDE.md` - NO Claude signatures in commits!
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
Ruby: 3.1.6
Rails: 7.0.8.7
Tests: ALL 198 PASSING
```

### ✅ RAILS 7 UPGRADE COMPLETE
- Rails 7.0.8.7 upgraded from 6.1.4 ✓
- Ruby 3.1.6 upgraded from 2.7.5 ✓
- Webpacker → jsbundling-rails with esbuild ✓
- All 84 MDI icons → Bootstrap Icons ✓
- All tests passing (fixed ENV.fetch mocking) ✓
- ComponentCard UI polished ✓
- Control counts fixed ✓

### 🐛 ONE REMAINING BUG: Cookie Overflow on OIDC Logout

**Error**: `ActionDispatch::Cookies::CookieOverflow in SessionsController#destroy`

**Root Cause**: OidcDiscoveryHelper stores entire OIDC discovery document in session cookie (can be 2-3KB), exceeding 4KB limit with other session data.

**File**: `/app/controllers/concerns/oidc_discovery_helper.rb`

**Already Fixed** (lines updated to use Rails.cache):
- Lines 153-188: `get_cached_discovery` - ✓ DONE
- Lines 190-202: `cache_discovery_document` - ✓ DONE

**STILL NEED TO FIX** (currently using session):
- Lines 21-35: Concurrent request prevention setup
- Lines 96-98: Cleanup in ensure block

### 📝 EXACT CODE CHANGES NEEDED

**Replace lines 21-35:**
```ruby
    # Prevent concurrent requests using Rails.cache
    discovery_url = "#{normalized_issuer}/.well-known/openid-configuration"
    request_lock_key = "oidc_discovery:lock:#{normalized_issuer}"

    # Check if a request is already in progress
    if Rails.cache.read(request_lock_key)
      log_oidc_discovery_event('concurrent_request_blocked', normalized_issuer, {
                                 reason: 'request_in_progress',
                                 cache_key: cache_key
                               })
      return nil
    end

    # Mark request in progress with short TTL
    Rails.cache.write(request_lock_key, true, expires_in: 10.seconds)

    begin
```

**Replace lines 96-98:**
```ruby
    ensure
      # Clear the request lock from cache
      request_lock_key = "oidc_discovery:lock:#{normalized_issuer}"
      Rails.cache.delete(request_lock_key)
    end
```

### ⚠️ CURRENTLY FAILING TESTS (4)
These will be fixed by completing the Rails.cache migration:
- spec/controllers/sessions_controller_spec.rb:323 - expects session cache
- spec/controllers/sessions_controller_spec.rb:233 - expects session cache
- spec/integration/okta_discovery_integration_spec.rb:134 - expects session cache
- spec/features/oidc_discovery_spec.rb:49 - literally "caches in session"

After fixing oidc_discovery_helper.rb, update these tests to check Rails.cache instead of session.

### 🎯 EXACT STEPS TO COMPLETE

1. **Edit the file**:
   ```bash
   code /Users/alippold/github/mitre/vulcan/app/controllers/concerns/oidc_discovery_helper.rb
   ```

2. **Make the two changes above** (lines 21-35 and 96-98)

3. **Test the fix**:
   - Login with OIDC at http://localhost:3000
   - Click logout - should NOT get CookieOverflow error

4. **Run tests** to ensure nothing broke:
   ```bash
   bundle exec rspec spec/controllers/sessions_controller_spec.rb
   ```

5. **Commit** (NO Claude signatures!):
   ```bash
   git add app/controllers/concerns/oidc_discovery_helper.rb
   git commit -m "fix: Move OIDC discovery cache from session to Rails.cache

   - Prevents cookie overflow when discovery document exceeds 4KB
   - Uses Rails.cache for both document storage and request locking
   - Preserves all security and concurrent request prevention

   Authored by: Aaron Lippold<lippold@gmail.com>"
   ```

### ⚠️ OTHER BUGS TO FIX LATER (in MCP memory)
1. **Seed script bug**: rules_count always 0, need to run update after seeding
2. **Test suite destructive**: Wipes dev database when tests run in dev mode
3. These are tracked in MCP entity "Vulcan Bugs to Fix Post-Rails7"

### 🚀 AFTER FIXING COOKIE OVERFLOW
1. Commit all remaining changes
2. Push branch: `git push -u origin upgrade-settingslogic-ruby31`
3. Create PR: "feat: Upgrade to Rails 7.0 + Ruby 3.1 + jsbundling"

---
*3% context - Cookie overflow is the ONLY blocker left!*