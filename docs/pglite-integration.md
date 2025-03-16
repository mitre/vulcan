# PGLite Integration Guide

This document describes the integration of PGLite as an embedded PostgreSQL alternative for testing and development in the Vulcan project.

## Overview

PGLite is a Ruby gem that embeds PostgreSQL directly in your application, providing a faster and more lightweight alternative to running a full Docker container for testing and development. The Vulcan project now supports both Docker-based PostgreSQL and embedded PGLite, giving developers flexibility in their workflow.

## Architecture

The PGLite integration is designed to be transparent and compatible with the existing Docker-based PostgreSQL setup. The key components are:

1. **DatabaseService Class**: A singleton service class that manages database connection, located at `spec/support/database_service.rb`.

2. **DB Service CLI**: A command-line interface for the DatabaseService class, located at `bin/db-service`.

3. **Test Environment Scripts**: Updated to support both database modes, with a `--db-mode` parameter.

4. **Test Runners**: Updated to automatically detect and use the appropriate database connection.

## Usage

### Setting Database Mode

You can control which database mode to use with the `--db-mode` parameter:

```bash
# Use embedded PGLite
bin/test-env --db-mode pglite

# Use Docker PostgreSQL
bin/test-env --db-mode docker

# Auto-detect the best option (default)
bin/test-env --db-mode auto
```

The auto-detection logic prefers:
- Docker in CI environments
- PGLite for local development (if available)
- Falling back to Docker if PGLite is not available

### Starting the Database

```bash
# Start database in the configured mode
bin/db-service start

# Check status
bin/db-service status

# Get the database connection URI
bin/db-service uri

# Stop the database
bin/db-service stop
```

### Running Tests with Database Selection

```bash
# Run all tests with auto-detected database
bin/run-all-tests

# Run RSpec tests with embedded PGLite
bin/run-all-tests --rspec-only --db-mode pglite

# Run end-to-end tests with Docker PostgreSQL
bin/run-all-tests --e2e-only --db-mode docker
```

## Benefits

### PGLite Benefits

- **Speed**: Faster startup and shutdown times
- **Simplicity**: No Docker dependencies required
- **Cross-platform**: Works on ARM (M1/M2/M3) and x86 architectures
- **Resource Efficiency**: Uses fewer system resources
- **Isolation**: Each test run can use a fresh database instance

### Docker Benefits

- **Environment Isolation**: Runs in a container separate from the host system
- **CI Compatibility**: Ideal for CI/CD environments
- **Production Similarity**: Closer to production environment
- **Stack Integration**: Easily integrates with other Docker services (LDAP, etc.)

## Implementation Details

### Database Connection

Both database modes use the same connection pattern:
- Host: localhost
- Port: 5432
- Username: postgres
- Password: vulcan_development
- Database: vulcan_vue_test

The connection URI is dynamically generated based on the active mode and can be retrieved using `bin/db-service uri`.

### Data Storage

- **Docker**: Uses a named volume `vulcan_test_db` to persist data across restarts
- **PGLite**: Stores data in the `tmp/pglite` directory

### Test Environment Integration

The testing infrastructure automatically:
1. Detects the desired database mode
2. Starts the appropriate database service
3. Configures Rails to use the correct connection URI
4. Provides the connection to test runners

## Troubleshooting

### Common Issues

#### Port Conflicts

If port 5432 is already in use:
```bash
# Check what's using the port
lsof -i :5432

# Stop the PGLite service
bin/db-service stop

# Stop the Docker service
bin/test-env --down
```

#### Database Connection Failures

If tests can't connect to the database:
```bash
# Check database status
bin/db-service status

# Restart the database
bin/test-env --restart --db-mode auto
```

#### PGLite Installation Issues

If PGLite fails to install:
```bash
# Install PostgreSQL development headers
# macOS:
brew install postgresql

# Ubuntu/Debian:
sudo apt-get install libpq-dev

# Then reinstall the gem
bundle install
```

## Future Enhancements

Planned improvements to the database service architecture:

1. **Shared Test Data**: Centralized test data creation and seeding across database modes
2. **LDAP Integration**: Ruby-based LDAP mock server similar to the PGLite approach
3. **Database Reset API**: Easy way to reset to a clean state between test runs
4. **Connection Pooling**: Optimized connection handling for parallel tests