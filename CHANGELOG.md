# Changelog

All notable changes to Vulcan will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v2.2.2] - 2026-02-08

### Upgraded
- Ruby 3.4.8 (from 3.3.9) with nkf gem for compatibility
- Puma 7.2.0 (from 5.6.9) for Heroku Router 2.0 compatibility
- Added parallel_tests for faster CI execution

### Added
- Global search infrastructure with pg_search gem and query transformation
- Unified multi-stage Dockerfile with CLI and improved .dockerignore
- Admin bootstrap with first-user-admin and env var support
- Health check endpoints for Kubernetes and Docker deployments
- DB_SUFFIX environment variable for worktree database isolation
- Command bars for view and edit pages
- Redesigned MembersModal with tabbed interface
- UnifiedRuleForm replacing Basic and Advanced forms
- CSV export with configurable column picker
- Severity filter buttons as connected button group with CAT I/II/III labels
- Postel's Law applied to satisfaction parsing and session timeout config
- Vitest testing infrastructure for Vue 2 components
- Centralized terminology constants (BENCHMARK_TERM, EXPORT_FORMATS)
- VitePress documentation system replacing MkDocs
- Mermaid diagram support in documentation
- Custom Vulcan branding with SVG logos and Media Kit page
- Comprehensive import/export and deployment documentation

### Changed
- Documentation navigation reorganized with Deployment, Authentication, and Security sections
- Documentation dependencies isolated from main application
- CI workflow uses parallel_rspec instead of serial rspec

### Fixed
- Nested attributes not saving in rules controller (#692)
- Also Satisfies resetting parent rule status
- Vue reactivity for satisfied_by relationship field visibility
- SRG search result links to use /srgs/ route
- Database config with DATABASE_URL support
- Consolidate Devise modules into single call in User model
- All ESLint errors and warnings resolved (20 errors, 6 warnings to 0)
- Documentation build issues with dead links and localhost URLs
- Remove dangerous DISABLE_DATABASE_ENVIRONMENT_CHECK from Docker entrypoint
- Fix Heroku review app postdeploy to use DISABLE_DATABASE_ENVIRONMENT_CHECK with db:schema:load
- Add db:seed and admin:bootstrap to review app postdeploy for usable review apps
- Resolve 10 Copilot-identified bugs (modulo-by-zero, YAML.safe_load, CSS vars, prop types)

### Security
- Updated rexml and rack gems (CVE-2025-58767, GHSA-625h)
- Configurable SSL for Docker deployments (#700, #702)
- Enhanced deployment security configurations
- YAML.safe_load replaces YAML.load_file in SearchAbbreviationService
- Database deployment safety regression tests (13 tests) prevent future misconfigurations

## [v2.2.1] - 2025-08-16

### Changed
- Improved Heroku Review App deployment configuration
- Enhanced Kubernetes deployment examples with better security practices
- Strengthened environment validation in utility scripts

### Fixed
- Email template accessibility improvements (added missing HTML attributes)
- Deployment configuration issues in app.json
- Minor formatting issues in Kubernetes YAML examples

### Security
- Enhanced deployment security configurations
- Improved environment checks for utility scripts

## [v2.2.0] - 2025-08-16

This release represents a major modernization of the Vulcan platform, bringing it up to the latest versions of Ruby, Rails, and Node.js while significantly improving performance, security, and developer experience.

### 🚀 Major Upgrades

#### Framework Modernization
- **Rails 8.0.2.1**: Complete upgrade from Rails 7.0.8.7 through progressive path (7.0 → 7.1 → 7.2 → 8.0)
- **Ruby 3.3.9**: Upgraded from Ruby 3.1.6 for improved performance and memory efficiency
- **Node.js 22 LTS**: Modernized from Node.js 16 for better JavaScript tooling support
- **esbuild**: Migrated from Webpacker for 10x faster JavaScript builds

#### Test Suite Overhaul ([#683](https://github.com/mitre/vulcan/pull/683))
- Migrated all controller specs to request specs (Rails 8 requirement)
- Migrated all feature specs to system specs (Rails 5.1+ standard)
- Removed anti-patterns like `any_instance_of` 
- Fixed Devise authentication with Rails 8 lazy route loading
- All 190 tests passing with improved performance

#### Docker & Container Optimization
- **Image size reduced by 73%**: From 6.5GB to 1.76GB
- **Memory usage reduced by 20-40%** using jemalloc
- Multi-stage builds for improved security
- Full support for corporate SSL certificates
- Container-friendly JSON structured logging

### 🛡️ Security Improvements

- **Critical fixes**:
  - SQL injection vulnerability in `Component#duplicate_rules` fixed with parameterized queries
  - Mass assignment vulnerabilities resolved with Rails 8 `expect` API
  - All Rails 8 deprecation warnings resolved

- **Dependency updates**:
  - axios: 1.6.8 → 1.11.0 (fixes SSRF vulnerabilities)
  - factory_bot: 5.2.0 → 6.5.4
  - ESLint: 8.x → 8.57.1
  - Prettier: 2.8.8 → 3.6.2
  - Added bundler-audit for vulnerability scanning

### ✨ New Features

#### OIDC Auto-Discovery
- Automatic endpoint configuration from provider metadata
- Support for Okta, Auth0, Keycloak, Azure AD
- Configuration reduced from 8+ to just 4 environment variables
- Session-based caching with 1-hour TTL

#### Enhanced Developer Experience
- Comprehensive environment variable documentation
- Automatic secret generation script (`setup-docker-secrets.sh`)
- Production-ready Docker Compose configurations
- SonarCloud integration for code quality

### 🐛 Bug Fixes

- Fixed 'Applicable - Configurable' status field display issue ([#684](https://github.com/mitre/vulcan/pull/684))
- Fixed overlay component seed data rule counts
- Fixed Vue template compilation errors in STIG pages
- Fixed component `rules_count` counter cache
- Fixed Capybara Selenium driver for Selenium 4.x compatibility

### 📦 UI Updates

- Complete migration from MDI to Bootstrap icons
- Removed @mdi/font package dependency (300KB reduction)
- Updated all navbar and component icons
- Improved icon consistency across the application

### ⚠️ Breaking Changes

- **Ruby 3.3.9** now required (was 3.1.6)
- **Node.js 22 LTS** now required (was Node.js 16)
- **Rails 8.0.2.1** now required (was Rails 7.0.8.7)
- Webpacker removed in favor of jsbundling-rails with esbuild
- RSpec Rails 6.0+ required for test suite
- Spring gem removed (Rails 8 uses built-in reloader)

### 📝 Migration Guide

1. **Update Ruby and Node.js**:
   ```bash
   rbenv install 3.3.9
   nvm install 22
   ```

2. **Update dependencies**:
   ```bash
   bundle install
   yarn install
   ```

3. **Run database migrations**:
   ```bash
   rails db:migrate
   ```

4. **Clear caches**:
   ```bash
   rails tmp:cache:clear
   ```

5. **Update test environment** if you have custom settings in `config/environments/test.rb`

### 🔮 Coming Soon

- Vue 3 migration (currently Vue 2.6.11)
- Bootstrap 5 upgrade (currently Bootstrap 4.4.1)
- Turbolinks removal for simplified architecture

---

## [v2.1.9] - 2024-06-13

### Major Features
- **OIDC Auto-Discovery Enhancement** ([#672](https://github.com/mitre/vulcan/pull/672))
  - Automatic configuration discovery for OpenID Connect providers
  - Reduced configuration complexity

### Infrastructure Improvements
- Enhanced Docker Compose configurations with production defaults
- Fixed Anchore SBOM artifact naming ([#668](https://github.com/mitre/vulcan/pull/668))
- Updated GitHub Actions to v4

### Bug Fixes
- Fixed critical OIDC authentication case sensitivity bug
- Fixed LDAP authentication ([#669](https://github.com/mitre/vulcan/pull/669))
- Fixed User `effective_permissions` method visibility
- Resolved axios compatibility issues

### Data Updates
- Updated CCI mappings to latest rev5 ([#627](https://github.com/mitre/vulcan/pull/627))
- Revised Excel/CSV column ordering to align with DISA SRGTemplate ([#660](https://github.com/mitre/vulcan/pull/660))

---

## [v2.1.8] - 2024-06-28

### Updates
- Updated CCI mapping with latest Rev 5 mappings ([#626](https://github.com/mitre/vulcan/issues/626))

---

## [v2.1.7] - 2024-05-21

### Security Updates
- Multiple npm dependency updates for security
- axios upgrade from 0.21.4 to 1.6.0 ([#617](https://github.com/mitre/vulcan/pull/617))

### Infrastructure
- Upgraded to new Heroku plan ([#624](https://github.com/mitre/vulcan/pull/624))

---

## [v2.1.6] - 2023-11-08

### Security
- Container now runs as non-root user ([#612](https://github.com/mitre/vulcan/pull/612))
- Security dependency updates

---

## Previous Releases

For releases prior to v2.1.6, please see the [GitHub releases page](https://github.com/mitre/vulcan/releases).

---

[v2.2.2]: https://github.com/mitre/vulcan/compare/v2.2.1...v2.2.2
[v2.2.1]: https://github.com/mitre/vulcan/compare/v2.2.0...v2.2.1
[v2.2.0]: https://github.com/mitre/vulcan/compare/v2.1.9...v2.2.0
[v2.1.9]: https://github.com/mitre/vulcan/compare/v2.1.8...v2.1.9
[v2.1.8]: https://github.com/mitre/vulcan/compare/v2.1.7...v2.1.8
[v2.1.7]: https://github.com/mitre/vulcan/compare/v2.1.6...v2.1.7
[v2.1.6]: https://github.com/mitre/vulcan/compare/v2.1.5...v2.1.6