# Vulcan Environment Variables

This document lists all environment variables that can be used to configure Vulcan.

## 12-Factor Configuration Philosophy

Vulcan follows [12-Factor App](https://12factor.net/config) principles:

- **Primitive variables** (`PORT`, `HOST`, `VULCAN_SCHEME`) are the single source of truth
- **Derived values** (`VULCAN_APP_URL`, `VULCAN_OIDC_REDIRECT_URI`) are computed at runtime
- **Override capability** allows explicit values when behind proxies or load balancers

```
PORT=3000              # Primitive - single source of truth
HOST=localhost         # Primitive - single source of truth
VULCAN_SCHEME=http     # Primitive - single source of truth
         |
         v
VULCAN_APP_URL         # Derived: ${VULCAN_SCHEME}://${HOST}:${PORT}
         |
         v
VULCAN_OIDC_REDIRECT_URI  # Derived: ${VULCAN_APP_URL}/users/auth/oidc/callback
```

## Core Configuration (Primitives)

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `PORT` | Web server port (used by Rails, Docker, derived URLs) | `3000` | `8080` |
| `HOST` | Application hostname (used in derived URLs) | `localhost` | `vulcan.example.com` |
| `VULCAN_SCHEME` | URL scheme (http/https) | `http` | `https` |

## Derived URLs (Auto-computed)

These are automatically derived from the primitives above. Only override when necessary (e.g., behind a reverse proxy with different external URL).

| Variable | Derived From | Default | Override Example |
|----------|--------------|---------|------------------|
| `VULCAN_APP_URL` | `${VULCAN_SCHEME}://${HOST}:${PORT}` | `http://localhost:3000` | `https://vulcan.example.com` |
| `VULCAN_OIDC_REDIRECT_URI` | `${VULCAN_APP_URL}/users/auth/oidc/callback` | Auto | `https://vulcan.example.com/users/auth/oidc/callback` |

## System Configuration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_CONFIG` | Override path to vulcan.yml config file | `config/vulcan.yml` | `/etc/vulcan/config.yml` |
| `VULCAN_ENV` | Override Rails environment | Uses `RAILS_ENV` | `production` |
| `PROMETHEUS_PORT` | Prometheus metrics port | `9394` | `9090` |
| `VULCAN_PROMETHEUS_BIND` | Prometheus bind address | `0.0.0.0` | `127.0.0.1` |

## Database Configuration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `DATABASE_URL` | PostgreSQL connection string | - | `postgres://user:pass@localhost:5432/vulcan_production` |
| `DATABASE_PORT` | PostgreSQL port (for docker-compose) | `5432` | `5433` |
| `POSTGRES_USER` | PostgreSQL username (Docker) | `postgres` | `vulcan` |
| `POSTGRES_PASSWORD` | PostgreSQL password (Docker) | - | `secure_password` |
| `POSTGRES_DB` | PostgreSQL database name (Docker) | `vulcan_postgres_production` | `vulcan_db` |

## General Application Settings

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_WELCOME_TEXT` | Welcome message on login page | `Welcome to Vulcan` | `Welcome to MITRE Vulcan` |
| `VULCAN_CONTACT_EMAIL` | Contact email for notifications and default SMTP sender | - | `support@example.com` |

### App Banner

Optional colored banner at top and bottom of page. Useful for environment indicators, classification levels, or public release notices.

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_BANNER_ENABLED` | Show/hide banner | `false` | `true` |
| `VULCAN_BANNER_TEXT` | Banner text | Empty | `DEVELOPMENT`, `PUBLIC RELEASE`, `UNCLASSIFIED` |
| `VULCAN_BANNER_BACKGROUND_COLOR` | Background color (see below) | `success` | `warning`, `#FF5733`, `var(--bs-danger)` |
| `VULCAN_BANNER_TEXT_COLOR` | Text color (see below) | `white` | `dark`, `#000000`, `var(--bs-white)` |

**Color Formats Supported:**
- **Bootstrap color names**: `primary`, `secondary`, `success`, `danger`, `warning`, `info`, `light`, `dark`, `white`
- **CSS variables**: `var(--bs-success)`, `var(--custom-color)`
- **Hex codes**: `#198754`, `#ffffff`

**Common Use Cases:**
```bash
# Development environment (orange banner)
VULCAN_BANNER_ENABLED=true
VULCAN_BANNER_TEXT=DEVELOPMENT
VULCAN_BANNER_BACKGROUND_COLOR=warning
VULCAN_BANNER_TEXT_COLOR=dark

# Staging environment (blue banner)
VULCAN_BANNER_ENABLED=true
VULCAN_BANNER_TEXT=STAGING
VULCAN_BANNER_BACKGROUND_COLOR=info
VULCAN_BANNER_TEXT_COLOR=white

# Public release (green banner)
VULCAN_BANNER_ENABLED=true
VULCAN_BANNER_TEXT=PUBLIC RELEASE
VULCAN_BANNER_BACKGROUND_COLOR=success
VULCAN_BANNER_TEXT_COLOR=white

# Classification marking (custom colors)
VULCAN_BANNER_ENABLED=true
VULCAN_BANNER_TEXT=UNCLASSIFIED
VULCAN_BANNER_BACKGROUND_COLOR=#198754
VULCAN_BANNER_TEXT_COLOR=#ffffff
```

### Consent Banner (Modal)

Modal shown before authentication requiring user acknowledgment. Blocks all access until user clicks "I Agree". Useful for terms of use, DoD warning banners, or acceptable use policies.

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_CONSENT_BANNER_ENABLED` | Show/hide consent modal | `false` | `true` |
| `VULCAN_CONSENT_BANNER_VERSION` | Version number (increment to re-prompt all users) | `1` | `2` |
| `VULCAN_CONSENT_BANNER_CONTENT` | Custom markdown content (optional) | See default below | See examples below |

**Features:**
- **Blocks access** until acknowledged (backdrop="static", no close button)
- **localStorage tracking** per version (incrementing version re-prompts all users)
- **Markdown support** with XSS protection (DOMPurify sanitization)
- **Blurred background** overlay (8px backdrop blur)

**Default Content:**
```markdown
## Terms of Use

By accessing this system, you acknowledge and agree to the following:

- Your use of this system may be monitored and recorded for security and auditing purposes
- You will use this system only for authorized and lawful purposes
- You will not attempt to gain unauthorized access to any resources
- You will protect any credentials provided to you

If you do not agree to these terms, please disconnect now.
```

**Example Configurations:**

```bash
# Enable with default content
VULCAN_CONSENT_BANNER_ENABLED=true
VULCAN_CONSENT_BANNER_VERSION=1

# DoD Warning Banner (custom content)
VULCAN_CONSENT_BANNER_ENABLED=true
VULCAN_CONSENT_BANNER_VERSION=1
VULCAN_CONSENT_BANNER_CONTENT="## System Access Warning\n\nYou are accessing a U.S. Government information system...\n\n**Unauthorized use may result in criminal prosecution.**"

# Re-prompt all users (increment version)
VULCAN_CONSENT_BANNER_ENABLED=true
VULCAN_CONSENT_BANNER_VERSION=2  # Users who acknowledged v1 will see modal again
```

**Markdown Formatting:**
```markdown
## Heading 2
### Heading 3

**Bold text** and *italic text*

- Bulleted list item 1
- Bulleted list item 2

1. Numbered list item 1
2. Numbered list item 2

`inline code`
```

**Version Management:**
- Users who acknowledge version 1 won't see modal again (stored in localStorage: `vulcan-consent-v1`)
- Incrementing `VULCAN_CONSENT_BANNER_VERSION=2` shows modal to all users again (checks for `vulcan-consent-v2`)
- Each user's acknowledgment is tracked per version in their browser

### Footer Legal Text

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_FOOTER_COPYRIGHT_SYMBOL` | Copyright symbol (©, ®, ™) | `©` | `©` |
| `VULCAN_FOOTER_COPYRIGHT_YEAR` | Copyright year | Current year | `2025` |
| `VULCAN_FOOTER_ORGANIZATION` | Organization name | `The MITRE Corporation` | `Acme Corp` |
| `VULCAN_FOOTER_COPYRIGHT_STATEMENT` | Copyright statement | `All rights reserved` | `All rights reserved` |
| `VULCAN_FOOTER_TRADEMARK_PRODUCTS` | Trademark products list | `MITRE Vulcan and the MITRE Vulcan logo` | `MyProduct and the MyProduct logo` |
| `VULCAN_FOOTER_PERMISSION_STATEMENT` | Distribution/usage permission text | `Material on this site may be copied and distributed with permission only` | Custom permission text |

**Footer Template:**
```
Copyright {symbol} {year}, {organization}. {copyright_statement}.
{trademark_products} are trademarks of {organization}.
{permission_statement}.
```

**Note:** These variables need to be added to the vulcan-helm chart values.

## Authentication Settings

### Local Login

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_ENABLE_LOCAL_LOGIN` | Enable local username/password login | `true` | `false` |
| `VULCAN_ENABLE_EMAIL_CONFIRMATION` | Require email confirmation for new users | `false` | `true` |
| `VULCAN_SESSION_TIMEOUT` | Session timeout in minutes | `60` | `120` |

### Account Lockout

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_ENABLE_LOCKABLE` | Enable account lockout after failed attempts | `true` | `false` |
| `VULCAN_LOCKABLE_MAX_ATTEMPTS` | Maximum login attempts before lockout | `5` | `10` |
| `VULCAN_LOCKABLE_UNLOCK_IN_MINUTES` | Minutes until auto-unlock | `30` | `60` |

### User Registration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_ENABLE_USER_REGISTRATION` | Allow new users to register | `true` | `false` |

### OIDC/OAuth (Okta, Auth0, Keycloak, etc.)

**Vulcan supports automatic endpoint discovery** - only 4 essential variables needed.

#### Essential Configuration

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `VULCAN_ENABLE_OIDC` | Enable OIDC authentication | Yes | `true` |
| `VULCAN_OIDC_ISSUER_URL` | OIDC issuer URL | Yes | `https://dev-12345.okta.com` |
| `VULCAN_OIDC_CLIENT_ID` | OIDC client ID | Yes | `0oa1b2c3d4e5f6g7h8i9j` |
| `VULCAN_OIDC_CLIENT_SECRET` | OIDC client secret | Yes | `secret_key_here` |

**Note**: `VULCAN_OIDC_REDIRECT_URI` is automatically derived from `VULCAN_APP_URL`. Only set it explicitly if your IdP requires a different callback URL.

#### Optional Configuration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_OIDC_DISCOVERY` | Enable automatic endpoint discovery | `true` | `false` |
| `VULCAN_OIDC_PROVIDER_TITLE` | Display name for OIDC provider | `OIDC Provider` | `Okta` |
| `VULCAN_OIDC_PROMPT` | OIDC prompt parameter | - | `login` |
| `VULCAN_OIDC_CLIENT_SIGNING_ALG` | OIDC signing algorithm | `RS256` | `RS256` |

#### Manual Configuration (Legacy/Fallback)

*Only required when `VULCAN_OIDC_DISCOVERY=false` or as fallback endpoints*

| Variable | Description | Example |
|----------|-------------|---------|
| `VULCAN_OIDC_AUTHORIZATION_URL` | OIDC authorization endpoint | `https://idp.example.com/oauth2/authorize` |
| `VULCAN_OIDC_TOKEN_URL` | OIDC token endpoint | `https://idp.example.com/oauth2/token` |
| `VULCAN_OIDC_USERINFO_URL` | OIDC userinfo endpoint | `https://idp.example.com/oauth2/userinfo` |
| `VULCAN_OIDC_JWKS_URI` | OIDC JWKS endpoint | `https://idp.example.com/oauth2/keys` |

### LDAP

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_ENABLE_LDAP` | Enable LDAP authentication | `false` | `true` |
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
| `VULCAN_ENABLE_SMTP` | Enable SMTP for sending emails | `false` | `true` |
| `VULCAN_SMTP_ADDRESS` | SMTP server address | - | `smtp.gmail.com` |
| `VULCAN_SMTP_PORT` | SMTP server port | - | `587` |
| `VULCAN_SMTP_DOMAIN` | SMTP domain | - | `example.com` |
| `VULCAN_SMTP_SERVER_USERNAME` | SMTP username | Falls back to `VULCAN_CONTACT_EMAIL` | `notifications@example.com` |
| `VULCAN_SMTP_SERVER_PASSWORD` | SMTP password | - | `smtp_password` |
| `VULCAN_SMTP_AUTHENTICATION` | SMTP authentication method | - | `plain` |
| `VULCAN_SMTP_TLS` | Use TLS for SMTP | - | `true` |
| `VULCAN_SMTP_ENABLE_STARTTLS_AUTO` | Enable STARTTLS auto | - | `true` |
| `VULCAN_SMTP_OPENSSL_VERIFY_MODE` | OpenSSL verify mode | - | `none` |

**Note**: When `VULCAN_SMTP_SERVER_USERNAME` is not set, `VULCAN_CONTACT_EMAIL` is used as the default sender address.

## Slack Integration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_ENABLE_SLACK_COMMS` | Enable Slack notifications | `false` | `true` |
| `VULCAN_SLACK_API_TOKEN` | Slack API token | - | `xoxb-your-token` |
| `VULCAN_SLACK_CHANNEL_ID` | Slack channel ID | - | `C1234567890` |

## Project Settings

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_PROJECT_CREATE_PERMISSION_ENABLED` | Require permission to create projects | `true` | `false` |

## Rails/Framework Settings

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `SECRET_KEY_BASE` | Rails secret key base | - | Generate with `openssl rand -hex 64` |
| `CIPHER_PASSWORD` | Encryption cipher password | - | Generate with `openssl rand -hex 64` |
| `CIPHER_SALT` | Encryption cipher salt | - | Generate with `openssl rand -hex 64` |
| `RAILS_MASTER_KEY` | Rails master key for credentials | - | Generated by Rails |
| `RAILS_LOG_TO_STDOUT` | Log to stdout instead of files | `false` | `true` |
| `RAILS_SERVE_STATIC_FILES` | Serve static files in production | `false` | `true` |
| `FORCE_SSL` | Force SSL connections | - | `true` |

## Container/Production Logging

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `RAILS_LOG_TO_STDOUT` | Enable container-friendly logging | `false` | `true` |
| `STRUCTURED_LOGGING` | Enable JSON structured logging | `false` | `true` |

## Docker Build Settings

These variables are used by `docker buildx bake` (via `docker-bake.hcl`). They use the `VULCAN_` prefix to avoid conflicts with Ruby/Node version managers (RVM, rbenv, nvm).

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_RUBY_VERSION` | Ruby version for Docker builds | `3.4.7` | `3.4.7` |
| `VULCAN_NODE_VERSION` | Node.js version for Docker builds | `24.11.1` | `24.11.1` |
| `VULCAN_IMAGE` | Docker image name | `mitre/vulcan` | `ghcr.io/mitre/vulcan` |
| `VULCAN_VERSION` | Docker image version | `latest` | `2.3.0` |

**Note**: We use `VULCAN_RUBY_VERSION` instead of `RUBY_VERSION` because RVM exports `RUBY_VERSION` with an interpreter prefix (e.g., `ruby-3.4.7`) which breaks Docker image tags.

## Configuration Examples

### Development (Minimal)

```bash
# .env
PORT=3000
HOST=localhost
VULCAN_SCHEME=http

POSTGRES_PASSWORD=postgres
SECRET_KEY_BASE=development_secret_key_base_not_for_production_use
CIPHER_PASSWORD=development_cipher_password_not_for_production_use
CIPHER_SALT=development_cipher_salt_not_for_production_use

VULCAN_ENABLE_LOCAL_LOGIN=true
VULCAN_CONTACT_EMAIL=admin@example.com
```

### Production (Docker)

```bash
# .env
PORT=3000
HOST=vulcan.example.com
VULCAN_SCHEME=https

# Or override the derived URL directly:
# VULCAN_APP_URL=https://vulcan.example.com

POSTGRES_PASSWORD=<secure_password>
SECRET_KEY_BASE=<generate_with_openssl>
CIPHER_PASSWORD=<generate_with_openssl>
CIPHER_SALT=<generate_with_openssl>

VULCAN_ENABLE_OIDC=true
VULCAN_OIDC_ISSUER_URL=https://your-idp.example.com
VULCAN_OIDC_CLIENT_ID=your-client-id
VULCAN_OIDC_CLIENT_SECRET=your-client-secret

VULCAN_CONTACT_EMAIL=vulcan-support@example.com

VULCAN_ENABLE_SMTP=true
VULCAN_SMTP_ADDRESS=smtp.example.com
VULCAN_SMTP_PORT=587
VULCAN_SMTP_SERVER_USERNAME=notifications@example.com
VULCAN_SMTP_SERVER_PASSWORD=smtp_password
```

### Production Behind Reverse Proxy

When running behind nginx/traefik with TLS termination:

```bash
# Internal container runs on port 3000
PORT=3000
HOST=vulcan-app
VULCAN_SCHEME=http

# But external URL is different
VULCAN_APP_URL=https://vulcan.example.com
VULCAN_OIDC_REDIRECT_URI=https://vulcan.example.com/users/auth/oidc/callback
```

## Notes

- Boolean values: Use `true` or `false` (case-insensitive)
- All boolean environment variables default to `false` unless otherwise specified
- Variables marked with `-` in the Default column are required when the feature is enabled
- Sensitive values (passwords, secrets) should never be committed to version control
- Generate secrets with: `openssl rand -hex 64`
