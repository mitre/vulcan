# Changelog

All notable changes to Vulcan will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Comment reactions (👍/👎) on rule comments and replies. Reactions render as counts on each comment in the rule editor pullout, the comment thread (reply rows), and the triage modal; click the people-icon to see reactor names (works on hover, focus, and tap — accessible to keyboard and touch). Reactions are merged into the parent comment's `Thread Replies` cell in the disposition-matrix CSV export (alongside text replies, in chronological order) as `[name · timestamp] reacted thumbs-up` entries. Audited via `vulcan_audited` so the toggle history is preserved.
- Rate limits on reaction endpoints: 60 toggles/min/user (POST) and 300 hover-fetches/min/user (GET) via Rack::Attack, with IP fallback for unauthenticated traffic.

### Changed

- Project viewers can now post comments on rules. Previously the `viewer` role was strictly read-only; it now grants read + comment access. Save / Approve / Request Changes / Lock / Unlock remain restricted to higher roles. To restrict commenting you must remove the user's project membership.
- Authorization rejection responses for JSON requests now return a structured `403 Forbidden` body (`{ error: 'permission_denied', message, admins: [...], toast }`) instead of `500 Internal Server Error`. The legacy `toast` shape is kept alongside so existing AlertMixin consumers keep working unchanged.

### Added

- `Review::VALID_ACTIONS` allowlist + inclusion validator on `Review#action` so unknown action strings no longer save silently as state-mutating no-ops
- AlertMixin now renders structured permission-denied responses as a "Permission denied" toast that lists the project administrators (name and email) the user should contact for access — no more silent or generic failures on rejected actions

### Fixed

- `rescue_from` ordering bug in `ApplicationController` — `NotAuthorizedError` was being shadowed by the catch-all `StandardError` rescue (`ActiveSupport::Rescuable` matches handlers via `reverse_each`, so the LAST-declared rescue wins). The dedicated `not_authorized` handler was effectively dead code in any non-development environment for JSON requests, surfacing every unauthorized action as a 500 instead of the proper 401/403. Reordered so the specific rescue wins.

## [v2.3.5] - 2026-04-11

### Added

- Server-side user search endpoint `GET /api/users/search` with admin authorization
- `scope=members` parameter for searching within existing project/component members (PoC selection — accessible to any member)
- `Project#search_available_members` and `Project#search_members` (combine exclusion + ILIKE search)
- `Component#search_available_members` and `Component#search_members` (mirrors `all_users` semantics for inherited + direct members)
- Async server-side user search via `vue-multiselect` in `NewMembership`, `MembersModal`, and `UpdateComponentDetailsModal` (debounced 300ms, min 2 characters)
- Contract tests asserting `/components/:id.json` editor refresh response shape matches `ComponentBlueprint :editor` exactly
- Regression guards in `ComponentBlueprint` and `rules_spec` asserting `available_members` and `all_users` are not present in serialized payloads (information disclosure regression guard)
- Dedicated `release.yml` workflow triggered only on release published events

### Changed

- `available_members` and `all_users` removed from `ComponentBlueprint` and `ProjectBlueprint` payloads (no longer pre-loaded into the DOM)
- `MembershipsTable` derives pending access request user info from `access_requests` directly instead of cross-referencing `available_members`
- `ComponentsController#show` editor JSON now renders `ComponentBlueprint :editor` directly, eliminating a parallel jbuilder code path that produced a different shape than the initial render
- `show.json.jbuilder` simplified to non-member only (BenchmarkViewer's lightweight rule shape)
- Docker release workflow split out of `ci.yml` so test suite no longer reruns on release publish
- All GitHub Actions pinned to full commit SHAs for supply chain safety

### Fixed

- **Information disclosure**: pre-loaded full user directory removed from project/component pages — admins could previously enumerate every registered user via the page payload
- **Editor refresh shape drift**: `refreshComponent()` (called by `UpdateComponentDetailsModal`, `UpdateMetadataModal`, `AddQuestionsModal` after save) replaced local `component.memberships` with name/email-less stripped versions, silently breaking `MembersModal` display until full page reload
- `MembershipsTable.getAccessRequestId` was reading stale `request.user_id` and would crash Accept/Reject after the access_requests payload moved to nested `request.user.{id,name,email}` shape
- `Component#search_available_members` / `#search_members` were missing entirely (controller dispatched to `@target.search_*` but only `Project` had them), causing `NoMethodError` for any `membership_type=Component` request
- `first_user_admin` after_create callback was silently promoting test users to site admin in new request specs, masking project-level authorization assertions
- SBOM tag mismatch (`v2.3.4` vs `2.3.4`) in release workflow

### Security

- The `/api/users/search` endpoint enforces admin-only access for non-member searches and member-only access for `scope=members` searches, preventing unauthorized user enumeration

## [v2.3.4] - 2026-04-07

### Added

- Blueprinter JSON serialization framework with 15 blueprint classes and context-specific views (:index, :show, :editor, :navigator, :viewer)
- blueprinter-activerecord auto-preloader for automatic N+1 prevention
- Oj fast JSON generator (~2x faster than stdlib)
- Rule and Review test factories
- 12 query performance regression tests
- Session auth method tracking (session[:auth_method]) — distinguishes "signed in via" from "account linked to"
- Unlink identity feature with password verification
- VULCAN_AUTO_LINK_USER global setting for automatic provider-to-local account linking
- Admin password management UI: always show all options regardless of SMTP configuration

### Changed

- All controllers migrated from to_json(methods:[]) to Blueprint.render
- All model as_json overrides removed (BaseRule, Rule, Review, Membership)
- Project#details consolidated from 9 COUNT queries to 3 (GROUP BY)
- Project#available_members uses SQL WHERE NOT IN instead of Ruby set subtraction
- Project#available_components uses .select() for column filtering
- Component#reviews uses pluck(:id, :rule_id) instead of loading full rule objects
- Rule creation uses DB lookup instead of parsing multi-MB XML
- UsersController audit query bounded with .limit(200)
- ApplicationController check_access_request_notifications rewritten (N+1 → single query)
- Replaced gitlab_omniauth-ldap with omniauth-ldap 2.3.3 (removes nkf VM crash)
- Ruby 3.4.8 → 3.4.9
- Bumped version to v2.3.4

### Fixed

- OIDC provider conflict: symbol/string comparison bug in User.from_omniauth
- Provider+uid-first lookup pattern (GitLab pattern) prevents provider hijacking
- rescue_from ordering: StandardError defined before ProviderConflictError
- Production /stigs crash (R14/R15 memory, H12 timeout) — SeverityCounts concern auto-excludes xml/binary columns
- VulcanAudit bitwise & → && fix for nil rule
- OmniAuth backtrace logging gated on development only — now logs in all environments
- email_verified OIDC claim hardened with ActiveModel::Type::Boolean.new.cast
- Polymorphic membership_type filter in access request notifications
- JSON.parse round-trip eliminated in component show jbuilder (render_as_hash)
- Slack notification firing on every user update instead of only admin changes
- Polymorphic audit query missing user_type filter
- PROJECT_MEMBER_ADMINS normalized from scalar string to array
- UsersTable typeColumn uses falsy check for undefined provider
- Exception message no longer leaked to client in rescue blocks
- update_columns used for password reset token to skip validations
- Visibility chain (stray public keyword) fixed in registrations controller
- valid_password? bcrypt→PBKDF2 rehash side-effect documented at unlink call site

## [v2.3.1] - 2026-03-03

### Added

- Multi-stage Dockerfile with CLI integration and improved .dockerignore
- Admin bootstrap: first-user-admin on registration and env var (`VULCAN_ADMIN_EMAIL`/`VULCAN_ADMIN_PASSWORD`) support
- Health check endpoints for Kubernetes/Docker readiness probes
- DB_SUFFIX environment variable for worktree database isolation
- GET /api/version endpoint
- Tag-triggered release automation with git-cliff changelog generation
- Frontend tests added to CI pipeline
- Centralized version infrastructure and parallel test stability improvements
- Global search using pg_search: full-text search across rules, STIGs, SRGs, and SRG rules via unified API endpoint and frontend composable
- FilterBar and FilterGroup shared components with disabled state support and configurable display defaults
- EasyMDE markdown editor with custom Shiki syntax highlighting for rule content fields
- Centralized terminology constants for consistent UI text across components
- Unified rule form replacing separate Basic and Advanced forms, with IA Control/CCI display and severity override guidance
- RuleFormGroup shared component for DRY form field rendering
- Per-section rule locking: backend field-level editability abstraction and locking UI
- Rule panel buttons and actions toolbar with two-row layout redesign
- Auto-select first visible rule on page load
- Right sidebar panels converted to Bootstrap slideovers
- Command bars for rule view and edit pages with unified layout structure
- Project page standardized with command bar, sidepanels, and ComponentActionPicker for component creation
- Projects, Released Components, STIGs, SRGs, and Users list pages standardized with breadcrumbs and command bars
- User Profile page converted to Vue with breadcrumb navigation and comprehensive settings
- Redesigned MembersModal with tabbed interface
- Redesigned severity filter buttons as connected button group
- Unified BenchmarkViewer with composable navigation, SRG detail pages, sortable columns, severity badges, and keyboard navigation
- STIG/SRG XCCDF export with frontend integration
- CSV export with configurable column picker for STIGs and SRGs
- Export service with Registry, formatters (XCCDF, InSpec, Excel, CSV, JSON archive), and mode-first ExportModal with progressive disclosure
- VendorSubmission mode for DISA-compliant exports; PublishedStig and Backup export modes
- JSON archive backup export with full-fidelity serializer, membership backup/restore, and dry-run import support
- Restore from backup: component picker modal, per-component detail, POST /projects/create_from_backup endpoint
- Export pre-flight warning for components with all NYD (Not Yet Determined) rules
- Exclude-satisfied-by toggle for Excel/CSV exports
- Satisfaction data import/export via CSV column and VulnDiscussion parsing; Postel's Law applied to ingest (liberal) and export (canonical)
- CSV header aliases for backward-compatible import
- SRG auto-detection from spreadsheet import
- Spreadsheet update modal with word-diff preview
- Excel exporter switched from FastExcel to caxlsx with Source column and per-cell lock styling
- Configurable Remember Me with 8-hour default
- PasswordField component with show/hide toggle, replacing all password inputs
- Configurable password complexity policy (DoD 8500.2/2222 compliant)
- Admin user management UI: create, edit, password reset tools
- Account lockout (STIG AC-07): Devise lockable module, lock/unlock endpoints, navbar notifications, and audit trail
- Shared notification event bus for cross-component reactivity
- Authentication security hardening: PBKDF2 password hashing, session hardening, Devise audit logging
- Frontend form validation composable
- Classification banner and configurable consent modal (AC-8)
- AC-8 server-side consent tracking with configurable TTL (`VULCAN_CONSENT_TTL`)
- Input length limits (configurable via Settings), CSP headers, and detailed import error messages
- VULCAN_SEED_DEMO_DATA guard to prevent demo seeding in production
- Reusable delete confirmation system with JSON responses for axios compatibility
- TimeoutParser with Postel's Law for flexible session timeout configuration

### Changed

- Upgraded Ruby from 3.3.9 to 3.4.9 and Puma to 7.2.0
- Upgraded Node.js to 24 LTS
- Upgraded PostgreSQL from 12/16 to 18 across Docker, CI, and documentation
- Replaced overcommit with lefthook for git hooks; added pre-push checks for RuboCop, ESLint, and Brakeman
- Added RuboCop plugins: rubocop-capybara, rubocop-factory_bot, rubocop-rspec_rails
- Applied SonarCloud-driven improvements across Ruby, Vue, and JavaScript files
- Replaced BasicRuleForm and AdvancedRuleForm with a single UnifiedRuleForm; removed dead severities prop chain
- Extracted shared ControlsCommandBar and ControlsSidepanels components; reorganized buttons by semantic group
- Renamed History to Activity in rule command bar; moved Members button to modal actions group
- Replaced RulesReadOnlyView with route-based views; updated RulesCodeEditorView to use composables
- Migrated all rule and component UI references to RULE_TERM terminology constants
- Removed old NewProject page system; replaced dead Stig components with RuleFormGroup
- Added Vitest infrastructure for Vue 2 component testing with coverage reporting
- Converted 36 spec files to `let_it_be` for approximately 65% faster backend test suite
- Added shoulda-matchers 7.0 and validation contract specs for all core models
- Added composite indexes for severity count queries and Jbuilder collection caching
- DRY'd seed data, model concerns, SRG ID serialization, satisfaction text, and notification dispatch
- Added request specs for components, rules, exports, and backup round-trip integration
- Added frontend test coverage for mixins, modals, utilities, banner, consent, lockout, and section locking
- Wired XCCDF and InSpec exports through a unified export service
- Pinned Devise to ~> 4.9 to prevent accidental upgrade to v5
- Increased CI backend shards from 4 to 6; added frozen_string_literal to all migration files
- Updated deployment documentation: Docker, database setup, env vars, port registry, and authorization
- Added backup/restore, data management, AC-8 consent, and security control documentation
- Optimized Heroku slug size with .slugignore and node_modules cleanup
- Bumped version to v2.3.1

### Fixed

- Sanitize SQL LIKE input to prevent injection in search queries
- Enforce deny-by-default authorization on all controller actions; prevent provider hijacking on existing accounts
- Input security hardening: XXE prevention, upload validation, rate limiting
- Avoid cleartext password storage during bcrypt-to-PBKDF2 migration
- Replace thread-unsafe class variables in export controller with session storage
- Remove dangerous DISABLE_DATABASE_ENVIRONMENT_CHECK from Docker entrypoint
- Remove explicit secure cookie flag; let Rails SSL middleware set it automatically
- Add Devise Lockable migration for existing deployments
- Consent modal now shown before login, not after (AC-8 compliance)
- Resolve nested attributes not saving in rules controller (#692)
- Also Satisfies no longer resets parent rule status; show disabled buttons in read-only mode
- Display SRG IDs in satisfaction relationships and all rule views; enable paste/type input
- Derive srg_id from association in non-member component view
- Sort rules by rule_id and version before auto-selecting first visible rule
- Show New Project button for non-admin users with create permission; show delete button for project admins
- Correct SRG search result links to use /srgs/ route
- Respect component_ids selection for XCCDF and InSpec exports
- Add null guards for missing SRG data and name/email in search filters
- Fix v-b-tooltip directive pattern app-wide
- Use CAT I/II/III labels, fix text contrast for severity badges
- Replace table with div for accessible listbox in RuleList
- Fix body padding offset for fixed classification banner
- Correct file picker accept attribute for component import
- Enable Remember Me checkbox for OmniAuth/LDAP logins
- Docker build fix, configurable SSL for Docker deployments (#700, #702, #703)
- Database config with DATABASE_URL support; DRY database.yml defaults
- CSP configuration for OIDC provider and Vue 2 unsafe-eval
- Use CONCURRENTLY for GIN and composite index migrations to avoid table locks
- Make seeds idempotent using find_or_create_by!
- Resolve ESLint and RuboCop linting issues
- Resolve SonarCloud reliability bugs, security hotspots, and CI workflow issues
- Update rexml, rack, faraday, and uri gems to patch known CVEs

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

[v2.3.4]: https://github.com/mitre/vulcan/compare/v2.3.1...v2.3.4
[v2.3.1]: https://github.com/mitre/vulcan/compare/v2.2.0...v2.3.1
[v2.2.1]: https://github.com/mitre/vulcan/compare/v2.2.0...v2.2.1
[v2.2.0]: https://github.com/mitre/vulcan/compare/v2.1.9...v2.2.0
[v2.1.9]: https://github.com/mitre/vulcan/compare/v2.1.8...v2.1.9
[v2.1.8]: https://github.com/mitre/vulcan/compare/v2.1.7...v2.1.8
[v2.1.7]: https://github.com/mitre/vulcan/compare/v2.1.6...v2.1.7
[v2.1.6]: https://github.com/mitre/vulcan/compare/v2.1.5...v2.1.6