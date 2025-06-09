# Development Setup Script

The `bin/dev-setup` script provides a comprehensive way to set up your local Vulcan development environment with different authentication methods.

## Quick Start

```bash
# Basic setup with local authentication
./bin/dev-setup

# Setup with Okta authentication
./bin/dev-setup --okta

# Setup with LDAP authentication  
./bin/dev-setup --ldap

# Clean setup (removes existing containers first)
./bin/dev-setup --clean

# Refresh database (drops and recreates)
./bin/dev-setup --refresh
```

## Features

- **Ruby Version Management**: Automatically detects and switches to the correct Ruby version using RVM or rbenv
- **Node.js Version Management**: Automatically detects and switches to the correct Node.js version using NVM
- **Dependency Installation**: Installs Ruby gems and Node packages as needed
- **Database Setup**: Manages PostgreSQL in Docker and handles database creation/migration
- **Multiple Auth Modes**: Supports local, Okta, and LDAP authentication configurations

## Authentication Modes

### Local Authentication (Default)
The simplest mode for development. Uses database-backed authentication.

```bash
./bin/dev-setup --local  # or just ./bin/dev-setup
```

Test credentials:
- Email: admin@example.com
- Password: 1234567ab!

### Okta Authentication
For testing OIDC/Okta integration.

```bash
./bin/dev-setup --okta
```

Requires `.env.development.local` with:
```
VULCAN_OIDC_CLIENT_ID=your-client-id
VULCAN_OIDC_CLIENT_SECRET=your-client-secret
```

### LDAP Authentication  
For testing LDAP integration. Uses a test LDAP server in Docker.

```bash
./bin/dev-setup --ldap
```

Test LDAP users (from docker-compose.dev.yml):
- Username: fry@planetexpress.com / Password: fry
- Username: zoidberg@planetexpress.com / Password: zoidberg

## Environment Files

The script looks for these environment files:

- `.env` - General environment variables (always loaded)
- `.env.development` - Development-specific variables
- `.env.development.local` - Local overrides (not committed to git)
- `.env.okta.dev` - Okta configuration template
- `.env.ldap` - LDAP configuration (optional)

## Requirements

- Docker and Docker Compose (for PostgreSQL and LDAP server)
- Ruby (managed by RVM or rbenv)
- Node.js (managed by NVM)
- Yarn

## Troubleshooting

### Wrong Ruby Version
The script will automatically try to switch Ruby versions using RVM or rbenv. If neither is installed, you'll need to manually install the correct Ruby version specified in `.ruby-version`.

### Database Connection Issues
Make sure Docker is running and port 5432 is not already in use. The script uses Docker Compose to manage PostgreSQL.

### Missing Dependencies
The script automatically runs `bundle install` and `yarn install` when needed. If you encounter issues, try running these commands manually.

### Clean Start
If you're having issues, try a clean start:
```bash
./bin/dev-setup --clean --refresh
```

This will remove existing containers and recreate the database from scratch.