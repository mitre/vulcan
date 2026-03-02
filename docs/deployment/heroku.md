# Heroku Deployment

This guide covers deploying Vulcan to Heroku, a platform-as-a-service (PaaS) that enables developers to build and run applications entirely in the cloud.

## Prerequisites

- Heroku account (free tier available)
- Heroku CLI installed locally
- Git repository with Vulcan code
- PostgreSQL add-on (Heroku Postgres)

## Quick Deploy

### Deploy with Heroku Button

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/mitre/vulcan)

### Manual Deployment

1. **Create a new Heroku app**:
```bash
heroku create your-vulcan-app
```

2. **Add PostgreSQL database**:
```bash
heroku addons:create heroku-postgresql:mini
```

3. **Set required environment variables**:
```bash
# Ruby buildpack configuration
heroku config:set RAILS_ENV=production
heroku config:set RAILS_SERVE_STATIC_FILES=true
heroku config:set RAILS_LOG_TO_STDOUT=true

# Application configuration
heroku config:set SECRET_KEY_BASE=$(rails secret)
heroku config:set VULCAN_CONTACT_EMAIL=admin@example.com
heroku config:set VULCAN_APP_URL=https://your-vulcan-app.herokuapp.com
```

4. **Deploy the application**:
```bash
git push heroku main
```

Migrations run automatically via the Procfile release phase (`bundle exec rails db:migrate`). No manual migration step is needed.

5. **Create admin user** (choose one):

   **Option A** — First-user-admin (simplest):
   ```bash
   heroku config:set VULCAN_FIRST_USER_ADMIN=true
   ```
   Then register via the web UI — the first user becomes admin.

   **Option B** — Environment variable bootstrap:
   ```bash
   heroku config:set VULCAN_ADMIN_EMAIL=admin@example.com
   heroku config:set VULCAN_ADMIN_PASSWORD=SecurePassword123!
   ```
   Admin is created on the next deploy (hooked into `db:prepare` via Docker, or run manually with `heroku run rails admin:bootstrap`).

## Configuration

### Essential Environment Variables

```bash
# Database (automatically set by Heroku Postgres)
DATABASE_URL=postgres://...

# Rails configuration
SECRET_KEY_BASE=your-secret-key
RAILS_ENV=production
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true

# Vulcan configuration
VULCAN_CONTACT_EMAIL=admin@example.com
VULCAN_APP_URL=https://your-app.herokuapp.com
VULCAN_WELCOME_TEXT="Welcome to Vulcan"

# Email configuration (Community Best Practice)
# Simple setup: Most deployments only need VULCAN_CONTACT_EMAIL
# Following Rails community standard like OpenProject/Alonetone
VULCAN_CONTACT_EMAIL=support@yourcompany.com

# Recommended: Use professional email service (avoid Gmail SMTP)
# Option 1: Mailgun (Free tier: 100 emails/day)
heroku addons:create mailgun:starter
VULCAN_ENABLE_SMTP=true
VULCAN_SMTP_ADDRESS=smtp.mailgun.org
VULCAN_SMTP_PORT=587
VULCAN_SMTP_AUTHENTICATION=plain
# VULCAN_SMTP_SERVER_USERNAME automatically defaults to VULCAN_CONTACT_EMAIL
VULCAN_SMTP_SERVER_PASSWORD=your-mailgun-password
VULCAN_SMTP_DOMAIN=your-app.herokuapp.com
VULCAN_SMTP_ENABLE_STARTTLS_AUTO=true

# Option 2: SendGrid (if you need different SMTP username)
VULCAN_ENABLE_SMTP=true
VULCAN_SMTP_ADDRESS=smtp.sendgrid.net
VULCAN_SMTP_PORT=587
VULCAN_SMTP_AUTHENTICATION=plain
VULCAN_SMTP_SERVER_USERNAME=apikey  # Override when different from contact_email
VULCAN_SMTP_SERVER_PASSWORD=your-sendgrid-api-key
VULCAN_SMTP_DOMAIN=heroku.com
VULCAN_SMTP_ENABLE_STARTTLS_AUTO=true
```

### Classification Banner & Consent Modal

For DoD/government deployments, enable the classification banner and consent modal:

```bash
# Classification banner (top + bottom of every page)
heroku config:set VULCAN_BANNER_ENABLED=true
heroku config:set VULCAN_BANNER_TEXT=UNCLASSIFIED
heroku config:set VULCAN_BANNER_BACKGROUND_COLOR=#007a33
heroku config:set VULCAN_BANNER_TEXT_COLOR=#ffffff

# Consent/terms-of-use modal (blocks access until acknowledged)
heroku config:set VULCAN_CONSENT_ENABLED=true
heroku config:set VULCAN_CONSENT_VERSION=1
heroku config:set VULCAN_CONSENT_TITLE="Acceptable Use Policy"
heroku config:set VULCAN_CONSENT_CONTENT="By using this system you agree to the **acceptable use policy**."
heroku config:set VULCAN_CONSENT_TTL=0
```

Consent acknowledgment is tracked server-side in the Rails session (AC-8 compliant). `VULCAN_CONSENT_TTL=0` means consent is required every session (DoD default). Set to `24h` or `12h` for less strict environments. Consent content supports Markdown. Increment `VULCAN_CONSENT_VERSION` to re-prompt all users after policy changes.

See [Configuration](/getting-started/configuration#classification-banner) for the full DoD color table.

### Authentication Providers

For OAuth/OIDC authentication, add:

```bash
# GitHub OAuth
VULCAN_GITHUB_APP_ID=your-github-app-id
VULCAN_GITHUB_APP_SECRET=your-github-app-secret

# OIDC
VULCAN_ENABLE_OIDC=true
VULCAN_OIDC_ISSUER_URL=https://your-provider.com
VULCAN_OIDC_CLIENT_ID=your-client-id
VULCAN_OIDC_CLIENT_SECRET=your-client-secret
```

## Add-ons

### Recommended Add-ons

1. **Heroku Postgres** (Required)
   ```bash
   heroku addons:create heroku-postgresql:mini
   ```

2. **SendGrid** (Email service)
   ```bash
   heroku addons:create sendgrid:starter
   ```

3. **Papertrail** (Logging)
   ```bash
   heroku addons:create papertrail:choklad
   ```

4. **New Relic** (Application monitoring)
   ```bash
   heroku addons:create newrelic:wayne
   ```

5. **Heroku Scheduler** (Background jobs)
   ```bash
   heroku addons:create scheduler:standard
   ```

## Scaling

### Dyno Configuration

```bash
# Scale web dynos
heroku ps:scale web=1

# For production workloads
heroku ps:scale web=2:standard-2x

# Add worker dynos if needed
heroku ps:scale worker=1:standard-1x
```

### Database Scaling

```bash
# Upgrade database plan
heroku addons:upgrade heroku-postgresql:standard-0
```

## Maintenance

### Updates and Migrations

Migrations run automatically during the Procfile release phase on every deploy. Manual migration is rarely needed.

```bash
# Deploy updates (migrations run automatically)
git push heroku main

# Manual migration (only if needed)
heroku run rails db:migrate

# For large migrations, enable maintenance mode first
heroku maintenance:on
git push heroku main
heroku maintenance:off
```

### Backup and Restore

```bash
# Create backup
heroku pg:backups:capture

# List backups
heroku pg:backups

# Download backup
heroku pg:backups:download

# Restore from backup
heroku pg:backups:restore b001 DATABASE_URL
```

### Logs

```bash
# View recent logs
heroku logs --tail

# View specific process logs
heroku logs --source app --tail

# Export logs to file
heroku logs -n 1500 > production.log
```

## Review Apps

Review Apps create a temporary Heroku app for each pull request, with its own fresh database.

### How It Works

The `app.json` in the repository root configures review apps:

| Phase | Command | When | Purpose |
|-------|---------|------|---------|
| **Release** | `db:migrate` (Procfile) | Every deploy | Runs pending migrations (no-op on first deploy) |
| **Postdeploy** | `db:schema:load db:seed admin:bootstrap` | First deploy only | Loads schema, seeds data, creates admin |

The postdeploy uses `DISABLE_DATABASE_ENVIRONMENT_CHECK=1` because review apps run with `RAILS_ENV=production` and `db:schema:load` (the rake task) checks for protected environments. This flag is safe here — review apps always have fresh, empty databases.

> **Important**: `DISABLE_DATABASE_ENVIRONMENT_CHECK` must NEVER be set for production or staging. It only appears in the review app postdeploy script. See `spec/config/database_safety_spec.rb` for regression tests enforcing this.

### Database Strategy

| Environment | DB Command | Safety |
|-------------|-----------|--------|
| **Production** | `db:migrate` (Procfile release) | Only runs pending migrations, never destructive |
| **Staging** | `db:migrate` (Procfile release) | Same as production |
| **Review Apps** | `db:schema:load` (postdeploy, once) | Fresh DB only, flag scoped to one-time script |
| **Docker** | `db:prepare` (entrypoint) | Creates if missing, migrates if exists, no flag needed |

### Setup

1. The `app.json` is already configured in the repository root
2. Enable Review Apps in your Heroku Pipeline settings
3. Each PR will automatically get a review app with:
   - Fresh PostgreSQL database (Essential-0 plan)
   - Schema loaded from `db/schema.rb`
   - First-user-admin enabled (`VULCAN_FIRST_USER_ADMIN=true`)

## Troubleshooting

### Common Issues

1. **Assets not loading**
   ```bash
   heroku config:set RAILS_SERVE_STATIC_FILES=true
   heroku run rails assets:precompile
   ```

2. **Database connection errors**
   ```bash
   # Check database URL
   heroku config:get DATABASE_URL
   
   # Restart database
   heroku pg:restart
   ```

3. **Memory issues**
   ```bash
   # Check memory usage
   heroku ps
   
   # Scale to larger dyno
   heroku ps:resize web=standard-2x
   ```

4. **Deployment failures**
   ```bash
   # Check build log
   heroku builds:info
   
   # Clear build cache
   heroku builds:cache:purge
   ```

## Security Considerations

1. **Use strong SECRET_KEY_BASE**
   ```bash
   heroku config:set SECRET_KEY_BASE=$(openssl rand -hex 64)
   ```

2. **Enable HTTPS only**
   - Heroku provides SSL certificates automatically
   - Force SSL in Rails configuration

3. **Restrict database access**
   - Use Heroku Private Spaces for sensitive data
   - Enable database encryption at rest

4. **Regular updates**
   ```bash
   # Update Ruby buildpack
   heroku buildpacks:set heroku/ruby
   
   # Update dependencies
   bundle update --conservative
   ```

## Cost Optimization

- Use Eco dynos for development/staging ($5/month)
- Schedule dyno sleeping for non-production apps
- Use Heroku Postgres Mini for small projects ($5/month)
- Monitor usage with `heroku ps:type`

## Additional Resources

- [Heroku Ruby Support](https://devcenter.heroku.com/articles/ruby-support)
- [Heroku Postgres Documentation](https://devcenter.heroku.com/articles/heroku-postgresql)
- [Rails on Heroku Guide](https://devcenter.heroku.com/articles/getting-started-with-rails7)