# Changelog

All notable changes to Vulcan will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- VitePress documentation system replacing MkDocs for better Vue ecosystem alignment
- Mermaid diagram support in documentation with custom Vue component
- Comprehensive documentation guide at `/development/documentation`
- Production and staging deployment links in documentation
- Separate package.json for docs to isolate dependencies (temporary until Vue 3 migration)
- Custom Vulcan branding with SVG logos and Media Kit page
- Automatic SVG optimization using vite-plugin-image-optimizer
- Media Kit & Branding page at `/about/media-kit` with logos, colors, and usage guidelines

### Changed
- Documentation navigation reorganized with top-level Deployment, Authentication, and Security sections
- Improved compliance documentation with source code verification and cross-references
- LICENSE file renamed to LICENSE.md for consistency with other project documentation
- Simplified CI/CD workflow by removing symlink preprocessing script (no longer needed)
- All project documentation files now use consistent .md extensions

### Fixed
- Documentation build issues with dead links and localhost URLs
- ESLint configuration to properly handle VitePress files
- Trailing whitespace issues in configuration files
- VitePress symlink handling with proper configuration
- Circular reference in README.md documentation link removed

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

### 🔮 Coming in v2.3.0

- ✅ Vue 3.5 migration with Composition API and Pinia (completed)
- ✅ Bootstrap 5 upgrade with Bootstrap-Vue-Next (completed)
- ✅ Turbolinks removal, Vue Router for SPA navigation (completed)
- Command Palette with global search
- Ruby 3.4.7 and Node.js 24 LTS upgrades
- PostgreSQL 16 upgrade
- Docker image optimization (~550MB production image)

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

[v2.2.0]: https://github.com/mitre/vulcan/compare/v2.1.9...v2.2.0
[v2.1.9]: https://github.com/mitre/vulcan/compare/v2.1.8...v2.1.9
[v2.1.8]: https://github.com/mitre/vulcan/compare/v2.1.7...v2.1.8
[v2.1.7]: https://github.com/mitre/vulcan/compare/v2.1.6...v2.1.7
[v2.1.6]: https://github.com/mitre/vulcan/compare/v2.1.5...v2.1.6