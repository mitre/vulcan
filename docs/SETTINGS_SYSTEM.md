# Vulcan Settings System

## Overview

Vulcan uses `rails-settings-cached` to provide a flexible, database-backed configuration system that supports both environment variable defaults and runtime configuration changes through the admin interface.

## How It Works

### Precedence Model
Settings follow this precedence order (highest to lowest):
1. **Database Value** - Set via admin interface or API
2. **Environment Variable** - Set in deployment configuration
3. **Hardcoded Default** - Fallback value in the code

### Example
```ruby
# Environment variable: VULCAN_ENABLE_OIDC=true
# Database value: (none set)
Setting.oidc_enabled  # => true (from environment variable)

# Admin sets OIDC to false via web interface
# Database value: false
Setting.oidc_enabled  # => false (database overrides environment)

# Admin deletes the setting via admin interface
# Database value: (deleted)
Setting.oidc_enabled  # => true (falls back to environment variable)
```

### Dynamic Configuration
- **No Restart Required**: All setting changes take effect immediately
- **Runtime Flexibility**: Admin interface can override deployment defaults
- **Infrastructure as Code**: Environment variables provide deployment configuration

## Settings Reference

### Authentication Settings (`Setting.local_login.*`)

| Setting | Type | Environment Variable | Default | Description |
|---------|------|---------------------|---------|-------------|
| `local_login_enabled` | Boolean | `VULCAN_ENABLE_LOCAL_LOGIN` | `true` | Enable local username/password authentication |
| `local_login_session_timeout` | Integer | `VULCAN_SESSION_TIMEOUT` | `60` | Session timeout in minutes |
| `local_login_email_confirmation` | Boolean | `VULCAN_ENABLE_EMAIL_CONFIRMATION` | `false` | Require email confirmation for new accounts |

### OIDC Settings (`Setting.oidc.*`)

| Setting | Type | Environment Variable | Default | Description |
|---------|------|---------------------|---------|-------------|
| `oidc_enabled` | Boolean | `VULCAN_ENABLE_OIDC` | `false` | Enable OpenID Connect authentication |
| `oidc_discovery` | Boolean | `VULCAN_OIDC_DISCOVERY` | `true` | Use OIDC discovery for automatic configuration |
| `oidc_strategy` | String | - | `openid_connect` | OmniAuth strategy name |
| `oidc_title` | String | `VULCAN_OIDC_PROVIDER_TITLE` | `Single Sign-On` | Display name for login button |
| `oidc_args` | Hash | Multiple | (see below) | Complete OIDC provider configuration |

#### OIDC Configuration Hash (`oidc_args`)
```ruby
{
  name: :oidc,
  scope: [:openid, :email, :profile],
  uid_field: 'sub',
  response_type: :code,
  discovery: true,  # from VULCAN_OIDC_DISCOVERY
  issuer: "https://your-provider.com",  # from VULCAN_OIDC_ISSUER_URL
  client_auth_method: :secret,
  client_options: {
    identifier: "your-client-id",  # from VULCAN_OIDC_CLIENT_ID
    secret: "your-client-secret",  # from VULCAN_OIDC_CLIENT_SECRET
    redirect_uri: "https://vulcan.example.com/users/auth/oidc/callback"  # from VULCAN_OIDC_REDIRECT_URI
  }
}
```

### LDAP Settings (`Setting.ldap.*`)

| Setting | Type | Environment Variable | Default | Description |
|---------|------|---------------------|---------|-------------|
| `ldap_enabled` | Boolean | `VULCAN_ENABLE_LDAP` | `false` | Enable LDAP authentication |
| `ldap_servers` | Hash | Multiple | (see below) | LDAP server configuration |

#### LDAP Configuration Hash (`ldap_servers`)
```ruby
{
  main: {
    host: "ldap.example.com",     # from VULCAN_LDAP_HOST
    port: 389,                    # from VULCAN_LDAP_PORT
    method: :plain,               # from VULCAN_LDAP_ENCRYPTION
    base: "ou=people,dc=example,dc=com",  # from VULCAN_LDAP_BASE
    bind_dn: "cn=admin,dc=example,dc=com",  # from VULCAN_LDAP_BIND_DN
    password: "admin-password",   # from VULCAN_LDAP_ADMIN_PASS
    uid: "uid",                  # from VULCAN_LDAP_UID
    title: "LDAP"                # from VULCAN_LDAP_TITLE
  }
}
```

### SMTP Settings (`Setting.smtp.*`)

| Setting | Type | Environment Variable | Default | Description |
|---------|------|---------------------|---------|-------------|
| `smtp_enabled` | Boolean | `VULCAN_ENABLE_SMTP` | `false` | Enable SMTP email delivery |
| `smtp_settings` | Hash | Multiple | (see below) | Complete SMTP configuration |

#### SMTP Configuration Hash (`smtp_settings`)
```ruby
{
  address: "smtp.example.com",      # from VULCAN_SMTP_ADDRESS
  port: 587,                        # from VULCAN_SMTP_PORT
  domain: "example.com",            # from VULCAN_SMTP_DOMAIN
  user_name: "smtp-user",           # from VULCAN_SMTP_USERNAME
  password: "smtp-password",        # from VULCAN_SMTP_PASSWORD
  authentication: :plain,           # from VULCAN_SMTP_AUTHENTICATION
  enable_starttls_auto: true        # from VULCAN_SMTP_ENABLE_STARTTLS_AUTO
}
```

### Slack Settings (`Setting.slack.*`)

| Setting | Type | Environment Variable | Default | Description |
|---------|------|---------------------|---------|-------------|
| `slack_enabled` | Boolean | `VULCAN_ENABLE_SLACK` | `false` | Enable Slack integration |
| `slack_api_token` | String | `VULCAN_SLACK_API_TOKEN` | - | Slack API token for notifications |

### General Settings

| Setting | Type | Environment Variable | Default | Description |
|---------|------|---------------------|---------|-------------|
| `app_url` | String | `VULCAN_APP_URL` | - | Base URL for the application |
| `contact_email` | String | `VULCAN_CONTACT_EMAIL` | - | Contact email for system notifications |

## Container Deployment

### Environment Variable Setup
```bash
# Required for production
VULCAN_APP_URL=https://vulcan.example.com

# Authentication (choose one or more)
VULCAN_ENABLE_LOCAL_LOGIN=true
VULCAN_ENABLE_OIDC=true
VULCAN_ENABLE_LDAP=true

# OIDC Configuration
VULCAN_OIDC_ISSUER_URL=https://your-provider.com
VULCAN_OIDC_CLIENT_ID=your-client-id
VULCAN_OIDC_CLIENT_SECRET=your-client-secret
VULCAN_OIDC_REDIRECT_URI=https://vulcan.example.com/users/auth/oidc/callback

# LDAP Configuration
VULCAN_LDAP_HOST=ldap.example.com
VULCAN_LDAP_PORT=389
VULCAN_LDAP_BASE=ou=people,dc=example,dc=com
VULCAN_LDAP_BIND_DN=cn=admin,dc=example,dc=com
VULCAN_LDAP_ADMIN_PASS=admin-password

# SMTP Configuration
VULCAN_ENABLE_SMTP=true
VULCAN_SMTP_ADDRESS=smtp.example.com
VULCAN_SMTP_USERNAME=smtp-user
VULCAN_SMTP_PASSWORD=smtp-password

# Slack Integration
VULCAN_ENABLE_SLACK=true
VULCAN_SLACK_API_TOKEN=xoxb-your-slack-token
```

### Docker Compose Example
```yaml
version: '3.8'
services:
  vulcan:
    image: vulcan:latest
    environment:
      - VULCAN_APP_URL=https://vulcan.example.com
      - VULCAN_ENABLE_OIDC=true
      - VULCAN_OIDC_ISSUER_URL=https://your-provider.com
      - VULCAN_OIDC_CLIENT_ID=your-client-id
      - VULCAN_OIDC_CLIENT_SECRET=your-client-secret
      # ... other settings
```

## Runtime Configuration

### Admin Interface
Settings can be modified through the admin interface at `/admin/settings` (admin users only).

### API Access
```ruby
# Reading settings
Setting.oidc_enabled                    # => true/false
Setting.oidc_args                       # => hash
Setting.smtp_settings                   # => hash

# Setting values (programmatically)
Setting.oidc_enabled = false            # Disable OIDC
Setting.slack_api_token = "new-token"   # Update Slack token

# Deleting settings (falls back to environment/default)
Setting.destroy(:oidc_enabled)          # Falls back to environment variable
```

## Implementation Details

### OmniAuth Dynamic Configuration
Vulcan uses OmniAuth's setup phase to configure providers dynamically:

```ruby
# In config/initializers/devise.rb
config.omniauth(:ldap,
  setup: lambda { |env|
    if Setting.ldap_enabled && Setting.ldap_servers.present?
      strategy = env['omniauth.strategy']
      strategy.options.deep_merge!(Setting.ldap_servers.values.first)
    end
  }
)
```

This allows provider configuration to change at runtime without restart.

### Avoiding Autoloading Issues
All Setting model access in initializers is wrapped in `Rails.application.reloader.to_prepare` blocks to avoid Rails autoloading warnings.

## Migration from settingslogic

If migrating from the old settingslogic system:

1. **Environment variables remain the same** - no changes needed for container deployments
2. **Database values override environment variables** - existing behavior preserved
3. **Admin interface works immediately** - no restart required for changes
4. **Nested API compatibility** - `Settings.oidc.enabled` still works via compatibility layer (if implemented)

## Troubleshooting

### Common Issues

**Setting not taking effect:**
- Check precedence: database value overrides environment variable
- Verify setting name matches exactly (case sensitive)
- For authentication providers, ensure the provider is enabled

**Provider not appearing on login page:**
- Verify both `enabled` flag and required configuration are present
- Check Rails logs for validation errors during startup

**Environment variables ignored:**
- Database value is set and overriding environment variable
- Delete database setting to fall back to environment variable

### Debugging
```ruby
# Check current value and source
Setting.oidc_enabled                    # Current effective value
RailsSettings::Settings.count           # Number of database overrides
ENV['VULCAN_ENABLE_OIDC']              # Environment variable value

# Clear database override
Setting.destroy(:oidc_enabled)          # Falls back to environment default
```