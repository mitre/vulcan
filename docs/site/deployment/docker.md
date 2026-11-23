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

> **Note**: `docker-compose.yml` defaults the web service to `RAILS_FORCE_SSL=false` so the HTTP
> quickstart works out of the box. For production behind SSL termination (Caddy, nginx, traefik),
> set `RAILS_FORCE_SSL=true` in your `.env` file.

### Using Docker Run

```bash
# Pull the latest released image
docker pull mitre/vulcan:release-latest

# Run with PostgreSQL (use -p ${PORT}:3000 to change host port)
docker run -d \
  --name vulcan \
  -p ${VULCAN_PORT:-3000}:3000 \
  -e DATABASE_URL="postgresql://user:pass@host/vulcan" \
  -e SECRET_KEY_BASE="your-secret-key" \
  mitre/vulcan:release-latest
```

## Image Details

- **Base**: Red Hat UBI 9 Minimal, pinned by tag *and* digest in the `Dockerfile`, with Ruby compiled
  from source (YJIT enabled). The Ruby version comes from the `RUBY_VERSION` build arg and matches
  `.ruby-version`; its tarball is verified against the `RUBY_SHA256` build arg.
- **Architectures**: linux/amd64, linux/arm64 (multi-arch, built natively via Docker Build Cloud)
- **Size**: see the tag listing on [Docker Hub](https://hub.docker.com/r/mitre/vulcan/tags)
- **Memory**: jemalloc compiled from source + `MALLOC_ARENA_MAX=2`
- **Security**: Non-root user (UID 1000), minimal attack surface, Iron Bank / DISA-aligned base image

The production stage deliberately ships **no Node runtime** — JavaScript and CSS bundles are built
during the image build. Custom/corporate CA certificates are imported at build time from `./certs/`
(see `certs/README.md`), not mounted at runtime.

## Configuration

### Environment Variables

See [Environment Variables](../getting-started/environment-variables.md) for complete list.

Key variables for Docker:
- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Rails secret key
- `RAILS_ENV` - Set to `production` (already set in the image)
- `RAILS_FORCE_SSL` - `true` when a reverse proxy terminates TLS; `docker-compose.yml` defaults it to `false`
- `VULCAN_SESSION_TIMEOUT` - Session inactivity timeout (e.g., `15m`, `900`, `1h`). DoD standard: `15m`
- `IMAGE_NAME` - Image `docker compose` runs and pulls; set to `mitre/vulcan:release-latest` (or a
  specific release tag) to use the published image instead of building locally

The production environment logs to stdout unconditionally, so no logging variable is needed.

### Volumes

The application's working directory inside the container is `/rails`. Uploaded files live in Active
Storage's local disk service at `/rails/storage`.

`docker-compose.yml` keeps the database in a named volume:

```yaml
volumes:
  - vulcan_dbdata:/var/lib/postgresql
```

To persist uploads across container replacement, add a volume for the storage directory:

```yaml
volumes:
  - ./data/storage:/rails/storage
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

> **Important**: Set `RAILS_FORCE_SSL=true` in `.env` when a reverse proxy terminates TLS.
> `docker-compose.yml` defaults it to `false` for the HTTP quickstart.

`docker-compose.yml` also ships commented-out Caddy and nginx proxy profiles with
`Caddyfile.example` and `nginx.conf.example` as starting points — see the comments at the top of the
compose file.

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

The Docker entrypoint automatically runs `db:prepare` on every container start:

- **First startup**: Creates the database, loads `db/schema.rb`, runs seeds (demo data only when
  `VULCAN_SEED_DEMO_DATA=true`), bootstraps admin
- **Subsequent startups**: Runs pending migrations only (existing data is preserved)

No manual database initialization is needed. To run migrations manually:
```bash
docker compose run --rm web bundle exec rails db:migrate
```

> **Why `db:prepare` and not `db:migrate`?** `db:prepare` handles both fresh and existing databases. It is the Rails 8 standard pattern for Docker entrypoints. Unlike `db:schema:load`, `db:prepare` does NOT need `DISABLE_DATABASE_ENVIRONMENT_CHECK` — it calls `load_schema()` as a Ruby method, bypassing the protected environment check by design. See [Rails source: DatabaseTasks#initialize_database](https://github.com/rails/rails/blob/main/activerecord/lib/active_record/tasks/database_tasks.rb) for details.

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
# Check container health status (compose names the container <project>-web-1)
docker inspect --format='{{.State.Health.Status}}' vulcan-web-1

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
docker compose exec db pg_dump -U postgres vulcan_production > backup.sql

# Restore
docker compose exec -T db psql -U postgres vulcan_production < backup.sql
```

### Application Data

Uploaded files live in `/rails/storage` inside the container.

```bash
# Backup uploads
docker compose exec web tar -cz -C /rails storage > uploads-backup.tar.gz

# Restore uploads
docker compose exec -T web tar -xz -C /rails < uploads-backup.tar.gz
```

## Troubleshooting

### Common Issues

1. **Database connection failed**
   - Ensure PostgreSQL is running
   - Check DATABASE_URL format
   - Verify network connectivity

2. **Asset compilation errors**
   - Assets are compiled into the image at build time, and the production stage has no Node runtime,
     so `assets:precompile` cannot be re-run inside the container. Rebuild the image instead:
     `docker compose build web`

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