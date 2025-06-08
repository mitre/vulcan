# Vulcan Environment Variables

This document lists all environment variables that can be used to configure Vulcan.

## System Configuration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_CONFIG` | Override path to vulcan.yml config file | `config/vulcan.yml` | `/etc/vulcan/config.yml` |
| `VULCAN_ENV` | Override Rails environment | Uses `RAILS_ENV` | `production` |

## Database Configuration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `DATABASE_URL` | PostgreSQL connection string | - | `postgres://user:pass@localhost:5432/vulcan_development` |
| `VULCAN_VUE_DATABASE_PASSWORD` | PostgreSQL password (production only) | - | `postgres_password` |

## General Application Settings

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_APP_URL` | Application URL | `http://localhost:3000` | `https://vulcan.example.com` |
| `VULCAN_WELCOME_TEXT` | Welcome message on login page | `Welcome to Vulcan` | `Welcome to MITRE Vulcan` |
| `VULCAN_CONTACT_EMAIL` | Contact email for notifications | `do_not_reply@vulcan` | `admin@example.com` |

## Authentication Settings

### Local Login
| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_ENABLE_LOCAL_LOGIN` | Enable local username/password login | `true` | `true` or `false` |
| `VULCAN_ENABLE_EMAIL_CONFIRMATION` | Require email confirmation for new users | `false` | `true` or `false` |
| `VULCAN_SESSION_TIMEOUT` | Session timeout in minutes | `60` | `120` |

### User Registration
| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_ENABLE_USER_REGISTRATION` | Allow new users to register | `true` | `true` or `false` |

### OIDC/OAuth (e.g., Okta)
| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_ENABLE_OIDC` | Enable OIDC authentication | `false` | `true` or `false` |
| `VULCAN_OIDC_PROVIDER_TITLE` | Display name for OIDC provider | `OIDC Provider` | `Okta` |
| `VULCAN_OIDC_ISSUER_URL` | OIDC issuer URL | - | `https://dev-12345.okta.com` |
| `VULCAN_OIDC_HOST` | OIDC provider hostname | - | `dev-12345.okta.com` |
| `VULCAN_OIDC_CLIENT_ID` | OIDC client ID | - | `0oa1b2c3d4e5f6g7h8i9j` |
| `VULCAN_OIDC_CLIENT_SECRET` | OIDC client secret | - | `secret_key_here` |
| `VULCAN_OIDC_REDIRECT_URI` | OIDC redirect URI | - | `https://vulcan.example.com/users/auth/oidc/callback` |
| `VULCAN_OIDC_AUTHORIZATION_URL` | OIDC authorization endpoint | - | `https://dev-12345.okta.com/oauth2/default/v1/authorize` |
| `VULCAN_OIDC_TOKEN_URL` | OIDC token endpoint | - | `https://dev-12345.okta.com/oauth2/default/v1/token` |
| `VULCAN_OIDC_USERINFO_URL` | OIDC userinfo endpoint | - | `https://dev-12345.okta.com/oauth2/default/v1/userinfo` |
| `VULCAN_OIDC_JWKS_URI` | OIDC JWKS endpoint | - | `https://dev-12345.okta.com/oauth2/default/v1/keys` |
| `VULCAN_OIDC_PORT` | OIDC provider port | `443` | `443` |
| `VULCAN_OIDC_SCHEME` | OIDC provider scheme | `https` | `https` |
| `VULCAN_OIDC_CLIENT_SIGNING_ALG` | OIDC signing algorithm | `RS256` | `RS256` |
| `VULCAN_OIDC_PROMPT` | OIDC prompt parameter | - | `login` (forces re-authentication) |

### LDAP
| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_ENABLE_LDAP` | Enable LDAP authentication | `false` | `true` or `false` |
| `VULCAN_LDAP_HOST` | LDAP server hostname | `localhost` | `ldap.example.com` |
| `VULCAN_LDAP_PORT` | LDAP server port | `389` | `636` |
| `VULCAN_LDAP_TITLE` | Display name for LDAP | `LDAP` | `Corporate LDAP` |
| `VULCAN_LDAP_ATTRIBUTE` | LDAP attribute for user lookup | `uid` | `sAMAccountName` |
| `VULCAN_LDAP_ENCRYPTION` | LDAP encryption method | `plain` | `simple_tls` or `start_tls` |
| `VULCAN_LDAP_BIND_DN` | LDAP bind DN | - | `cn=admin,dc=example,dc=com` |
| `VULCAN_LDAP_ADMIN_PASS` | LDAP bind password | - | `ldap_password` |
| `VULCAN_LDAP_BASE` | LDAP search base | - | `dc=example,dc=com` |

## Email/SMTP Settings

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_ENABLE_SMTP` | Enable SMTP for sending emails | `false` | `true` or `false` |
| `VULCAN_SMTP_ADDRESS` | SMTP server address | - | `smtp.gmail.com` |
| `VULCAN_SMTP_PORT` | SMTP server port | - | `587` |
| `VULCAN_SMTP_DOMAIN` | SMTP domain | - | `example.com` |
| `VULCAN_SMTP_SERVER_USERNAME` | SMTP username | - | `notifications@example.com` |
| `VULCAN_SMTP_SERVER_PASSWORD` | SMTP password | - | `smtp_password` |
| `VULCAN_SMTP_AUTHENTICATION` | SMTP authentication method | - | `plain` |
| `VULCAN_SMTP_OPENSSL_VERIFY_MODE` | OpenSSL verify mode for SMTP | - | `none` |
| `VULCAN_SMTP_TLS` | Use TLS for SMTP | - | `true` or `false` |
| `VULCAN_SMTP_ENABLE_STARTTLS_AUTO` | Enable STARTTLS auto | - | `true` or `false` |

## Slack Integration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_ENABLE_SLACK_COMMS` | Enable Slack notifications | `false` | `true` or `false` |
| `VULCAN_SLACK_API_TOKEN` | Slack API token | - | `xoxb-your-token` |
| `VULCAN_SLACK_CHANNEL_ID` | Slack channel ID | - | `C1234567890` |

## Project Settings

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_PROJECT_CREATE_PERMISSION_ENABLED` | Require permission to create projects | `true` | `true` or `false` |

## Development Environment

For local development, create a `.env` file in the project root with your settings:

```bash
# Database
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/vulcan_vue_development

# Enable OIDC (example for Okta)
VULCAN_ENABLE_OIDC=true
VULCAN_OIDC_PROVIDER_TITLE=Okta
VULCAN_OIDC_ISSUER_URL=https://dev-12345.okta.com
VULCAN_OIDC_HOST=dev-12345.okta.com
VULCAN_OIDC_CLIENT_ID=your_client_id
VULCAN_OIDC_CLIENT_SECRET=your_client_secret

# Disable local login when using OIDC
VULCAN_ENABLE_LOCAL_LOGIN=false
```

## Production Environment

In production, set these as actual environment variables through your deployment platform (Docker, Kubernetes, etc.) rather than using `.env` files.

## Docker Deployment

When using Docker, you can set environment variables in:
- `docker-compose.yml` using the `environment:` section
- `.env-prod` file referenced in docker-compose.yml
- Container runtime with `-e` flags

## Rails/Framework Settings

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `RAILS_MASTER_KEY` | Rails master key for credentials | - | Generated by Rails |
| `RAILS_LOG_TO_STDOUT` | Log to stdout instead of files | - | `true` |
| `RAILS_SERVE_STATIC_FILES` | Serve static files in production | - | `true` |
| `FORCE_SSL` | Force SSL connections | - | `true` |

## GitHub OAuth (Optional)

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `GITHUB_APP_ID` | GitHub OAuth app ID | - | `your_github_app_id` |
| `GITHUB_APP_SECRET` | GitHub OAuth app secret | - | `your_github_app_secret` |

## Notes

- Boolean values: Use `true` or `false` (case-insensitive)
- All boolean environment variables default to `false` unless otherwise specified
- Variables marked with `-` in the Default column are required when the feature is enabled
- Sensitive values (passwords, secrets) should never be committed to version control