# Docker Deployment

## Overview

Vulcan provides production-ready Docker images for easy deployment. The images are optimized for size and performance, using multi-stage builds and memory-efficient configurations.

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Download the docker-compose file
wget https://raw.githubusercontent.com/mitre/vulcan/master/docker-compose.yml

# Generate secure configuration
wget https://raw.githubusercontent.com/mitre/vulcan/master/setup-docker-secrets.sh
chmod +x setup-docker-secrets.sh
./setup-docker-secrets.sh

# Start Vulcan
docker-compose up -d
```

### Using Docker Run

```bash
# Pull the latest image
docker pull mitre/vulcan:latest

# Run with PostgreSQL
docker run -d \
  --name vulcan \
  -p 3000:3000 \
  -e DATABASE_URL="postgresql://user:pass@host/vulcan" \
  -e SECRET_KEY_BASE="your-secret-key" \
  mitre/vulcan:latest
```

## Image Details

- **Base**: Ruby 3.4.7 on Debian Bookworm (slim)
- **Size**: ~550MB (optimized multi-stage build)
- **Memory**: Uses jemalloc for 20-40% memory reduction
- **Security**: Non-root user, minimal attack surface
- **Build**: Unified Dockerfile with `--target production`

## Configuration

### Environment Variables

See [Environment Variables](../getting-started/environment-variables.md) for complete list.

Key variables for Docker:
- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Rails secret key
- `RAILS_ENV` - Set to `production`
- `RAILS_LOG_TO_STDOUT` - Set to `true` for container logs
- `FORCE_SSL` - Set to `true` for production with HTTPS, `false` for local dev

### Volumes

```yaml
volumes:
  - ./data/postgres:/var/lib/postgresql/data
  - ./data/uploads:/app/public/uploads
  - ./certs:/app/certs  # For corporate SSL certificates
```

## Production Deployment

### 1. Generate Secrets

```bash
./setup-docker-secrets.sh
# Choose option 2 for production
```

### 2. Configure Authentication

Edit `.env` file to set up OIDC/LDAP:

```bash
# OIDC Configuration
VULCAN_ENABLE_OIDC=true
VULCAN_OIDC_ISSUER_URL=https://your-domain.okta.com
VULCAN_OIDC_CLIENT_ID=your-client-id
VULCAN_OIDC_CLIENT_SECRET=your-client-secret

# Or LDAP Configuration
VULCAN_ENABLE_LDAP=true
VULCAN_LDAP_HOST=ldap.example.com
VULCAN_LDAP_PORT=636
VULCAN_LDAP_BASE=dc=example,dc=com
```

### 3. SSL/TLS Setup

For HTTPS, use a reverse proxy like nginx:

```nginx
server {
    listen 443 ssl;
    server_name vulcan.example.com;
    
    ssl_certificate /etc/ssl/certs/vulcan.crt;
    ssl_certificate_key /etc/ssl/private/vulcan.key;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 4. Database Initialization

First time only:
```bash
docker-compose run --rm web bundle exec rails db:create db:schema:load db:migrate
```

## Monitoring

### Health Check

The Docker image includes a health check:
```bash
docker inspect --format='{{.State.Health.Status}}' vulcan
```

### Logs

```bash
# View logs
docker-compose logs -f web

# Or for single container
docker logs -f vulcan
```

## Backup and Restore

### Database Backup

```bash
# Backup
docker-compose exec postgres pg_dump -U vulcan vulcan_production > backup.sql

# Restore
docker-compose exec -T postgres psql -U vulcan vulcan_production < backup.sql
```

### Application Data

```bash
# Backup uploads
tar -czf uploads-backup.tar.gz ./data/uploads

# Restore uploads
tar -xzf uploads-backup.tar.gz
```

## Troubleshooting

### Common Issues

1. **Database connection failed**
   - Ensure PostgreSQL is running
   - Check DATABASE_URL format
   - Verify network connectivity

2. **Asset compilation errors**
   - Run: `docker-compose run --rm web bundle exec rails assets:precompile`

3. **Permission errors**
   - Check volume mount permissions
   - Ensure UID/GID match between host and container

### Debug Mode

```bash
# Run with debug output
docker-compose run --rm -e RAILS_LOG_LEVEL=debug web
```

## Building Docker Images

Vulcan uses a unified multi-stage Dockerfile that supports both development and production builds.

### Quick Build

```bash
# Production image (~550MB)
docker build -t vulcan:prod --target production .

# Development image (~2.7GB, includes all dev tools)
docker build -t vulcan:dev --target development .
```

### Using the Vulcan CLI

The CLI provides a streamlined build experience:

```bash
# Build production image
vulcan build

# Build development image
vulcan build --target dev

# Show build configuration
vulcan build --info

# Build and push to registry
vulcan build --push

# Custom registry and version
vulcan build --registry ghcr.io/myorg --version v2.3.0
```

### Using Docker Buildx Bake

For advanced builds, use the `docker-bake.hcl` configuration:

```bash
# Build production (default)
docker buildx bake

# Build development
docker buildx bake dev

# Build all targets
docker buildx bake all

# Show what would be built
docker buildx bake --print production
```

### Multi-Architecture Builds

Build for multiple platforms (amd64 + arm64):

```bash
# Using CLI
vulcan build -p linux/amd64,linux/arm64 --push

# Using docker buildx bake
docker buildx bake production-multiarch --push

# Manual docker build
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --target production \
  --push \
  -t mitre/vulcan:latest .
```

::: warning Multi-arch Requirements
Multi-architecture builds require:
- Docker Buildx (included in Docker Desktop)
- A builder with multi-platform support
- `--push` flag (multi-arch images can't be loaded locally)
:::

### Build Targets

| Target | Size | Description |
|--------|------|-------------|
| `production` | ~550MB | Optimized for deployment, non-root user |
| `development` | ~2.7GB | Full dev environment with all tools |

### Build Arguments

Override versions at build time:

```bash
docker build \
  --build-arg RUBY_VERSION=3.4.7 \
  --build-arg NODE_VERSION=24.11.1 \
  --build-arg BUNDLER_VERSION=2.6.5 \
  --target production \
  -t vulcan:custom .
```

### Corporate SSL Certificates

Place certificates in the `certs/` directory before building:

```bash
# Add corporate CA certificates
cp /path/to/corporate-ca.crt certs/

# Build (certificates are automatically installed)
docker build --target production -t vulcan:prod .
```

Supported formats: `.crt`, `.pem`, `.cer` (auto-converted to `.crt`)

### Development with Docker

For local development using Docker:

```bash
# Build development image
docker build -t vulcan:dev --target development .

# Run with mounted source code
docker run -it --rm \
  -v $(pwd):/rails \
  -p 3000:3000 \
  vulcan:dev

# Or use docker-compose.dev.yml
docker-compose -f docker-compose.dev.yml up
```

## Security Considerations

- Always use strong SECRET_KEY_BASE
- Enable HTTPS in production
- Configure authentication (OIDC/LDAP)
- Regularly update base images
- Use read-only root filesystem where possible
- Implement network segmentation

## Next Steps

- [Kubernetes Deployment](kubernetes.md) - For orchestrated deployments
- [Authentication Setup](auth/oidc-okta.md) - Configure SSO
- [Environment Variables](../getting-started/environment-variables.md) - Full configuration reference