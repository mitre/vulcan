# RECOVERY PROMPT - Vulcan Rails 7 Upgrade - Cookie Overflow Fix
## Context at Compact: 11% - January 13, 2025, 10:45 PM PST
## Status: Rails 7 COMPLETE, fixing OIDC cookie overflow issue

### 🚨 CRITICAL FIRST STEPS AFTER COMPACT
1. **MUST READ**: `/Users/alippold/.claude/CLAUDE.md` - User's STRICT preferences (NO Claude signatures!)
2. **MUST READ**: `/Users/alippold/github/mitre/vulcan/CLAUDE.md` - Project context and conventions
3. **CHECK MCP**: Run `mcp__server-memory__open_nodes` with name "Vulcan Rails 7 Upgrade"
4. **CHECK BRANCH**: Should be on `upgrade-settingslogic-ruby31`
5. **SERVER STATUS**: Running at localhost:3000 with `foreman start -f Procfile.dev`

### 📍 CURRENT STATE
```bash
pwd: /Users/alippold/github/mitre/vulcan
branch: upgrade-settingslogic-ruby31
server: http://localhost:3000 (running)
login: admin@example.com / 1234567ab!
Ruby: 3.1.6 (have 3.3.6 and 3.4.5 installed but not tested)
Rails: 7.0.8.7
Tests: ALL 198 PASSING! 
```

### ✅ WHAT'S COMPLETE
1. **Rails 7.0.8.7** - Fully upgraded from 6.1.4
2. **Ruby 3.1.6** - Upgraded from 2.7.5
3. **jsbundling-rails** - Migrated from Webpacker with esbuild
4. **All tests passing** - Fixed ENV.fetch mocking issues
5. **UI improvements** - ComponentCard.vue polished
6. **Control count bug** - Fixed (was showing 0, now shows actual count)
7. **Old Webpacker artifacts** - Removed

### 🔧 UNCOMMITTED CHANGES
```
M app/javascript/components/components/ComponentCard.vue  # UI improvements
M app/views/components/show.html.haml                     # Fixed v-bind error
M config/environments/test.rb                             # Added perform_deliveries
M spec/lib/oidc_startup_validator_spec.rb                 # Fixed ENV.fetch mocking
M spec/controllers/sessions_controller_spec.rb            # Fixed ENV.fetch mocking
M app/controllers/concerns/oidc_discovery_helper.rb       # PARTIAL fix for cookie overflow
```

### 🐛 ACTIVE BUG: Cookie Overflow on OIDC Logout

**Problem**: ActionDispatch::Cookies::CookieOverflow when logging out with OIDC
- Session cookie exceeds 4KB limit
- OidcDiscoveryHelper stores entire OIDC discovery document in session

**Root Cause** (line numbers):
- `/app/controllers/concerns/oidc_discovery_helper.rb:204` - `session[cache_key] = config`
- `/app/controllers/concerns/oidc_discovery_helper.rb:153-188` - `get_cached_discovery` reads from session
- `/app/controllers/concerns/oidc_discovery_helper.rb:25-35` - Concurrent request tracking in session

**Solution Started (Option B chosen)**:
1. Move discovery document cache from `session` to `Rails.cache`
2. Use `Rails.cache` for concurrent request prevention too
3. Already updated `get_cached_discovery` (lines 153-188)
4. Already updated `cache_discovery_document` (lines 190-202)
5. **STILL NEED**: Update concurrent request prevention (lines 21-35 and 96-98)

### 📝 CODE TO COMPLETE COOKIE OVERFLOW FIX

```ruby
# Replace lines 21-35 in oidc_discovery_helper.rb:
    discovery_url = "#{normalized_issuer}/.well-known/openid-configuration"
    
    # Use Rails.cache for concurrent request prevention
    request_lock_key = "oidc_discovery:lock:#{normalized_issuer}"
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

# Also remove line 96-98:
    ensure
      # Clear the request lock
      Rails.cache.delete(request_lock_key)
    end
```

### 🎯 NEXT STEPS (in order)
1. **Complete cookie overflow fix** - Update concurrent request prevention
2. **Test OIDC logout** - Verify no more CookieOverflow error
3. **Run tests** - Ensure nothing broke with Rails.cache changes
4. **Commit all changes** - Remember: NO Claude signatures, use "Authored by: Aaron Lippold<lippold@gmail.com>"
5. **Test Ruby 3.3** - Quick compatibility check
6. **Push and create PR** - Title: "feat: Upgrade to Rails 7.0 + Ruby 3.1 + jsbundling"

### 💡 KEY LEARNINGS
- ENV.fetch vs ENV[] mocking - must mock both in tests
- mitre-settingslogic works fine - no behavior changes
- Session cookies have 4KB limit - use Rails.cache for large data
- Bootstrap Icons doesn't have rocket-takeoff, use tag icon for release

### 🚀 RECOVERY COMMAND SEQUENCE
```bash
# Verify state
cd /Users/alippold/github/mitre/vulcan
git status
git log --oneline -3

# Check server
ps aux | grep puma | head -1

# Continue fixing cookie overflow
code app/controllers/concerns/oidc_discovery_helper.rb
# Update lines 21-35 and 96-98 as shown above

# Test the fix
# 1. Navigate to http://localhost:3000
# 2. Login with OIDC
# 3. Logout - should not get CookieOverflow

# Run tests
bundle exec rspec

# When ready to commit
git add -A
git commit -m "fix: Move OIDC discovery cache from session to Rails.cache to prevent cookie overflow

- Session cookies limited to 4KB were overflowing with large discovery documents
- Moved discovery document caching to Rails.cache with 1 hour TTL
- Moved concurrent request prevention to Rails.cache with 10 second TTL
- Preserves all security and functionality from original implementation

Authored by: Aaron Lippold<lippold@gmail.com>"
```

### ⚡ CRITICAL REMINDERS
1. **NO CLAUDE SIGNATURES** in commits
2. Rails 7 upgrade is COMPLETE and working
3. Only issue is cookie overflow - solution 80% done
4. All tests passing after mocking fixes
5. User prefers Python/Ruby over sed for text processing
6. Fix root causes, no workarounds

---
*Recovery document prepared at 11% context for post-compact continuity*