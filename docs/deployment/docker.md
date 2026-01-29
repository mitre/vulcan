# Docker Deployment

## Overview

Vulcan provides production-ready Docker images for easy deployment. The images are optimized for size and performance, using multi-stage builds and memory-efficient configurations.

## Quick Start

```bash
# Clone or download the repository
git clone https://github.com/mitre/vulcan.git
cd vulcan

# Generate secrets (one time)
./setup-docker-secrets.sh

# Start Vulcan
docker compose up

# Open http://localhost:3000
# Register your first user - they become admin automatically
```

**What happens on first start:**
- PostgreSQL starts with generated credentials
- The entrypoint runs `db:prepare` (creates database, runs migrations)
- Admin bootstrap runs automatically (hooked into `db:prepare`)
- First user to register becomes admin (via `VULCAN_FIRST_USER_ADMIN=true`)

### Admin Bootstrap Options

Vulcan provides three ways to create the initial admin:

1. **First User Admin** (Default): First user to register becomes admin
   - Enabled by default via `VULCAN_FIRST_USER_ADMIN=true`
   - Protected by PostgreSQL advisory lock against race conditions

2. **Environment Variables** (Recommended for Production):
   ```bash
   # Add to .env
   VULCAN_ADMIN_EMAIL=admin@example.com
   VULCAN_ADMIN_PASSWORD=SecurePassword123!
   VULCAN_FIRST_USER_ADMIN=false
   ```
   - Admin created automatically during `db:prepare`
   - If password omitted, a secure random password is generated and logged

3. **Manual Rake Task**:
   ```bash
   docker compose exec web rails db:create_admin
   ```

> **Note**: For local testing without SSL/reverse proxy, add `RAILS_FORCE_SSL=false` to your `.env` file.
> For production with SSL termination (nginx, traefik), keep the default `RAILS_FORCE_SSL=true`.

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

- **Base**: Ruby 3.3.9 on Debian Bookworm
- **Size**: 1.76GB (73% smaller than v2.1)
- **Memory**: Uses jemalloc for 20-40% memory reduction
- **Security**: Non-root user, minimal attack surface

## Configuration

### Environment Variables

See [Environment Variables](../getting-started/environment-variables.md) for complete list.

Key variables for Docker:
- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Rails secret key
- `RAILS_ENV` - Set to `production`
- `RAILS_LOG_TO_STDOUT` - Set to `true` for container logs

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

For HTTPS, use a reverse proxy like nginx. The proxy should set the `X-Forwarded-Proto` header so Rails knows the original request was HTTPS.

> **Important**: Keep `RAILS_FORCE_SSL=true` (default) when using a reverse proxy. Only set `RAILS_FORCE_SSL=false` for local Docker testing without SSL termination.

Example nginx configuration:

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

The Docker entrypoint automatically runs `db:prepare` on first startup, which creates the database and runs migrations. No manual database initialization is needed.

To run migrations manually:
```bash
docker compose run --rm web bundle exec rails db:migrate
```

## Monitoring

### Health Check Endpoints

Vulcan provides health check endpoints for container orchestration and monitoring:

| Endpoint | Purpose | Response |
|----------|---------|----------|
| `GET /up` | Liveness probe (is process alive?) | HTML with green background |
| `GET /health_check` | Readiness probe (database connected?) | `ok` or `service unavailable` |
| `GET /health_check/database` | Database connectivity only | `ok` or `service unavailable` |
| `GET /health_check/migrations` | Pending migrations check | `ok` or `service unavailable` |

**Docker Compose health check** (built into image):
```bash
# Check container health status
docker inspect --format='{{.State.Health.Status}}' vulcan

# Manual endpoint test
curl http://localhost:3000/up
curl http://localhost:3000/health_check
```

**Kubernetes probe configuration:**
```yaml
livenessProbe:
  httpGet:
    path: /up
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health_check
    port: 3000
  initialDelaySeconds: 15
  periodSeconds: 5
```

### Logs

```bash
# View logs
docker compose logs -f web

# Or for single container
docker logs -f vulcan
```

## Backup and Restore

### Database Backup

```bash
# Backup
docker compose exec postgres pg_dump -U vulcan vulcan_production > backup.sql

# Restore
docker compose exec -T postgres psql -U vulcan vulcan_production < backup.sql
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
   - Run: `docker compose run --rm web bundle exec rails assets:precompile`

3. **Permission errors**
   - Check volume mount permissions
   - Ensure UID/GID match between host and container

### Debug Mode

```bash
# Run with debug output
docker compose run --rm -e RAILS_LOG_LEVEL=debug web
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