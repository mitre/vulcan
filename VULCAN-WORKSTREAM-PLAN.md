# Vulcan Workstream Implementation Plan

This document outlines the structured approach for implementing the separate workstreams identified during refactoring of the Vulcan project. It serves as a persistent reference for the team regarding PR sequence and scope.

## Current Branch Analysis

The `upgrade-webpack-to-jsbundling` branch initially contained multiple parallel workstreams:

1. Asset pipeline modernization (Webpacker → jsbundling-rails)
2. CLI architecture enhancements (TTY-based CLI)
3. Configuration system overhaul
4. Testing infrastructure improvements

These have been separated into focused branches to enable a more manageable implementation process.

## PR Sequence and Scope

### PR1: Asset Pipeline Modernization

**Branch:** `upgrade-webpack-to-jsbundling`

**Core Changes:**
- Replace Webpacker with jsbundling-rails using esbuild
- Add Propshaft for non-JS asset management
- Ensure all Vue components render correctly
- Include minimal testing infrastructure (unified-test-runner)
- Ruby 3.0.7 and Rails 7.0.8 upgrade prerequisites

**Key Files:**
- Gemfile (add jsbundling-rails and propshaft)
- esbuild.config.js
- Updated app/javascript files
- App layout templates with new asset helpers
- bin/unified-test-runner and bin/run-tests
- CI workflow with Playwright tests

**Validation Approach:**
- Playwright tests for UI component rendering
- RSpec tests for backend functionality
- Asset compilation verification

### PR2: Testing Infrastructure Enhancement

**Branch:** `testing-infrastructure-backup`

**Core Changes:**
- Hierarchical test runner implementation
- Cross-platform test containers
- Test organization improvements
- Enhanced test isolation
- CI pipeline improvements

**Key Files:**
- bin/hierarchical-test-runner
- Docker compose test configurations
- Expanded Playwright test suite
- LDAP testing improvements

**Validation Approach:**
- Self-testing (the test infrastructure tests itself)
- Cross-platform validation

### PR3: CLI Architecture

**Branch:** `cli-architecture-backup`

**Core Changes:**
- TTY-based CLI with improved UX
- Command registry implementation
- Shell escaping security enhancements
- Standardized command formats
- Improved CLI documentation

**Key Files:**
- lib/vulcan/ CLI implementation
- bin/vulcan CLI entry point
- CLI command tests
- Shell security tests

**Validation Approach:**
- CLI-specific test suite
- Security validation
- UX testing

### PR4: Configuration System

**Branch:** `configuration-system-backup`

**Core Changes:**
- Rails-CLI configuration bridge
- Environment-specific configuration
- Configuration validation
- Secret management
- Configuration interfaces

**Key Files:**
- lib/vulcan/core/config.rb
- lib/vulcan/bridges/rails_config_bridge.rb
- Config validation tests
- Environment-specific configs

**Validation Approach:**
- Configuration test suite
- Cross-environment testing
- Integration with both CLI and Rails

## Implementation Guidelines

When implementing each PR:

1. **Stay Focused**: Avoid scope creep - each PR should address only its core focus area
2. **Independent Testing**: Each PR should have its own testing approach
3. **Clear Dependencies**: Document any dependencies between PRs
4. **Documentation**: Update relevant documentation for each workstream
5. **Review Process**: Each PR requires thorough review before merging

This structured approach ensures we maintain a clean separation of concerns while progressively enhancing the Vulcan platform.