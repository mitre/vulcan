# Changelog

## [Unreleased]

**🚀 Major Framework & Infrastructure Upgrades:**

### Test Modernization & Dependency Updates (#683)
- **Test Framework Modernization**:
  - Migrated all controller specs to request specs (Rails 8 requirement)
  - Migrated all feature specs to system specs (Rails 5.1+ standard)
  - Removed `any_instance_of` anti-pattern from all tests
  - Fixed Devise authentication issues with Rails 8 lazy route loading
- **Security & Dependency Updates**:
  - axios: 1.6.8 → 1.11.0 (fixes SSRF vulnerabilities)
  - factory_bot: 5.2.0 → 6.5.4
  - ESLint: 8.x → 8.57.1 (optimized for compatibility)
  - Prettier: 2.8.8 → 3.6.2
  - eslint-plugin-prettier: 4.2.1 → 5.2.1
- **Rails 8 Compatibility Fixes**:
  - Removed Spring gem (Rails 8 uses built-in reloader)
  - Fixed `fixture_paths` deprecation (changed to singular `fixture_path`)
  - Added bundler-audit for Ruby vulnerability scanning
- **UI Updates**:
  - Complete MDI to Bootstrap icon migration
  - Removed @mdi/font package dependency
  - Updated all navbar and component icons
- All 190 tests passing with improved performance

### Rails 8.0.2.1 Upgrade (#682)
- **Progressive upgrade path**: Rails 7.0.8.7 → 7.1.5.2 → 7.2.2.2 → 8.0.2.1
- All 198 tests passing with 0 failures
- Migrated from Webpacker to jsbundling-rails with esbuild
- Already using Propshaft (no Sprockets migration needed)
- Updated RSpec Rails from 4.0 to 6.0 for Rails 8 compatibility

### Ruby & Node.js Modernization (#680)
- **Ruby**: Upgraded from 3.1.6 → 3.3.6 → 3.3.9
- **Node.js**: Upgraded from 16 → 20 → 22 LTS (specified in .nvmrc)
- Full compatibility with modern JavaScript tooling
- Improved performance and memory usage

### OIDC Authentication Enhancements
- **Auto-Discovery Feature**: Automatic endpoint configuration from provider metadata
- Moved OIDC discovery cache from session to Rails.cache for better performance
- Support for all major OIDC providers (Okta, Auth0, Keycloak, Azure AD)
- Only 4 environment variables needed (down from 8+)
- Comprehensive logging for troubleshooting

### Docker & Container Optimization
- **Production Docker image**: Reduced from 6.5GB to 1.76GB
- Multi-stage builds with jemalloc for 20-40% memory reduction
- Fixed SSL certificate installation for corporate proxies
- Heroku-24 stack compatibility
- Container-friendly logging with JSON structured output support

**🛡️ Security Improvements:**
- Fixed SQL injection vulnerability in Component#duplicate_rules using parameterized queries
- Migrated to Rails 8 `expect` API for strong parameters
- Updated all security dependencies
- Fixed mass assignment warnings
- SonarCloud quality gate passing

**🔧 CI/CD & DevOps:**
- Fixed Anchore SBOM and Docker Hub push workflows
- Updated GitHub Actions to v4
- Fixed Bundler deprecation warnings
- Added .sonarcloud.properties for automatic analysis
- Heroku review apps and production deployment optimized

**📚 Environment Variables & Configuration:**
- Comprehensive environment variable documentation in ENVIRONMENT_VARIABLES.md
- Production-ready Docker Compose configurations
- Automatic secret generation script (setup-docker-secrets.sh)
- Support for corporate SSL certificates in Docker builds

**🐛 Bug Fixes:**
- Fixed overlay component seed data (now shows correct rule counts)
- Fixed Vue template compilation error in STIG pages
- Fixed component rules_count counter cache
- Fixed Capybara Selenium driver for Selenium 4.x compatibility
- Resolved all Rails 8 deprecation warnings

**📝 Breaking Changes:**
- Ruby 3.3.9 required (upgraded from 3.1.6)
- Node.js 22 LTS required (upgraded from 16)
- Rails 8.0.2.1 required (upgraded from 7.0.8.7)
- Webpacker removed in favor of jsbundling-rails with esbuild
- RSpec Rails 6.0+ required for test suite

**🔄 Migration Notes:**
- Default credentials remain: admin@example.com / 1234567ab!
- Database migrations required: `rails db:migrate`
- Clear Rails cache after upgrade: `rails tmp:cache:clear`
- Test environment configuration may need updates (see config/environments/test.rb)
- Bundle install required for new dependencies

**🚧 Upcoming:**
- Bootstrap 5 migration (currently on Bootstrap 4.4.1)
- Vue 3 upgrade (currently on Vue 2.x)
- Potential migration to Hotwire/Turbo

## [v2.1.9](https://github.com/mitre/vulcan/tree/v2.1.9) (2025-06-13)

[Full Changelog](https://github.com/mitre/vulcan/compare/v2.1.8...v2.1.9)

**🚀 Major Features:**
- OIDC Auto-Discovery Enhancement (#672) - Automatic configuration discovery for OpenID Connect providers
- Comprehensive webpacker migration research and planning documents
- Enhanced Docker Compose configurations with production environment defaults
- Enterprise configuration management roadmap documentation

**🔧 Infrastructure & CI/CD Improvements:**
- Add VULCAN_OIDC_DISCOVERY=true to CI/CD workflow
- Fix CI/CD and WebMock configuration for stable test runs
- Fix overcommit YarnInstall hook configuration
- Fix Anchore SBOM artifact naming issue (#668)
- Update GitHub Actions and dependencies to latest versions

**🛡️ Security & Authentication Fixes:**
- Fix critical OIDC authentication bug - case sensitivity issue
- Fix authentication test edge cases and mocking issues
- Fix critical authentication and authorization vulnerabilities
- Fix User effective_permissions method visibility
- Fix LDAP authentication in master branch (#669)

**📊 Excel Export & Data Handling:**
- Revised ordering of excel/csv output columns to align with DISA provided SRGTemplate spreadsheet (#660)
- Update CCI mappings to latest rev5 (#627)

**🐛 Bug Fixes:**
- Fix Dockerfile legacy ENV format warnings
- Fix axios compatibility issues
- Remove problematic controller tests in favor of comprehensive model tests
- Fix RuboCop documentation warnings for test support modules

**📚 Documentation & Project Management:**
- Add organized documentation structure for decision records, guides, and architecture
- Track project CLAUDE.md as official project documentation
- Add comprehensive webpacker migration research and planning documents
- Enterprise configuration management to modernization roadmap

**🔒 Dependency Updates:**
- Update workflow to use artifact actions v4 and update actions/cache from v2 to v4
- Bump ws from 6.2.2 to 6.2.3 in the npm_and_yarn group
- Various security-focused dependency updates

**🏗️ Development Environment:**
- Modernize Docker Compose configurations
- Fix overcommit issues and configuration
- Add production environment defaults to Docker configuration

**📋 Notes:**
- This is the final release using settingslogic for configuration management
- Next release (v2.2.0) will include migration to rails-settings-cached
- Rollback point for users who need the legacy configuration system

## [v2.1.8](https://github.com/mitre/vulcan/tree/v2.1.8) (2024-06-28)

[Full Changelog](https://github.com/mitre/vulcan/compare/v2.1.7...v2.1.8)

**Closed issues:**

- Update CCI mapping in Vulcan with the latest CCI list with Rev 5 mappings [\#626](https://github.com/mitre/vulcan/issues/626)

## [v2.1.7](https://github.com/mitre/vulcan/tree/v2.1.7) (2024-05-21)

[Full Changelog](https://github.com/mitre/vulcan/compare/v2.1.6...v2.1.7)

**Dependencies updates:**

- Bump the npm\_and\_yarn group across 1 directory with 3 updates [\#623](https://github.com/mitre/vulcan/pull/623) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump the npm\_and\_yarn group across 1 directories with 1 update [\#620](https://github.com/mitre/vulcan/pull/620) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump the npm\_and\_yarn group across 1 directories with 1 update [\#619](https://github.com/mitre/vulcan/pull/619) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump axios from 0.21.4 to 1.6.0 [\#617](https://github.com/mitre/vulcan/pull/617) ([dependabot[bot]](https://github.com/apps/dependabot))

**Merged pull requests:**

- Upgrade to New Heroku Plan [\#624](https://github.com/mitre/vulcan/pull/624) ([DMedina6](https://github.com/DMedina6))

## [v2.1.6](https://github.com/mitre/vulcan/tree/v2.1.6) (2023-11-08)

[Full Changelog](https://github.com/mitre/vulcan/compare/v2.1.5...v2.1.6)

**Dependencies updates:**

- Bump browserify-sign from 4.2.1 to 4.2.2 [\#614](https://github.com/mitre/vulcan/pull/614) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump @babel/traverse from 7.15.4 to 7.23.2 [\#613](https://github.com/mitre/vulcan/pull/613) ([dependabot[bot]](https://github.com/apps/dependabot))

**Closed issues:**

- Update image to not run as root [\#611](https://github.com/mitre/vulcan/issues/611)

**Merged pull requests:**

- updating container to run as a non root user [\#612](https://github.com/mitre/vulcan/pull/612) ([rlakey](https://github.com/rlakey))

## [v2.1.5](https://github.com/mitre/vulcan/tree/v2.1.5) (2023-10-02)

[Full Changelog](https://github.com/mitre/vulcan/compare/v2.1.4...v2.1.5)

**Implemented enhancements:**

- Enable user to select which component to excel export [\#610](https://github.com/mitre/vulcan/pull/610) ([vanessuniq](https://github.com/vanessuniq))
- Enabled viewing of related rules in read-only mode, but hiding the  copy button [\#605](https://github.com/mitre/vulcan/pull/605) ([vanessuniq](https://github.com/vanessuniq))

**Fixed bugs:**

- Vulcan container crashes when exporting to excel [\#600](https://github.com/mitre/vulcan/issues/600)
- Update inspec after copying or duplicate a component [\#598](https://github.com/mitre/vulcan/issues/598)
- Ensure a rule's inspec code is updated after establishing rule satisfaction or reverting change on a rule [\#609](https://github.com/mitre/vulcan/pull/609) ([vanessuniq](https://github.com/vanessuniq))
- Added fixref attribute to fixtext XML tag for compatibility with stig-viewer-3x [\#608](https://github.com/mitre/vulcan/pull/608) ([smarlaku820](https://github.com/smarlaku820))

**Closed issues:**

- Add fixref to XCCDF generation to be compatible with STIG Viewer 3.x [\#607](https://github.com/mitre/vulcan/issues/607)

**Merged pull requests:**

- Removed Changelog from the landing page and have the app version on the top menu as a link directing to the changelog page [\#606](https://github.com/mitre/vulcan/pull/606) ([vanessuniq](https://github.com/vanessuniq))

## [v2.1.4](https://github.com/mitre/vulcan/tree/v2.1.4) (2023-08-25)

[Full Changelog](https://github.com/mitre/vulcan/compare/v2.1.3...v2.1.4)

**Implemented enhancements:**

- Give admins the ability to mark a project as 'open' [\#590](https://github.com/mitre/vulcan/issues/590)
- Add constraint to satisfies workflow for configurable only requirements. [\#585](https://github.com/mitre/vulcan/issues/585)
- Have Vulcan automatically list all available STIGs/SRGs [\#480](https://github.com/mitre/vulcan/issues/480)
- STIG & Related Rules workflow [\#599](https://github.com/mitre/vulcan/pull/599) ([vanessuniq](https://github.com/vanessuniq))
- New Feature: Enable setting up Project visibility and Requesting access to a project [\#595](https://github.com/mitre/vulcan/pull/595) ([vanessuniq](https://github.com/vanessuniq))
- Notifications: Slack notification and SMTP Enhancement [\#594](https://github.com/mitre/vulcan/pull/594) ([vanessuniq](https://github.com/vanessuniq))
- VULCAN-528: Fix component admin on component cards [\#588](https://github.com/mitre/vulcan/pull/588) ([vanessuniq](https://github.com/vanessuniq))
- Constrain requirement for locking Applicable -Does Not Meet and Applicable - Inherently Meets controls [\#587](https://github.com/mitre/vulcan/pull/587) ([vanessuniq](https://github.com/vanessuniq))
- Constrain the selectable list to allow only Apllicable - Configurable controls to be satisfied by other [\#586](https://github.com/mitre/vulcan/pull/586) ([vanessuniq](https://github.com/vanessuniq))

**Fixed bugs:**

- Fix component\_admin on component cards [\#528](https://github.com/mitre/vulcan/issues/528)
- Fix Related Rules Grouping [\#604](https://github.com/mitre/vulcan/pull/604) ([vanessuniq](https://github.com/vanessuniq))
- Fix: Capture STIG Name on Upload [\#603](https://github.com/mitre/vulcan/pull/603) ([vanessuniq](https://github.com/vanessuniq))
- If null data just return for related info [\#602](https://github.com/mitre/vulcan/pull/602) ([freddyfeelgood](https://github.com/freddyfeelgood))

**Dependencies updates:**

- Bump puma from 4.3.12 to 5.6.7 [\#601](https://github.com/mitre/vulcan/pull/601) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump word-wrap from 1.2.3 to 1.2.4 [\#597](https://github.com/mitre/vulcan/pull/597) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump semver from 5.7.1 to 5.7.2 [\#596](https://github.com/mitre/vulcan/pull/596) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump audited from 5.0.2 to 5.3.3 [\#568](https://github.com/mitre/vulcan/pull/568) ([dependabot[bot]](https://github.com/apps/dependabot))

**Closed issues:**

- Extend email notifications to alert users when their role changes. [\#593](https://github.com/mitre/vulcan/issues/593)
- Enable users to provide their own Slack user ID if they would like to receive Slack DMs \(e.g. when added/removed from a project, role changes, review requests, etc\). [\#592](https://github.com/mitre/vulcan/issues/592)
- Enable users \(admins\) to provide the Slack channel they want to use for each project or component. This can be provided on project/component creation or edited in the project/component metadata. [\#591](https://github.com/mitre/vulcan/issues/591)
- The Mitigation field must be populated if the requirement Status is 'Applicable - Does Not Meet' [\#578](https://github.com/mitre/vulcan/issues/578)
- Artifact Description is required and should only be visible in Status - Applicable - Inherently Meets [\#577](https://github.com/mitre/vulcan/issues/577)
- Look into backup options for heroku deployment [\#458](https://github.com/mitre/vulcan/issues/458)

## [v2.1.3](https://github.com/mitre/vulcan/tree/v2.1.3) (2023-06-01)

[Full Changelog](https://github.com/mitre/vulcan/compare/v2.1.2...v2.1.3)

**Implemented enhancements:**

- Implementing ActionMailer for sending email notifications [\#551](https://github.com/mitre/vulcan/issues/551)
- Enabling SMTP feature to send emails via ActionMailer [\#584](https://github.com/mitre/vulcan/pull/584) ([smarlaku820](https://github.com/smarlaku820))
- Control View Only and Edit Mode UX refactor [\#583](https://github.com/mitre/vulcan/pull/583) ([vanessuniq](https://github.com/vanessuniq))

**Fixed bugs:**

- Import From a SpreadSheet does not work as expected when contains a rule that is satisfied by more than one other rules [\#581](https://github.com/mitre/vulcan/issues/581)
- Bug: Vulcan project metadata update triggers project\_rename slack notification [\#579](https://github.com/mitre/vulcan/issues/579)
- VULCAN-581: Enhance Import from Spreadsheet workflow  [\#582](https://github.com/mitre/vulcan/pull/582) ([vanessuniq](https://github.com/vanessuniq))
- fix project update logic for detecting name changes correctly [\#580](https://github.com/mitre/vulcan/pull/580) ([smarlaku820](https://github.com/smarlaku820))

**Closed issues:**

- Move user button in Find and Replace to top of the modal [\#576](https://github.com/mitre/vulcan/issues/576)
- Update Find and Replace to search all fields [\#575](https://github.com/mitre/vulcan/issues/575)
- Update Find and Replace to add case sensitive and non-sensitive [\#574](https://github.com/mitre/vulcan/issues/574)
- Expose Requirement Satellites Nesting in Form feels and UX [\#571](https://github.com/mitre/vulcan/issues/571)
- Refactor 'Mark As Duplicate' into original design of nested elements [\#570](https://github.com/mitre/vulcan/issues/570)

## [v2.1.2](https://github.com/mitre/vulcan/tree/v2.1.2) (2023-05-08)

[Full Changelog](https://github.com/mitre/vulcan/compare/v2.1.1...v2.1.2)

**Implemented enhancements:**

- Add version info to UI [\#565](https://github.com/mitre/vulcan/issues/565)
- Add description text to xccdf exports [\#556](https://github.com/mitre/vulcan/issues/556)
- VULCAN- 565: Add latest release version tag to Navbar component [\#567](https://github.com/mitre/vulcan/pull/567) ([vanessuniq](https://github.com/vanessuniq))
- Adding the option to group/sort controls by SrG ID [\#566](https://github.com/mitre/vulcan/pull/566) ([vanessuniq](https://github.com/vanessuniq))
- VULCAN-563: Export/Import inspec control body [\#564](https://github.com/mitre/vulcan/pull/564) ([vanessuniq](https://github.com/vanessuniq))
- Group histories with the same name, created\_at, and comment; add tooltip for rule status [\#562](https://github.com/mitre/vulcan/pull/562) ([vanessuniq](https://github.com/vanessuniq))
- Enabled editing component STIG ID prefix [\#558](https://github.com/mitre/vulcan/pull/558) ([vanessuniq](https://github.com/vanessuniq))

**Fixed bugs:**

- Support multiple cci's  [\#559](https://github.com/mitre/vulcan/issues/559)
- VULCAN-559: Support for Multiple CCIs [\#569](https://github.com/mitre/vulcan/pull/569) ([vanessuniq](https://github.com/vanessuniq))

**Closed issues:**

- Export/Import InSpec Control Body [\#563](https://github.com/mitre/vulcan/issues/563)

## [v2.1.1](https://github.com/mitre/vulcan/tree/v2.1.1) (2023-04-13)

[Full Changelog](https://github.com/mitre/vulcan/compare/v2.1.0...v2.1.1)

**Implemented enhancements:**

- Add additional component question of URL type. [\#372](https://github.com/mitre/vulcan/issues/372)
- 348 alternative testing [\#546](https://github.com/mitre/vulcan/pull/546) ([vanessuniq](https://github.com/vanessuniq))

**Fixed bugs:**

- customized parser to not interpret character/html entity [\#550](https://github.com/mitre/vulcan/pull/550) ([vanessuniq](https://github.com/vanessuniq))

**Dependencies updates:**

- Bump nokogiri from 1.14.2 to 1.14.3 [\#554](https://github.com/mitre/vulcan/pull/554) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump rack from 2.2.6.3 to 2.2.6.4 [\#548](https://github.com/mitre/vulcan/pull/548) ([dependabot[bot]](https://github.com/apps/dependabot))

**Merged pull requests:**

- use title for description if description blank [\#557](https://github.com/mitre/vulcan/pull/557) ([rlakey](https://github.com/rlakey))
- 372 add additional component question of url type [\#553](https://github.com/mitre/vulcan/pull/553) ([freddyfeelgood](https://github.com/freddyfeelgood))
- Up to deep linking [\#552](https://github.com/mitre/vulcan/pull/552) ([vanessuniq](https://github.com/vanessuniq))

## [v2.1.0](https://github.com/mitre/vulcan/tree/v2.1.0) (2023-03-29)

[Full Changelog](https://github.com/mitre/vulcan/compare/v2.0.0...v2.1.0)

**Implemented enhancements:**

- Add option to restrict project creation [\#538](https://github.com/mitre/vulcan/issues/538)
- Populate gid/rid in InSpec body data [\#530](https://github.com/mitre/vulcan/issues/530)
- Add "DISA Excel Export" option [\#527](https://github.com/mitre/vulcan/issues/527)
- Add SRG version \(release/version\) to SRG info on controls [\#517](https://github.com/mitre/vulcan/issues/517)
- Output Vulcan logs to stdout [\#514](https://github.com/mitre/vulcan/issues/514)
- Add button to component card to download a single component as an XCCDF file [\#499](https://github.com/mitre/vulcan/issues/499)
- Allow export to excel for non-released components [\#496](https://github.com/mitre/vulcan/issues/496)
- Add an icon to indicate a control has children [\#490](https://github.com/mitre/vulcan/issues/490)
- Diff view swap comparison [\#410](https://github.com/mitre/vulcan/issues/410)
- Diff comparison pulling in non-released components [\#408](https://github.com/mitre/vulcan/issues/408)
- OIDC identity provider support to remove login friction with username/password. [\#390](https://github.com/mitre/vulcan/issues/390)
- 389 Integrate Slack With Vulcan [\#389](https://github.com/mitre/vulcan/issues/389)
- Account for controls marked as duplicate on existing SRG content import [\#362](https://github.com/mitre/vulcan/issues/362)
- Fix search on 'New Component' Dropdown [\#352](https://github.com/mitre/vulcan/issues/352)
- Show 'loading' when uploading a new SRG [\#350](https://github.com/mitre/vulcan/issues/350)
- Add deep linking to controls [\#348](https://github.com/mitre/vulcan/issues/348)
- Add option to disable registration [\#338](https://github.com/mitre/vulcan/issues/338)
- Add option to toggle sidebar between STIG ID and SRG ID [\#315](https://github.com/mitre/vulcan/issues/315)
- Include version as part of the SRG Title on the “Create a New Component” page. [\#306](https://github.com/mitre/vulcan/issues/306)
- Check if date in “release-info” is consistent across all SRGs [\#305](https://github.com/mitre/vulcan/issues/305)
- When uploading an SRG the application should show “Loading…” in place of the Upload Button [\#304](https://github.com/mitre/vulcan/issues/304)
- SRG page enhancements [\#298](https://github.com/mitre/vulcan/issues/298)
- Add support for upgrading between versions of SRGs [\#82](https://github.com/mitre/vulcan/issues/82)
- 389 Integrate Slack With Vulcan [\#549](https://github.com/mitre/vulcan/pull/549) ([smarlaku820](https://github.com/smarlaku820))
- Added OIDC Integration capability for Vulcan [\#540](https://github.com/mitre/vulcan/pull/540) ([smarlaku820](https://github.com/smarlaku820))
- Disallow new project creation if not admin by default [\#539](https://github.com/mitre/vulcan/pull/539) ([smarlaku820](https://github.com/smarlaku820))
- Feature DISA Export Excel complete with tests [\#529](https://github.com/mitre/vulcan/pull/529) ([smarlaku820](https://github.com/smarlaku820))
- Completed \#496 [\#523](https://github.com/mitre/vulcan/pull/523) ([vanessuniq](https://github.com/vanessuniq))
- Enable XCCDF export of a single component [\#511](https://github.com/mitre/vulcan/pull/511) ([vanessuniq](https://github.com/vanessuniq))
- 470 change the color of the mark as duplicate button [\#482](https://github.com/mitre/vulcan/pull/482) ([vanessuniq](https://github.com/vanessuniq))

**Fixed bugs:**

- Export to excel not sorted by SRG ID [\#536](https://github.com/mitre/vulcan/issues/536)
- Mitigation text for DNM controls is not copied over on a copy component workflow with new SRG [\#531](https://github.com/mitre/vulcan/issues/531)
- Copy/Duplicate Component creates additional\_answers in the source component if they exist [\#524](https://github.com/mitre/vulcan/issues/524)
- Copy Component corrupts SRG data when updating SRG version of the new SRG [\#515](https://github.com/mitre/vulcan/issues/515)
- Copy Component fails when selecting a newer SRG version and a control has been previously deleted in the source component [\#501](https://github.com/mitre/vulcan/issues/501)
- Export to Excel does not work if Components have the same name [\#495](https://github.com/mitre/vulcan/issues/495)
- Troubleshoot editing a control [\#491](https://github.com/mitre/vulcan/issues/491)
- Fix the display of the Github logo on the documentation page [\#483](https://github.com/mitre/vulcan/issues/483)
- A user with the author role cannot revoke a review request they initiated. [\#479](https://github.com/mitre/vulcan/issues/479)
- Change the color of the "mark as duplicate" button [\#470](https://github.com/mitre/vulcan/issues/470)
- Project/Component authors and admins cannot mark/unmark controls as duplicates [\#449](https://github.com/mitre/vulcan/issues/449)
- Project page component card control counts include deleted controls [\#433](https://github.com/mitre/vulcan/issues/433)
- Deleting a control prevents the deleting of the component [\#429](https://github.com/mitre/vulcan/issues/429)
- Sort tags in InSpec metadata [\#419](https://github.com/mitre/vulcan/issues/419)
- Add Version and Release info when importing a released component into a project [\#415](https://github.com/mitre/vulcan/issues/415)
- Sort Project Components by Name then Version/Release [\#414](https://github.com/mitre/vulcan/issues/414)
- Some SRG XCCDF files fail to load [\#351](https://github.com/mitre/vulcan/issues/351)
- 524 fix answer cloning issue [\#525](https://github.com/mitre/vulcan/pull/525) ([rlakey](https://github.com/rlakey))
- Properly using \#dup method for expected behavior: [\#522](https://github.com/mitre/vulcan/pull/522) ([vanessuniq](https://github.com/vanessuniq))
- 495 export to excel does not work if components have the same name [\#505](https://github.com/mitre/vulcan/pull/505) ([vanessuniq](https://github.com/vanessuniq))
- 501 copy component fails when selecting a newer srg version and a control has been previously deleted in the source component [\#503](https://github.com/mitre/vulcan/pull/503) ([vanessuniq](https://github.com/vanessuniq))
- Debugged: added the missing currentUserId prop to RuleEditorHeader co… [\#486](https://github.com/mitre/vulcan/pull/486) ([vanessuniq](https://github.com/vanessuniq))

**Dependencies updates:**

- Bump omniauth-rails\_csrf\_protection Gem [\#542](https://github.com/mitre/vulcan/issues/542)
- Bump rack from 2.2.6.2 to 2.2.6.3 [\#545](https://github.com/mitre/vulcan/pull/545) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump omniauth-rails\_csrf\_protection Gem [\#543](https://github.com/mitre/vulcan/pull/543) ([smarlaku820](https://github.com/smarlaku820))
- Bump omniauth and gitlab\_omniauth-ldap [\#541](https://github.com/mitre/vulcan/pull/541) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump globalid from 1.0.0 to 1.0.1 [\#521](https://github.com/mitre/vulcan/pull/521) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump rack from 2.2.4 to 2.2.6.2 [\#520](https://github.com/mitre/vulcan/pull/520) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump json5 from 1.0.1 to 1.0.2 [\#513](https://github.com/mitre/vulcan/pull/513) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump rails-html-sanitizer from 1.4.3 to 1.4.4 [\#510](https://github.com/mitre/vulcan/pull/510) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump loofah from 2.18.0 to 2.19.1 [\#509](https://github.com/mitre/vulcan/pull/509) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump nokogiri from 1.13.6 to 1.13.10 [\#508](https://github.com/mitre/vulcan/pull/508) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump minimatch from 3.0.4 to 3.1.2 [\#507](https://github.com/mitre/vulcan/pull/507) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump express from 4.17.1 to 4.18.2 [\#506](https://github.com/mitre/vulcan/pull/506) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump decode-uri-component from 0.2.0 to 0.2.2 [\#502](https://github.com/mitre/vulcan/pull/502) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump loader-utils from 1.4.0 to 1.4.2 [\#500](https://github.com/mitre/vulcan/pull/500) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump omniauth from 1.9.1 to 1.9.2 [\#466](https://github.com/mitre/vulcan/pull/466) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump moment from 2.29.2 to 2.29.4 [\#451](https://github.com/mitre/vulcan/pull/451) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump terser from 4.8.0 to 4.8.1 [\#450](https://github.com/mitre/vulcan/pull/450) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump rails-html-sanitizer from 1.4.2 to 1.4.3 [\#446](https://github.com/mitre/vulcan/pull/446) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump eventsource from 1.1.0 to 1.1.1 [\#440](https://github.com/mitre/vulcan/pull/440) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump rack from 2.2.3 to 2.2.3.1 [\#439](https://github.com/mitre/vulcan/pull/439) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump nokogiri from 1.13.5 to 1.13.6 [\#437](https://github.com/mitre/vulcan/pull/437) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump nokogiri from 1.13.4 to 1.13.5 [\#435](https://github.com/mitre/vulcan/pull/435) ([dependabot[bot]](https://github.com/apps/dependabot))

**Closed issues:**

- Typos [\#475](https://github.com/mitre/vulcan/issues/475)
- Enable login via MITRE SSO [\#463](https://github.com/mitre/vulcan/issues/463)
- Improve visibility of mark as duplicate feature [\#457](https://github.com/mitre/vulcan/issues/457)
- Implement find and replace for rules across components [\#454](https://github.com/mitre/vulcan/issues/454)
- Add concept of compensating controls and POA&M statuses to Applicable - Does Not Meet status [\#448](https://github.com/mitre/vulcan/issues/448)
- Enable context-aware popover help icons, depending on Status field [\#447](https://github.com/mitre/vulcan/issues/447)
- Title Box Visibility [\#445](https://github.com/mitre/vulcan/issues/445)
- Adding new control should duplicate CCI-000366 [\#444](https://github.com/mitre/vulcan/issues/444)
- Copy component timeout error [\#442](https://github.com/mitre/vulcan/issues/442)
- Fix Heroku Deployment [\#425](https://github.com/mitre/vulcan/issues/425)

**Merged pull requests:**

- Sorted excel output and misc bug fixes [\#537](https://github.com/mitre/vulcan/pull/537) ([rlakey](https://github.com/rlakey))
- Created an ENV variable for controlling USER registrations on Vulcan app \(Enabled by Default\) [\#535](https://github.com/mitre/vulcan/pull/535) ([smarlaku820](https://github.com/smarlaku820))
- 530 populate gid and rid in inspec body data [\#533](https://github.com/mitre/vulcan/pull/533) ([rlakey](https://github.com/rlakey))
- 531 fix for copy comp w new srg for vuln disc [\#532](https://github.com/mitre/vulcan/pull/532) ([rlakey](https://github.com/rlakey))
- Added Filtering capability to SRG dropdown [\#526](https://github.com/mitre/vulcan/pull/526) ([freddyfeelgood](https://github.com/freddyfeelgood))
- 517 update SRG info on control view [\#519](https://github.com/mitre/vulcan/pull/519) ([rlakey](https://github.com/rlakey))
- 315 added toggle for stig id to srg id [\#516](https://github.com/mitre/vulcan/pull/516) ([rlakey](https://github.com/rlakey))
- Update push-to-docker.yml [\#489](https://github.com/mitre/vulcan/pull/489) ([vanessuniq](https://github.com/vanessuniq))
- Fix GitHub logo in README [\#485](https://github.com/mitre/vulcan/pull/485) ([ChrisHinchey](https://github.com/ChrisHinchey))
- Add GitHub logo to README [\#481](https://github.com/mitre/vulcan/pull/481) ([ChrisHinchey](https://github.com/ChrisHinchey))
- fixes \#475 [\#477](https://github.com/mitre/vulcan/pull/477) ([wdower](https://github.com/wdower))
- VULCAN-448: mitigations are always shown [\#465](https://github.com/mitre/vulcan/pull/465) ([timwongj](https://github.com/timwongj))
- VULCAN-452: Review workflow improvements [\#464](https://github.com/mitre/vulcan/pull/464) ([timwongj](https://github.com/timwongj))
- VULCAN-448: Add concept of compensating controls and POA&M statuses to Applicable - Does Not Meet status [\#462](https://github.com/mitre/vulcan/pull/462) ([timwongj](https://github.com/timwongj))
- VULCAN-447: Enable context-aware popover help icons, depending on Status field [\#461](https://github.com/mitre/vulcan/pull/461) ([timwongj](https://github.com/timwongj))
- VULCAN-449: Fix mark as duplicate for proj/comp admin/authors [\#460](https://github.com/mitre/vulcan/pull/460) ([timwongj](https://github.com/timwongj))
- VULCAN-457: Add tooltip for mark as duplicate [\#459](https://github.com/mitre/vulcan/pull/459) ([timwongj](https://github.com/timwongj))
- VULCAN-445: Title box visibility [\#456](https://github.com/mitre/vulcan/pull/456) ([timwongj](https://github.com/timwongj))
- VULCAN-454: Implement find and replace [\#455](https://github.com/mitre/vulcan/pull/455) ([timwongj](https://github.com/timwongj))
- fix add new control [\#443](https://github.com/mitre/vulcan/pull/443) ([timwongj](https://github.com/timwongj))
- VULCAN-410: Swap diff view comparison [\#441](https://github.com/mitre/vulcan/pull/441) ([sgober](https://github.com/sgober))
- VULCAN-415: Show version and release for overlaid components suggestions [\#438](https://github.com/mitre/vulcan/pull/438) ([timwongj](https://github.com/timwongj))
- VULCAN-433: Modify rules\_count to exclude deleted rules [\#436](https://github.com/mitre/vulcan/pull/436) ([timwongj](https://github.com/timwongj))
- VULCAN-414: Sort displayed components [\#434](https://github.com/mitre/vulcan/pull/434) ([timwongj](https://github.com/timwongj))
- VULCAN-419: Sort Inspec tags [\#432](https://github.com/mitre/vulcan/pull/432) ([timwongj](https://github.com/timwongj))
- VULCAN-301: Display loading... when uploading SRG [\#431](https://github.com/mitre/vulcan/pull/431) ([timwongj](https://github.com/timwongj))
- VULCAN-429: Fix deleting a control prevents the deleting of the component [\#430](https://github.com/mitre/vulcan/pull/430) ([timwongj](https://github.com/timwongj))
- VULCAN-298: SRG page enhancements [\#428](https://github.com/mitre/vulcan/pull/428) ([timwongj](https://github.com/timwongj))
- VULCAN-362: Account for controls marked as duplicate on existing SRG content import [\#427](https://github.com/mitre/vulcan/pull/427) ([timwongj](https://github.com/timwongj))



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
