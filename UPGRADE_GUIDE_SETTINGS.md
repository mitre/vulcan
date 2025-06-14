# Upgrade Guide: Migrating from Settingslogic to Rails-Settings-Cached

This guide helps existing Vulcan installations upgrade to the new settings system introduced in [version X.X.X].

## Overview of Changes

We've replaced the deprecated `settingslogic` gem with `rails-settings-cached` to enable:
- Ruby 3+ compatibility
- Runtime configuration changes without restart
- Database-backed settings with environment variable defaults
- Foundation for future admin UI

## Breaking Changes

1. **New Database Table Required**: A `settings` table must be created
2. **Configuration Storage**: Settings are now stored in the database instead of YAML files
3. **Removed Files**:
   - `config/vulcan.default.yml` - No longer used
   - `config/app.yml` - No longer used

## Upgrade Steps

### 1. Update Your Code

```bash
git pull origin master
bundle install
```

### 2. Run Database Migration

This creates the new settings table:

```bash
bundle exec rails db:migrate
```

### 3. Verify Environment Variables

All settings now use environment variables as defaults. Ensure your deployment has these set:

**Essential Variables:**
- `VULCAN_CONTACT_EMAIL` (defaults to 'admin@vulcan.local')
- `VULCAN_APP_URL` (for email links)

**Authentication (if using):**
- OIDC: `VULCAN_OIDC_ISSUER_URL`, `VULCAN_OIDC_CLIENT_ID`, `VULCAN_OIDC_CLIENT_SECRET`
- LDAP: `VULCAN_LDAP_HOST`, `VULCAN_LDAP_BASE`, `VULCAN_LDAP_BIND_DN`, etc.
- Local Login: `VULCAN_ENABLE_LOCAL_LOGIN` (defaults to true)

**Optional Services:**
- SMTP: `VULCAN_ENABLE_SMTP`, `VULCAN_SMTP_ADDRESS`, etc.
- Slack: `VULCAN_ENABLE_SLACK_COMMS`, `VULCAN_SLACK_API_TOKEN`, etc.

### 4. Import Existing Settings (Optional)

If you had custom settings in your old YAML files, you can import them via Rails console:

```ruby
# Start Rails console
bundle exec rails console

# Example: Import custom welcome text
Setting.welcome_text = "Your custom welcome message"

# Example: Override SMTP settings
Setting.smtp_enabled = true
Setting.smtp_settings = {
  address: 'smtp.example.com',
  port: 587,
  # ... other settings
}

# View all current settings
Setting.all
```

### 5. Remove Old Configuration Files

After verifying the application works correctly:

```bash
# Remove old config files (already removed from git)
rm -f config/vulcan.default.yml
rm -f config/app.yml
```

## Docker Deployments

Update your docker-compose.yml or Kubernetes configs to include all required environment variables. Example:

```yaml
environment:
  - VULCAN_ENABLE_OIDC=true
  - VULCAN_OIDC_ISSUER_URL=https://your-provider.com
  - VULCAN_OIDC_CLIENT_ID=your-client-id
  - VULCAN_OIDC_CLIENT_SECRET=your-client-secret
  # ... other settings
```

## Heroku Deployments

Set environment variables using Heroku CLI:

```bash
heroku config:set VULCAN_ENABLE_OIDC=true
heroku config:set VULCAN_OIDC_ISSUER_URL=https://your-provider.com
# ... etc
```

## Troubleshooting

### Application Won't Start

1. **Check migrations ran successfully**:
   ```bash
   bundle exec rails db:migrate:status
   ```

2. **Verify settings table exists**:
   ```bash
   bundle exec rails runner "puts Setting.count"
   ```

3. **Check for missing environment variables** in logs

### Settings Not Taking Effect

1. **Environment variables take precedence** over database values
2. **Clear Rails cache** after changing settings:
   ```bash
   bundle exec rails runner "Rails.cache.clear"
   ```

3. **Restart application** after changing environment variables

### OIDC/LDAP Login Not Working

1. **Verify settings loaded correctly**:
   ```ruby
   bundle exec rails console
   Setting.oidc_enabled
   Setting.oidc_args
   Setting.ldap_enabled
   Setting.ldap_servers
   ```

2. **Check logs** for initialization errors during startup

## Rollback Plan

If you need to rollback:

1. Checkout previous version
2. Restore old Gemfile/Gemfile.lock
3. Run `bundle install`
4. Rollback the migration: `bundle exec rails db:rollback`

## Getting Help

- Check logs: `tail -f log/production.log`
- Report issues: https://github.com/mitre/vulcan/issues
- Documentation: See CONFIGURATION.md for full settings reference

## Benefits After Upgrading

- ✅ Ruby 3.x compatibility
- ✅ Change settings without restart via console
- ✅ Cleaner configuration management
- ✅ Foundation for future admin UI
- ✅ Better performance with cached settings