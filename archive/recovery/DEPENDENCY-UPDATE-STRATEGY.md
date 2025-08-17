# Dependency Update Strategy - January 2025

## Executive Summary
- **Total Outdated Packages**: 36 Ruby gems + 11 JavaScript packages
- **Security Vulnerabilities**: 63 reported by GitHub (mostly Vue 2/Bootstrap 4 related)
- **High-Risk Updates**: Rack ecosystem, Vue 2→3, Bootstrap 4→5
- **Low-Risk Updates**: Development tools, minor version bumps

## 🟢 Immediate Updates (Low Risk - Current Branch)
These can be done safely on the current `security/dependency-updates-jan2025` branch:

### Ruby Gems
- `factory_bot`: 5.2.0 → 6.5.4 (test only, backward compatible)
- `factory_bot_rails`: 5.2.0 → 6.5.0 (test only)
- `highline`: 2.1.0 → 3.1.2 (CLI tool)
- `mixlib-log`: 3.0.9 → 3.2.3 (logging)
- `unicode-display_width`: 2.6.0 → 3.1.5 (string handling)
- `wisper`: 2.0.1 → 3.0.0 (event broadcasting)

### JavaScript Packages
- `axios`: 1.6.8 → 1.11.0 (HTTP client, minor breaking changes to review)

## 🟡 Short-term Updates (Medium Risk - Separate PR)
**Timeline**: Next 2-4 weeks  
**Branch**: `chore/q1-2025-dependency-updates`

### Ruby Gems
- `faraday` ecosystem: 1.x → 2.x (HTTP client library)
  - `faraday`: 1.10.4 → 2.13.4
  - All faraday plugins need coordinated update
- `http-accept`: 1.7.0 → 2.2.1
- `json-jwt`: 1.15.3.1 → 1.17.0
- `rubyzip`: 2.4.1 → 3.0.1 (may have breaking changes)
- `tomlrb`: 1.3.0 → 2.0.3

### JavaScript Packages
- `monaco-editor`: 0.32.1 → 0.52.2 (code editor - test thoroughly)
- ESLint ecosystem (coordinate together):
  - `eslint`: 8.x → 9.x (major version)
  - `eslint-config-prettier`: 8.x → 10.x
  - `eslint-plugin-prettier`: 3.x → 5.x
  - `prettier`: 2.x → 3.x

## 🔴 Long-term Updates (High Risk - Major Projects)

### Phase 1: Bootstrap 5 Migration (Q1 2025)
**Branch**: `feature/bootstrap-5-migration`  
**Dependencies**:
- `bootstrap`: 4.6.2 → 5.3.7
- `bootstrap-vue`: INCOMPATIBLE - needs replacement
- Requires extensive template updates (utility classes changed)
- **Blocker for**: Many security vulnerabilities

### Phase 2: Vue 3 Migration (Q2 2025)
**Branch**: `feature/vue-3-migration`  
**Dependencies**:
- `vue`: 2.7.16 → 3.5.18
- `vue-loader`: 15.x → 17.x
- `vue-template-compiler`: Remove (not needed in Vue 3)
- All Vue plugins need updates/replacements
- **Blocker for**: Most remaining vulnerabilities

### Phase 3: Rack 3 Upgrade (Q2-Q3 2025)
**Branch**: `feature/rack-3-upgrade`  
**Dependencies**:
- `rack`: 2.2.17 → 3.2.0
- `rack-protection`: 3.2.0 → 4.1.1
- `rack-session`: 1.0.2 → 2.1.1
- `rack-oauth2`: 1.21.3 → 2.2.1
- `rackup`: 1.0.1 → 2.2.1
- Requires Rails compatibility check

### Phase 4: Testing Framework Updates (Q3 2025)
**Branch**: `chore/testing-updates`
- `rspec-rails`: 6.1.5 → 8.0.2
- `spring`: 2.1.1 → 4.4.0 (development server)
- `spring-watcher-listen`: 2.0.1 → 2.1.0

## 🔒 Version-Locked Dependencies
These are locked for specific reasons:

- `slack-ruby-client`: 1.0.0 (locked by Gemfile constraint)
- `omniauth_openid_connect`: 0.6.1 (locked to ~> 0.6.0 for compatibility)
- `puma`: 5.6.9 (locked to ~> 5.6, consider upgrading constraint)

## 📊 Risk Assessment

### Low Risk Updates
- Development/test dependencies
- Patch version updates
- Libraries with good backward compatibility

### Medium Risk Updates
- Minor version updates of core libraries
- HTTP client libraries (faraday)
- Development tooling (ESLint, Prettier)

### High Risk Updates
- Framework migrations (Bootstrap, Vue)
- Rack ecosystem (affects entire request pipeline)
- Breaking API changes

## 📋 Recommended Action Plan

### Week 1-2 (Current)
1. ✅ Complete current branch with safe updates
2. Test thoroughly in staging
3. Deploy to production

### Week 3-4
1. Create new branch for medium-risk updates
2. Update Faraday and related gems
3. Update development tools (ESLint, Prettier)
4. Run full test suite and manual testing

### Month 2-3
1. Begin Bootstrap 5 migration planning
2. Create migration guide for utility classes
3. Identify all affected components
4. Start incremental migration

### Month 4-6
1. Plan Vue 3 migration
2. Evaluate Rack 3 compatibility with Rails 8
3. Consider upgrading test frameworks

## ⚠️ Security Considerations

Current GitHub vulnerabilities (63 total):
- **5 Critical**: Mostly in Vue 2 ecosystem
- **12 High**: Bootstrap 4, Vue dependencies
- **35 Moderate**: Various npm packages
- **11 Low**: Development dependencies

Most vulnerabilities will be resolved by:
1. Bootstrap 5 migration (removes jQuery dependency)
2. Vue 3 migration (updates entire Vue ecosystem)

## 💡 Notes

- Always update related packages together (e.g., all Faraday gems)
- Run full test suite after each update group
- Consider using `bundle update --conservative` for Ruby updates
- Use `yarn upgrade-interactive` for controlled JS updates
- Monitor for Rails 8.1 compatibility before Rack 3 upgrade
- Keep `CLAUDE.md` updated with any new learnings

## 🔄 Update Commands Reference

```bash
# Ruby - conservative updates
bundle update --conservative [gem_name]

# Ruby - check specific gem compatibility
bundle update --conservative --strict [gem_name]

# JavaScript - interactive updates
yarn upgrade-interactive --latest

# JavaScript - specific package
yarn upgrade [package]@[version]

# Check for security issues
bundle exec bundle-audit check
yarn audit
```