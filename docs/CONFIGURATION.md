# Vulcan Configuration Guide

Vulcan uses a flexible configuration system that supports both environment variables and database-backed settings through the `rails-settings-cached` gem. This allows for runtime configuration changes without application restarts.

[**Installation**](index.md) | [**Configuration**](CONFIGURATION.md)

## Configuration System Overview

Vulcan's configuration follows a hierarchy:
1. **Environment Variables** - Set at deployment time (highest priority)
2. **Database Settings** - Can be changed at runtime via console or future admin UI
3. **Default Values** - Coded defaults in the Setting model

### Accessing Settings

All settings are accessed through the `Settings` API:
```ruby
Settings.local_login.enabled        # Check if local login is enabled
Settings.smtp.enabled              # Check if SMTP is enabled
Settings.contact_email             # Get contact email address
```

### Modifying Settings at Runtime

Settings can be modified via Rails console:
```ruby
Settings.local_login.enabled = false    # Disable local login
Settings.contact_email = "admin@example.com"  # Change contact email
```

## Index

- [Welcome Text and Contact Email](#welcome-text-and-contact-email)
- [SMTP Configuration](#smtp-configuration)
- [Local Login](#local-login)
- [User Registration](#user-registration)
- [Project Permissions](#project-permissions)
- [LDAP Configuration](#ldap-configuration)
- [OIDC Configuration](#oidc-configuration)
- [Slack Integration](#slack-integration)

## Welcome Text and Contact Email

Basic application settings for user communication:

| Setting | Environment Variable | Default | Description |
|---------|---------------------|---------|-------------|
| `Settings.welcome_text` | `VULCAN_WELCOME_TEXT` | `nil` | Custom text shown on homepage below "What is Vulcan" |
| `Settings.contact_email` | `VULCAN_CONTACT_EMAIL` | `admin@vulcan.local` | Reply-to email for notifications |
| `Settings.app_url` | `VULCAN_APP_URL` | `nil` | Base URL for email links |

## SMTP Configuration

Email delivery settings:

| Setting | Environment Variable | Default | Description |
|---------|---------------------|---------|-------------|
| `Settings.smtp.enabled` | `VULCAN_ENABLE_SMTP` | `false` | Enable SMTP email delivery |
| `Settings.smtp.settings` | Multiple (see below) | `{}` | SMTP server configuration |

SMTP settings hash includes:
- **address**: `VULCAN_SMTP_ADDRESS` - Mail server hostname
- **port**: `VULCAN_SMTP_PORT` - Mail server port
- **domain**: `VULCAN_SMTP_DOMAIN` - HELO domain
- **authentication**: `VULCAN_SMTP_AUTHENTICATION` - Auth method (plain, login, cram_md5)
- **user_name**: `VULCAN_SMTP_SERVER_USERNAME` - SMTP username
- **password**: `VULCAN_SMTP_SERVER_PASSWORD` - SMTP password
- **enable_starttls_auto**: `VULCAN_SMTP_ENABLE_STARTTLS_AUTO` - Auto-start TLS
- **tls**: `VULCAN_SMTP_TLS` - Force TLS connection

## Local Login

Traditional username/password authentication:

| Setting | Environment Variable | Default | Description |
|---------|---------------------|---------|-------------|
| `Settings.local_login.enabled` | `VULCAN_ENABLE_LOCAL_LOGIN` | `true` | Allow local authentication |
| `Settings.local_login.email_confirmation` | `VULCAN_ENABLE_EMAIL_CONFIRMATION` | `false` | Require email verification |
| `Settings.local_login.session_timeout` | `VULCAN_SESSION_TIMEOUT` | `60` | Session timeout in minutes |

## User Registration

Control user self-registration:

| Setting | Environment Variable | Default | Description |
|---------|---------------------|---------|-------------|
| `Settings.user_registration.enabled` | `VULCAN_ENABLE_USER_REGISTRATION` | `true` | Allow new user signups |

## Project Permissions

Control project creation permissions:

| Setting | Environment Variable | Default | Description |
|---------|---------------------|---------|-------------|
| `Settings.project.create_permission_enabled` | `VULCAN_PROJECT_CREATE_PERMISSION_ENABLED` | `true` | Allow users to create projects |

## LDAP Configuration

LDAP/Active Directory authentication:

| Setting | Environment Variable | Default | Description |
|---------|---------------------|---------|-------------|
| `Settings.ldap.enabled` | `VULCAN_ENABLE_LDAP` | `false` | Enable LDAP authentication |
| `Settings.ldap.servers` | Multiple (see below) | `{}` | LDAP server configuration |

LDAP server configuration is stored as a hash. Primary server settings:
- **host**: `VULCAN_LDAP_HOST` - LDAP server hostname
- **port**: `VULCAN_LDAP_PORT` - LDAP port (default: 389)
- **title**: `VULCAN_LDAP_TITLE` - Display name for login button
- **uid**: `VULCAN_LDAP_ATTRIBUTE` - Username attribute (default: uid)
- **encryption**: `VULCAN_LDAP_ENCRYPTION` - Connection encryption (plain, simple_tls, start_tls)
- **bind_dn**: `VULCAN_LDAP_BIND_DN` - Bind DN for LDAP queries
- **password**: `VULCAN_LDAP_ADMIN_PASS` - Bind password
- **base**: `VULCAN_LDAP_BASE` - Search base DN

## OIDC Configuration

OpenID Connect single sign-on:

| Setting | Environment Variable | Default | Description |
|---------|---------------------|---------|-------------|
| `Settings.oidc.enabled` | `VULCAN_ENABLE_OIDC` | `false` | Enable OIDC authentication |
| `Settings.oidc.discovery` | `VULCAN_OIDC_DISCOVERY` | `true` | Use OIDC discovery |
| `Settings.oidc.title` | `VULCAN_OIDC_PROVIDER_TITLE` | `Single Sign-On` | Display name for login |
| `Settings.oidc.strategy` | - | `openid_connect` | OmniAuth strategy name |
| `Settings.oidc.args` | Multiple (see below) | `{}` | OIDC configuration |

OIDC args hash includes:
- **issuer**: `VULCAN_OIDC_ISSUER_URL` - OIDC provider URL
- **client_id**: `VULCAN_OIDC_CLIENT_ID` - OAuth client ID
- **client_secret**: `VULCAN_OIDC_CLIENT_SECRET` - OAuth client secret
- **redirect_uri**: `VULCAN_OIDC_REDIRECT_URI` - Callback URL
- **scope**: Requested scopes (default: openid email profile)

When discovery is disabled, manual endpoints can be configured:
- **authorization_endpoint**: `VULCAN_OIDC_AUTHORIZATION_URL`
- **token_endpoint**: `VULCAN_OIDC_TOKEN_URL`
- **userinfo_endpoint**: `VULCAN_OIDC_USERINFO_URL`
- **jwks_uri**: `VULCAN_OIDC_JWKS_URI`

## Slack Integration

Slack notifications for application events:

| Setting | Environment Variable | Default | Description |
|---------|---------------------|---------|-------------|
| `Settings.slack.enabled` | `VULCAN_ENABLE_SLACK_COMMS` | `false` | Enable Slack integration |
| `Settings.slack.api_token` | `VULCAN_SLACK_API_TOKEN` | `nil` | Slack API token |
| `Settings.slack.channel_id` | `VULCAN_SLACK_CHANNEL_ID` | `nil` | Target channel ID |

## Migration from settingslogic

As of [PR #676], Vulcan has migrated from settingslogic to rails-settings-cached. The API remains the same (`Settings.*`), but settings can now be modified at runtime and stored in the database. Environment variables still take precedence for security-sensitive settings.

### Key Differences:
- Settings are now stored in the `settings` database table
- Runtime modifications are possible without restart
- Environment variables provide defaults and overrides
- Future admin UI can modify non-sensitive settings