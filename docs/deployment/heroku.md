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

5. **Run database migrations**:
```bash
heroku run rails db:migrate
```

6. **Create admin user** (optional):
```bash
heroku run rails c
# In Rails console:
User.create!(
  email: 'admin@example.com',
  password: 'secure_password_here',
  admin: true,
  confirmed_at: Time.now
)
```

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

# Email configuration (if using SendGrid)
VULCAN_ENABLE_SMTP=true
VULCAN_SMTP_ADDRESS=smtp.sendgrid.net
VULCAN_SMTP_PORT=587
VULCAN_SMTP_AUTHENTICATION=plain
VULCAN_SMTP_SERVER_USERNAME=apikey
VULCAN_SMTP_SERVER_PASSWORD=your-sendgrid-api-key
VULCAN_SMTP_DOMAIN=heroku.com
VULCAN_SMTP_ENABLE_STARTTLS_AUTO=true
```

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

```bash
# Enable maintenance mode
heroku maintenance:on

# Deploy updates
git push heroku main

# Run migrations
heroku run rails db:migrate

# Disable maintenance mode
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

Enable Review Apps for pull request previews:

1. Create `app.json` in repository root:
```json
{
  "name": "Vulcan",
  "scripts": {
    "postdeploy": "bundle exec rails db:schema:load"
  },
  "env": {
    "RAILS_ENV": {
      "value": "production"
    },
    "SECRET_KEY_BASE": {
      "generator": "secret"
    }
  },
  "formation": {
    "web": {
      "quantity": 1,
      "size": "standard-1x"
    }
  },
  "addons": [
    "heroku-postgresql:mini"
  ],
  "buildpacks": [
    {
      "url": "heroku/nodejs"
    },
    {
      "url": "heroku/ruby"
    }
  ]
}
```

2. Enable Review Apps in Heroku Pipeline settings

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