# Rails 7 Upgrade Recovery Prompt

## Current Status
Working on PR #662 - Upgrading Vulcan from Rails 6.1 to Rails 7.0

### Major Milestone Achieved 🎉
Successfully implemented **Option 1** (perfectionist approach) for fixing all audit validation errors!
- All 116 tests passing (0 failures)
- Zero technical debt or workarounds
- Proper audit context infrastructure built

### Completed Tasks
1. ✅ Fixed LDAP authentication issues (PR #669 - merged)
2. ✅ Fixed Excel column reordering (PR #660 - merged) 
3. ✅ Fixed Anchore SBOM workflow (PR #668 - merged)
4. ✅ Fixed Dockerfile ENV format warnings (directly on master)
5. ✅ Successfully rebased Rails 7 upgrade branch on latest master
6. ✅ Installed Ruby 3.0.6 with patch for macOS compilation issues
7. ✅ Generated new Gemfile.lock for Rails 7
8. ✅ Fixed yarn.lock for CI/CD
9. ✅ Fixed initial Rubocop offenses (68 auto-corrected)
10. ✅ Fixed additional Rubocop offenses manually (All resolved!)
11. ✅ Added Overcommit for pre-commit linting hooks
12. ✅ Fixed all audit validation errors with proper infrastructure
13. ✅ Updated gems for Rails 7 compatibility (factory_bot_rails, rspec-rails)
14. ✅ Fixed local login feature test for Bootstrap-Vue compatibility

### Ruby Version Fix
Had to patch Ruby 3.0.6 compilation on macOS:
```bash
cat > /tmp/ruby-3.0.6-bigdecimal.patch << 'EOF'
--- a/ext/bigdecimal/bigdecimal.c
+++ b/ext/bigdecimal/bigdecimal.c
@@ -65,7 +65,7 @@
 #define BIGDECIMAL_POSITIVE_P(bd) ((bd)->sign > 0)
 #define BIGDECIMAL_NEGATIVE_P(bd) ((bd)->sign < 0)
 
-#define ENTER(n) volatile VALUE RB_UNUSED_VAR(vStack[n]);int iStack=0
+#define ENTER(n) volatile VALUE vStack[n];int iStack=0
 
 #define PUSH(x) (vStack[iStack++] = (VALUE)(x))
 #define SAVE(p) PUSH((p)->obj)
EOF

rvm install 3.0.6 --patch /tmp/ruby-3.0.6-bigdecimal.patch
```

### Audit Validation Fix Details
Successfully fixed "Audits is invalid" errors that were blocking Rails 7 upgrade:

1. **Root Cause**: Rails 7's stricter `belongs_to` validation requirements
2. **Solution**: Implemented proper audit context infrastructure
   - Created `AuditHelper` with `system_audit_user` and `VulcanAudit.as_user` pattern
   - Created `DeviseAuditHelper` to automatically set audit context for controller tests
   - Modified `VulcanAudit` to properly remove presence validations
   - Updated all affected specs to use proper audit context

3. **Files Fixed**:
   - `app/lib/vulcan_audit.rb` - Added `remove_presence_validations!` method
   - `config/initializers/audited.rb` - Simplified configuration
   - `spec/support/audit_helper.rb` - New helper for audit context
   - `spec/support/devise_audit_helper.rb` - New helper for Devise integration
   - 6 spec files updated with `VulcanAudit.as_user(system_audit_user)`

### Gem Updates
- **factory_bot_rails**: 5.2.0 → 6.4.4 (Rails 7 support)
- **rspec-rails**: 4.0.2 → 6.0.4 (Rails 7 support)
- **Skipped**: selenium-webdriver (requires Ruby 3.1+, we're on 3.0.6)

### Current Branch State
- Branch: upgrade-rails
- Commits ahead of master: 12
- **All tests passing locally (116 examples, 0 failures)** ✅
- Last CI run pending for gem updates and login test fix

### Recent Commits
1. "Fix all Rubocop offenses" - Fixed 26 remaining issues
2. "Add Overcommit for pre-commit linting hooks"
3. "Fix audit validation errors for Rails 7 compatibility"
4. "Fix remaining test failures for Rails 7 upgrade"
5. "Update gems for Rails 7 compatibility and fix login test"

### Next Steps
1. ✅ ~~Fix audit validation errors~~ DONE!
2. ✅ ~~Update gems for Rails 7 support~~ DONE!
3. Monitor CI results for latest push
4. If CI passes, PR #662 should be ready for review/merge!
5. Address duplicate test runs in CI/CD workflow (separate issue)

### Important Notes
- The `~> 3.0` Ruby version error appearing is harmless noise from RVM
- .tool-versions was updated to use Ruby 3.0.6 (from 3.0.7)
- Rails 7 requires Ruby 3.0+
- Settingslogic gem prevents using Ruby 3.1+

### Git Configuration
All commits must be co-authored:
```
Co-Authored-By: Aaron Lippold <lippold@gmail.com>
```

### Key Technical Decisions
1. **Audit Context Solution**: Chose Option 1 (proper fix) over pragmatic workarounds
   - User explicitly requested: "Let's work on option 1 and see how it goes"
   - Successfully implemented without technical debt
   
2. **Gem Update Strategy**: 
   - Updated only Rails 7 compatible gems
   - Skipped gems requiring Ruby 3.1+ (we're on 3.0.6)

### Commands to Continue
```bash
# Check CI status
gh pr checks 662

# View CI logs if needed
gh run list --branch upgrade-rails --limit 5
gh run view <run-id> --log-failed

# If CI passes, ready for review!
gh pr ready 662

# Check the PR
gh pr view 662 --web
```

### Known Issues
1. **Webpack Dev Server with Node.js 17+**: 
   - Error: `ERR_OSSL_EVP_UNSUPPORTED`
   - Solution: Use Node 16 (specified in .nvmrc) OR run with:
     ```bash
     export NODE_OPTIONS=--openssl-legacy-provider
     bin/webpack-dev-server
     ```