# Quick Start

Get Vulcan up and running in minutes.

## Try Vulcan Online

Before installing, you can try Vulcan directly:

- **Production**: [https://mitre-vulcan-prod.herokuapp.com](https://mitre-vulcan-prod.herokuapp.com/users/sign_in)
- **Staging**: [https://mitre-vulcan-staging.herokuapp.com](https://mitre-vulcan-staging.herokuapp.com/users/sign_in)

## Prerequisites

- **Docker** and **Docker Compose** installed
- **Ruby 3.4.7** (for local development)
- **Node.js 24 LTS** and **pnpm** (for local development)
- 4GB+ RAM available
- Port 3000 available

## Local Development (Recommended)

The fastest way to get started:

```bash
git clone https://github.com/mitre/vulcan.git && cd vulcan && bin/setup
```

That's it! `bin/setup` handles everything:
- Creates `.env` from `.env.example`
- Starts PostgreSQL 16 via Docker
- Installs Ruby and JavaScript dependencies
- Builds frontend assets
- Sets up database with seed data
- Starts the development server

### Access Vulcan

Open your browser: `http://localhost:3000`

Default credentials:
- **Email**: admin@example.com
- **Password**: 1234567ab!

## Production Docker

For production deployments:

```bash
# Download files
wget https://raw.githubusercontent.com/mitre/vulcan/master/docker-compose.yml
wget https://raw.githubusercontent.com/mitre/vulcan/master/setup-docker-secrets.sh

# Generate secure credentials
chmod +x setup-docker-secrets.sh
./setup-docker-secrets.sh

# Start application
docker-compose up -d
```

!!! warning "Security Notice"
    Never use default credentials in production! The `setup-docker-secrets.sh` script generates secure passwords.

## First Steps

1. **Create a Project**: Click "New Project" to start organizing your security controls
2. **Import an SRG**: Upload a Security Requirements Guide to begin tailoring
3. **Create Components**: Add system components that need STIG documentation
4. **Write Controls**: Document security controls with human-readable guidance and InSpec validation code

## Keyboard Shortcuts

- **Cmd+K** (Mac) / **Ctrl+K** (Windows/Linux): Open Command Palette for global search

## Next Steps

- [Full Installation Guide](installation.md) - Production deployment options
- [Configuration Guide](configuration.md) - Authentication, email, and advanced settings
- [User Guide](../user-guide/overview.md) - Complete walkthrough of Vulcan features

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/mitre/vulcan/issues)
- **Discussions**: [GitHub Discussions](https://github.com/mitre/vulcan/discussions)
- **Email**: saf@mitre.org
