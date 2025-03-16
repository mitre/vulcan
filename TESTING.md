# Vulcan Testing Guide

This document outlines the testing infrastructure and approaches for the Vulcan project.

## Testing Infrastructure

Vulcan uses a comprehensive testing approach with multiple layers:

1. **Unit Tests (RSpec)** - For testing individual components and models
2. **Integration Tests (RSpec)** - For testing workflows that involve multiple components
3. **End-to-End Tests (Playwright)** - For testing the full application from a user perspective

### Test Environment

All tests run against a dedicated test environment with managed services:

- **PostgreSQL** - For database testing (via Docker or embedded pg_tmp)
- **LDAP Service** - For authentication testing with LDAP
- **OIDC Mock** - Ruby-based in-process OpenID Connect server (ARM/M1 compatible)
- **Rails Server** - Runs on the host machine for E2E tests

The database service supports two modes:
- **Docker Mode**: PostgreSQL runs in a Docker container
- **pg_tmp Mode**: PostgreSQL runs via temporary clusters using the pg_tmp gem

For more details, see [Embedded PostgreSQL Guide](docs/pg-tmp-integration.md)

## Test Scripts

The project provides several scripts to simplify test execution:

### bin/test-env

Manages test services, including database (Docker or PGLite), LDAP, and Rails server.

```bash
# Start all services with auto-detected database mode
bin/test-env --up

# Start only the database
bin/test-env --db-only

# Use embedded PGLite database
bin/test-env --up --db-mode pglite

# Use Docker PostgreSQL database
bin/test-env --up --db-mode docker

# Check service status
bin/test-env --status

# Stop all services
bin/test-env --down
```

### bin/db-service

Manages database service specifically (Docker or PGLite).

```bash
# Start database with current TEST_DB_MODE
bin/db-service start

# Get database connection status
bin/db-service status

# Get database connection URI
bin/db-service uri

# Stop database service
bin/db-service stop
```

### bin/rspec-test

Runs RSpec tests with proper environment configuration.

```bash
# Run all RSpec tests
bin/rspec-test

# Run model tests only
bin/rspec-test spec/models

# Run tests matching a pattern
bin/rspec-test -f "project"

# Run tests in parallel
bin/rspec-test -p
```

### bin/e2e-test

Runs end-to-end tests with Playwright.

```bash
# Run all E2E tests
bin/e2e-test

# Run a specific test file
bin/e2e-test tests/e2e/jsbundling.spec.js

# Run tests matching a pattern
bin/e2e-test -f "asset pipeline"

# Run tests in parallel
bin/e2e-test -p
```

### bin/run-all-tests

Runs all tests in the proper sequence.

```bash
# Run all tests with auto-detected database mode
bin/run-all-tests

# Run only RSpec tests
bin/run-all-tests --rspec-only

# Run only E2E tests
bin/run-all-tests --e2e-only

# Run all tests in parallel mode
bin/run-all-tests -p

# Run tests with specific database mode
bin/run-all-tests --db-mode pglite
bin/run-all-tests --rspec-only --db-mode docker
```

### bin/unified-test-runner

A lower-level script that handles execution of different test types. This is used internally by the other test scripts but can be used directly for more advanced scenarios.

```bash
# Run RSpec tests
bin/unified-test-runner --type rspec

# Run Playwright tests
bin/unified-test-runner --type playwright

# Focus on a specific pattern or file
bin/unified-test-runner --type rspec --focus "models/user"

# Exclude patterns
bin/unified-test-runner --type rspec --exclude "requests"
```

## Testing Strategies

### Component Testing

When testing Vue components, use the following approach:

1. Test rendering with Playwright to ensure the component appears
2. Test interactions using Playwright test actions
3. Verify state changes through the UI in Playwright tests

### Model Testing

Models should have comprehensive unit tests covering:

1. Validations
2. Associations
3. Scopes
4. Business logic methods

### Authentication Testing

The test environment supports all authentication methods:

1. **Local Authentication** - Standard username/password
2. **LDAP Authentication** - Via the bitnami/openldap container
3. **OIDC Authentication** - Via the Ruby-based OIDC server

## CI/CD Integration

The testing infrastructure is designed for both local development and CI/CD environments:

- Docker services adapt to the host platform (ARM/x86)
- PGLite provides embedded PostgreSQL without Docker dependencies
- The OIDC server runs in-process as a Ruby service (no Docker required)
- Test commands can be run individually or together
- All services support health checks for reliability

In CI environments, use the following approach:

```yaml
- name: Start Test Environment
  run: bin/test-env --up --db-mode docker

- name: Run Tests
  run: bin/run-all-tests --db-mode docker

- name: Stop Test Environment
  run: bin/test-env --down
```

For local development, the PGLite approach is often faster:

```bash
# Start test environment with embedded PostgreSQL
bin/test-env --up --db-mode pglite

# Run your tests
bin/rspec-test spec/models/user_spec.rb

# Stop when finished
bin/test-env --down
```

## Debugging Tests

For failed tests, you can:

1. Use verbose mode with `-v` to get more detailed output
2. Focus on specific tests with `-f` pattern
3. Check service status with `bin/test-env --status`
4. For E2E tests, screenshots and videos are saved in the test-results directory