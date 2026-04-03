# Troubleshooting

Common issues and solutions across all deployment types.

## Database

### Migration fails with "relation already exists"

```bash
# Check migration status
bundle exec rails db:migrate:status

# If stuck, verify schema version matches
bundle exec rails db:version
```

### "FATAL: role postgres does not exist"

Create the PostgreSQL role:
```bash
createuser -s postgres
```

Or use your system username:
```bash
DATABASE_URL=postgres://$(whoami)@localhost/vulcan_vue_development
```

### Database connection refused

Verify PostgreSQL is running:
```bash
# macOS
brew services list | grep postgresql

# Linux
systemctl status postgresql
```

## Authentication

### OIDC callback fails with "Invalid credentials"

1. Verify `VULCAN_OIDC_REDIRECT_URI` matches exactly what's configured in your identity provider
2. Check the issuer URL responds: `curl -s https://your-domain/.well-known/openid-configuration`
3. Verify client ID and secret are correct (no trailing whitespace)

### "Provider conflict" error on login

A user with the same email already exists under a different auth provider. An admin must resolve this manually — Vulcan prevents silent account merging for security.

### Locked out of admin account

```bash
# Method 1: Rails console
bundle exec rails console
User.find_by(email: 'admin@example.com').unlock_access!

# Method 2: Wait for auto-unlock (default 15 minutes)

# Method 3: Create new admin
VULCAN_ADMIN_EMAIL=newadmin@example.com bundle exec rails db:prepare
```

## Assets / Frontend

### "Module not found" or blank page after update

```bash
yarn install
yarn build
# If using dev server:
foreman start -f Procfile.dev
```

### esbuild watch not picking up changes

HAML template changes require a server restart. Vue component changes should be picked up by `yarn build:watch`. If not:

```bash
# Kill any stale watch processes
pkill -f esbuild
yarn build:watch
```

## Docker

### Container exits immediately

Check logs:
```bash
docker compose logs web
```

Common causes:
- Missing `SECRET_KEY_BASE` — run `./setup-docker-secrets.sh`
- Database not ready — the entrypoint waits for PostgreSQL, but check `docker compose logs db`

### "Permission denied" on mounted volumes

```bash
# Fix ownership
docker compose run --rm web chown -R $(id -u):$(id -g) /app/storage
```

### Health check failing

```bash
# Check health endpoint directly
curl -f http://localhost:3000/up

# Check detailed health
curl http://localhost:3000/health_check
```

## Heroku

### "Slug size too large"

The `.slugignore` file excludes test files and dev configs. If still too large:
```bash
# Check what's taking space
heroku run du -sh */ --app your-app
```

### Review app database issues

Review apps use `db:schema:load` (not `db:migrate`). If schema is out of date:
```bash
# Destroy and recreate the review app
heroku reviewapps:disable --app your-pipeline
heroku reviewapps:enable --app your-pipeline
```

## Performance

### Slow page loads

1. Check database query count: enable `config.log_level = :debug` and look for N+1 queries
2. Verify `RAILS_MAX_THREADS` and `WEB_CONCURRENCY` are set appropriately
3. For Docker: ensure jemalloc is enabled (default in production Dockerfile)

### Rule editor feels sluggish

Large components (500+ rules) can be slow. Workarounds:
- Use status/severity filters to reduce visible rules
- Use the search bar for quick navigation
- Close sidebars (History, Reviews) when not needed

## Getting Help

- **GitHub Issues**: [github.com/mitre/vulcan/issues](https://github.com/mitre/vulcan/issues)
- **SAF Community**: [saf.mitre.org](https://saf.mitre.org)
