# Recovery Context - January 15, 2025 - Dependency Updates Session 2

## CRITICAL - READ FIRST
**ALWAYS READ**: `/Users/alippold/.claude/CLAUDE.md` - User's STRICT preferences including:
- **NEVER use `git add -A` or `git add .`** - ALWAYS add files individually
- **WE DO NOT COMMIT BROKEN CODE EVER** - all tests and linting must pass
- Git commits use: `Authored by: Aaron Lippold<lippold@gmail.com>` - NO Claude signatures
- Find and fix ROOT CAUSES, never work around problems
- **ALWAYS use rm -f flag** when deleting files to avoid prompts
- **Use YARN for JavaScript, NOT npm**

## Current State - 3% Context
- **Location**: `/Users/alippold/github/mitre/vulcan`
- **Branch**: `security/dependency-updates-jan2025` (3 commits, NOT pushed)
- **Base**: Rails 8.0.2.1, Ruby 3.3.9, Node.js 22 LTS
- **Tests**: 195 of 198 passing (3 StigsController tests failing)
- **Issue**: factory_bot 6 upgrade causing Devise mapping errors in controller tests

## What We Just Completed

### ✅ Successfully Updated
1. **JavaScript Security Fixes**:
   - axios: 1.6.8 → 1.11.0 (fixes 2 HIGH SSRF vulnerabilities!)
   - eslint: 8.x → 9.33.0
   - prettier: 2.8.8 → 3.6.2
   - eslint-config-prettier: 8.x → 10.1.8

2. **Ruby Gems**:
   - factory_bot: 5.2.0 → 6.5.4
   - factory_bot_rails: 5.2.0 → 6.5.0
   - chef-config & chef-utils: 18.7.10 → 18.8.11
   - multi_xml: 0.7.1 → 0.7.2
   - bundler-audit: Added for security scanning

3. **MDI to Bootstrap Icons Migration**:
   - Removed @mdi/font package completely
   - Updated NavbarItem.vue: `<i class="mdi">` → `<b-icon>`
   - Updated application_helper.rb with Bootstrap icon names
   - Removed dead code: releaseComponentClasses in ComponentCard.vue
   - Icons working: folder2-open, patch-check-fill, clipboard-check, clipboard, hourglass-split

## 🔴 Current Test Failures (Must Fix)

**File**: `spec/controllers/stigs_controller_spec.rb`
**Issue**: factory_bot 6 Devise mapping errors
**Error**: `Could not find a valid mapping for #<User...>`

**Already Fixed in**: `spec/controllers/registrations_controller_spec.rb`
- Added `@request.env['devise.mapping'] = Devise.mappings[:user]` in before block

**Attempted Fix**: Added same line to StigsController before block but still failing
**Next Debug Steps**:
1. Check if mapping is being preserved across test setup
2. May need to set mapping differently for factory_bot 6
3. Check if Users module include is needed

## Files Modified (Not Committed Yet)

```bash
# Modified files in staging:
- Gemfile (added bundler-audit, updated factory_bot_rails version)
- Gemfile.lock (all gem updates)
- package.json (JavaScript package updates)
- yarn.lock (JavaScript dependency updates)
- app/helpers/application_helper.rb (Bootstrap icons)
- app/javascript/components/navbar/NavbarItem.vue (b-icon component)
- app/javascript/components/components/ComponentCard.vue (removed dead code)
- spec/controllers/registrations_controller_spec.rb (Devise mapping fix)
- spec/controllers/stigs_controller_spec.rb (attempted Devise mapping fix - FAILING)

# New files created:
- DEPENDENCY-UPDATE-STRATEGY.md (complete update plan)
- RECOVERY-JAN15-DEPENDENCIES.md (earlier recovery)
```

## Git Status

```bash
# 3 commits on branch (not pushed):
1. Ruby gem updates (regexp_parser, mime-types-data, selenium-webdriver)
2. JavaScript dependency updates (Rails packages, esbuild, eslint-config-prettier)
3. MDI to Bootstrap icon migration and more dependency updates

# Current uncommitted changes:
- All the dependency updates from this session
- Test fixes (partial - StigsController still failing)
```

## Next Immediate Actions

1. **Fix StigsController tests**:
   - Debug why Devise mapping isn't working
   - May need different approach for factory_bot 6
   - Once fixed, commit all changes

2. **Push branch and create PR**:
   - Push security/dependency-updates-jan2025
   - Create PR with all dependency updates

3. **Continue Updates** (if time):
   - Try Faraday 2.x update again (may need to update oauth2)
   - Update more safe Ruby gems
   - Consider Monaco Editor update

## Blocked Updates (Need Major Work)

- **Faraday 1.x → 2.x**: Blocked by oauth2/other dependencies
- **Bootstrap 4 → 5**: Requires template migration (Phase 1 of roadmap)
- **Vue 2 → 3**: Requires component rewrites (Phase 2 of roadmap)
- **Rack 2.x → 3.x**: May need Rails 8.1 compatibility

## Key Learnings This Session

1. factory_bot 6 has breaking changes with Devise controller tests
2. Yarn doesn't accept caret (^) in version specifications for upgrade
3. MDI icons were only partially used - easy to migrate to Bootstrap icons
4. axios 1.11.0 fixes critical SSRF vulnerabilities
5. ESLint 9 and Prettier 3 work fine with existing config

## Testing Commands

```bash
# Run only StigsController tests (currently failing):
bundle exec rspec spec/controllers/stigs_controller_spec.rb

# Run all tests:
bundle exec rspec --format progress

# Check for Ruby vulnerabilities:
bundle exec bundle-audit check

# Check JavaScript vulnerabilities:
yarn audit

# Build JavaScript:
yarn build
```

## MCP Memory Keys
```
mcp__server-memory__open_nodes with names:
["Vulcan Technical Learnings", "Dependency Updates January 2025"]
```