# Quick Start

Get Vulcan up and running in minutes with Docker.

## Try Vulcan Online

Before installing, you can try Vulcan directly:

- **Production**: [https://mitre-vulcan-prod.herokuapp.com](https://mitre-vulcan-prod.herokuapp.com/users/sign_in)
- **Staging**: [https://mitre-vulcan-staging.herokuapp.com](https://mitre-vulcan-staging.herokuapp.com/users/sign_in)

## Prerequisites

- Docker and Docker Compose installed
- 4GB+ RAM available
- Port 3000 available

## Quick Installation

### 1. Pull and Run with Docker

```bash
# Pull the latest Docker image
docker pull mitre/vulcan:latest

# Or use docker compose for a complete setup
wget https://raw.githubusercontent.com/mitre/vulcan/master/docker-compose.prod.yml
wget https://raw.githubusercontent.com/mitre/vulcan/master/setup-docker-secrets.sh
chmod +x setup-docker-secrets.sh
./setup-docker-secrets.sh
docker compose -f docker-compose.prod.yml up
```

### 2. Access Vulcan

Open your browser and navigate to: `http://localhost:3000`

The first user to register becomes admin automatically.

::: tip Admin Bootstrap
For automated deployments, you can pre-configure an admin account via environment variables (`VULCAN_ADMIN_EMAIL` and `VULCAN_ADMIN_PASSWORD`). See [Environment Variables](environment-variables.md) for details.
:::

### 3. First Steps

1. **Create a Project**: Click "New Project" to start organizing your security controls
2. **Import an SRG**: Upload a Security Requirements Guide to begin tailoring
3. **Create Components**: Add system components that need STIG documentation
4. **Write Controls**: Begin documenting security controls with both human-readable guidance and InSpec validation code

## Next Steps

- [Full Installation Guide](installation.md) - Production deployment options
- [Configuration Guide](configuration.md) - Authentication, email, and advanced settings
- [User Guide](../user-guide/overview.md) - Complete walkthrough of Vulcan features

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/mitre/vulcan/issues)
- **Discussions**: [GitHub Discussions](https://github.com/mitre/vulcan/discussions)
- **Email**: saf@mitre.org