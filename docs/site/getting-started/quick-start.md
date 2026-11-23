# Quick Start

Get Vulcan up and running in minutes with Docker.

## Prerequisites

- Docker and Docker Compose installed
- 4GB+ RAM available
- Port 3000 available

## Quick Installation

### 1. Pull and Run with Docker

```bash
git clone https://github.com/mitre/vulcan.git
cd vulcan

# Generate .env with secure secrets (choose 1 for development, 2 for production)
./setup-docker-secrets.sh

# Run the published image instead of building locally (optional)
echo 'IMAGE_NAME=mitre/vulcan:release-latest' >> .env

docker compose up
```

::: tip
Clone the repository rather than downloading `docker-compose.yml` on its own:
`setup-docker-secrets.sh` reads the `.env.example` / `.env.production.example` templates, and the
compose file's `web` service builds from the repository when `IMAGE_NAME` is not set.
:::

### 2. Access Vulcan

Open your browser and navigate to: `http://localhost:3000`

The first user to register becomes admin automatically — this holds for the development template
(option 1). The production template sets `VULCAN_FIRST_USER_ADMIN=false` and disables
self-registration, so use the admin bootstrap variables below instead.

::: tip Admin Bootstrap
For automated deployments, you can pre-configure an admin account via environment variables (`VULCAN_ADMIN_EMAIL` and `VULCAN_ADMIN_PASSWORD`). See [Environment Variables](environment-variables.md) for details.
:::

### 3. First Steps

1. **Create a Project**: Click "New Project" to start organizing your security controls
2. **Import an SRG**: Upload a Security Requirements Guide to begin tailoring
3. **Create a Component**: Click "New Component" → "Create New Component". The form first asks **What are you authoring?** — **STIG** (implement an SRG's requirements for a specific product) or **SRG** (author a new Security Requirements Guide derived from core SRGs). The choice is permanent for the component.
4. **Write Controls**: Begin documenting security controls with both human-readable guidance and InSpec validation code — or, for an SRG component, decide and tailor each requirement (see the [SRG Authoring Workflow](../disa-process/srg-authoring))

## Next Steps

- [Full Installation Guide](installation.md) - Production deployment options
- [Configuration Guide](configuration.md) - Authentication, email, and advanced settings
- [User Guide](../user-guide/overview.md) - Complete walkthrough of Vulcan features

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/mitre/vulcan/issues)
- **Discussions**: [GitHub Discussions](https://github.com/mitre/vulcan/discussions)
- **Email**: saf@mitre.org
