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
| `DATABASE_URL` | PostgreSQL connection string (12-factor, takes precedence) | - | `postgres://user:pass@localhost:5432/vulcan_production` |
| `DATABASE_PORT` | PostgreSQL client connection port (used by database.yml) | `5432` | `5435` |
| `DATABASE_HOST` | PostgreSQL host (used by database.yml) | `127.0.0.1` | `localhost` |
| `DATABASE_GSSENCMODE` | GSSAPI encryption mode (set to `disable` on macOS with Kerberos) | `prefer` | `disable` |
| `DB_SUFFIX` | Database name suffix for worktree isolation (development only) | - | `_v2`, `_v3` |
| `POSTGRES_PORT` | Docker host-side port mapping (should match DATABASE_PORT) | `5432` | `5435` |
| `POSTGRES_USER` | PostgreSQL username (Docker init + database.yml) | `postgres` | `vulcan_user` |
| `POSTGRES_PASSWORD` | PostgreSQL password (Docker init + database.yml) | `postgres` | `secure_password` |
| `POSTGRES_DB` | PostgreSQL database name (Docker init + production database.yml) | `vulcan_postgres_production` | `vulcan_prod` |
| `PORT` | Application server (Puma) listen port | `3000` | `3001` |

**Note:** `DATABASE_URL` takes precedence when set (recommended for Heroku, Kubernetes). Individual variables (`POSTGRES_USER`, `POSTGRES_PASSWORD`, etc.) are used as fallback.

**Worktree Isolation**: When developing with multiple git worktrees (e.g., v2.x and v3.x), set `DB_SUFFIX` in each worktree's `.env` to give each branch its own database. This prevents migration conflicts when branches have diverging schemas. Not needed in production — each deployment has its own database.

```bash
# v2.x worktree .env
DB_SUFFIX=_v2    # → vulcan_vue_development_v2, vulcan_vue_test_v2

# v3.x worktree .env
DB_SUFFIX=_v3    # → vulcan_vue_development_v3, vulcan_vue_test_v3
```

**Deprecated:** `VULCAN_VUE_DATABASE_PASSWORD` is deprecated. Use `POSTGRES_PASSWORD` instead.

**Multi-Project Development**: See [docs/development/port-registry.md](docs/development/port-registry.md) for recommended port assignments when running multiple projects simultaneously.

## General Application Settings

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_APP_URL` | Application URL | `http://localhost:3000` | `https://vulcan.example.com` |
| `VULCAN_WELCOME_TEXT` | Welcome message on login page | `Welcome to Vulcan` | `Welcome to MITRE Vulcan` |
| `VULCAN_CONTACT_EMAIL` | Contact email for notifications and default SMTP username | `vulcan-support@example.com` | `support@mycompany.com` |

## Authentication Settings

### Local Login
| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_ENABLE_LOCAL_LOGIN` | Enable local username/password login | `true` | `true` or `false` |
| `VULCAN_ENABLE_EMAIL_CONFIRMATION` | Require email confirmation for new users | `false` | `true` or `false` |
| `VULCAN_SESSION_TIMEOUT` | Session inactivity timeout. Accepts explicit suffix (`30s`, `15m`, `1h`) or plain numbers (1-9 = hours, 10-299 = minutes, 300+ = seconds). | `1h` | `900` (DoD 15-min), `15m`, `1h` |
| `VULCAN_ENABLE_REMEMBER_ME` | Show "Remember Me" checkbox on login forms | `true` | `false` for DoD |
| `VULCAN_REMEMBER_ME_DURATION` | How long Remember Me keeps session alive. Same format as session timeout. | `8h` | `1d`, `28800` |

### User Registration
| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_ENABLE_USER_REGISTRATION` | Allow new users to register | `true` | `true` or `false` |

### Admin Bootstrap

Vulcan provides multiple ways to create the initial admin user. These are evaluated in priority order:

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_ADMIN_EMAIL` | Email for auto-created admin user | - | `admin@example.com` |
| `VULCAN_ADMIN_PASSWORD` | Password for auto-created admin user | Auto-generated | `SecurePass123!` |
| `VULCAN_FIRST_USER_ADMIN` | First registered user becomes admin | `true` (Docker) | `true` or `false` |

**Priority Order:**
1. **Environment Variables** (Most Secure): Set `VULCAN_ADMIN_EMAIL` and optionally `VULCAN_ADMIN_PASSWORD`
   - Admin is created automatically during `db:prepare`
   - If password is omitted, a secure random password is generated and logged
   - Best for: Production, CI/CD, Kubernetes

2. **First User Admin** (Convenience): Set `VULCAN_FIRST_USER_ADMIN=true`
   - First user to register or login becomes admin automatically
   - Protected by database advisory lock to prevent race conditions
   - Best for: Quick demos, development, evaluations

3. **Manual Rake Task**: Run `rails db:create_admin`
   - Interactive terminal prompt
   - Best for: Traditional deployments, manual setup

**Docker Default**: In Docker deployments, `VULCAN_FIRST_USER_ADMIN=true` is the default, allowing
immediate use after `docker compose up`. For production, disable this and use `VULCAN_ADMIN_EMAIL`.

**Security Note**: The first-user-admin feature uses PostgreSQL advisory locks to prevent race
condition attacks (similar to WordPress installer vulnerabilities). However, for production
deployments, explicit admin configuration via environment variables is recommended.

### Demo/Evaluation Data

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_SEED_DEMO_DATA` | Populate database with demo data in production | `false` | `true` |

When `VULCAN_SEED_DEMO_DATA=true`, `db:seed` creates sample users, projects, and components for evaluation purposes. In development/test environments, demo data is always seeded.

If no admin user exists (i.e., `VULCAN_ADMIN_EMAIL` was not set), a fallback demo admin is created:
- **Email**: `admin@example.com`
- **Password**: `12qwaszx\!@QWASZX` (DoD 2222/15 compliant)

If an admin already exists from `admin:bootstrap`, the demo admin is skipped and only sample projects/users are created.

### OIDC/OAuth (e.g., Okta, Auth0, Keycloak)

**New in v2.2+**: Vulcan supports automatic endpoint discovery, reducing configuration from 8+ variables to just 4 essential ones.

#### Essential Configuration (Auto-Discovery Enabled)
| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `VULCAN_ENABLE_OIDC` | Enable OIDC authentication | ✅ | `true` |
| `VULCAN_OIDC_ISSUER_URL` | OIDC issuer URL | ✅ | `https://dev-12345.okta.com` |
| `VULCAN_OIDC_CLIENT_ID` | OIDC client ID | ✅ | `0oa1b2c3d4e5f6g7h8i9j` |
| `VULCAN_OIDC_CLIENT_SECRET` | OIDC client secret | ✅ | `secret_key_here` |
| `VULCAN_OIDC_REDIRECT_URI` | OIDC redirect URI | ✅ | `https://vulcan.example.com/users/auth/oidc/callback` |

#### Optional Configuration
| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_OIDC_DISCOVERY` | Enable automatic endpoint discovery | `true` | `false` (to disable) |
| `VULCAN_OIDC_PROVIDER_TITLE` | Display name for OIDC provider | `OIDC Provider` | `Okta` |
| `VULCAN_OIDC_PROMPT` | OIDC prompt parameter | - | `login` (forces re-authentication) |
| `VULCAN_OIDC_CLIENT_SIGNING_ALG` | OIDC signing algorithm | `RS256` | `RS256` |

#### Manual Configuration (Legacy/Fallback)
*Only required when `VULCAN_OIDC_DISCOVERY=false` or as fallback endpoints*

| Variable | Description | Example |
|----------|-------------|---------|
| `VULCAN_OIDC_AUTHORIZATION_URL` | OIDC authorization endpoint | `https://dev-12345.okta.com/oauth2/default/v1/authorize` |
| `VULCAN_OIDC_TOKEN_URL` | OIDC token endpoint | `https://dev-12345.okta.com/oauth2/default/v1/token` |
| `VULCAN_OIDC_USERINFO_URL` | OIDC userinfo endpoint | `https://dev-12345.okta.com/oauth2/default/v1/userinfo` |
| `VULCAN_OIDC_JWKS_URI` | OIDC JWKS endpoint | `https://dev-12345.okta.com/oauth2/default/v1/keys` |

#### Deprecated Variables
*These variables are no longer needed with auto-discovery enabled*

| Variable | Replacement | Notes |
|----------|-------------|-------|
| `VULCAN_OIDC_HOST` | Use `VULCAN_OIDC_ISSUER_URL` | Automatically extracted from issuer URL |
| `VULCAN_OIDC_PORT` | Use `VULCAN_OIDC_ISSUER_URL` | Automatically extracted from issuer URL |
| `VULCAN_OIDC_SCHEME` | Use `VULCAN_OIDC_ISSUER_URL` | Automatically extracted from issuer URL |

#### Migration Examples

**Before (8+ variables)**:
```bash
VULCAN_ENABLE_OIDC=true
VULCAN_OIDC_ISSUER_URL=https://dev-12345.okta.com
VULCAN_OIDC_CLIENT_ID=your-client-id
VULCAN_OIDC_CLIENT_SECRET=your-secret
VULCAN_OIDC_REDIRECT_URI=https://vulcan.example.com/users/auth/oidc/callback
VULCAN_OIDC_AUTHORIZATION_URL=https://dev-12345.okta.com/oauth2/default/v1/authorize
VULCAN_OIDC_TOKEN_URL=https://dev-12345.okta.com/oauth2/default/v1/token
VULCAN_OIDC_USERINFO_URL=https://dev-12345.okta.com/oauth2/default/v1/userinfo
VULCAN_OIDC_JWKS_URI=https://dev-12345.okta.com/oauth2/default/v1/keys
```

**After (4 variables)**:
```bash
VULCAN_ENABLE_OIDC=true
VULCAN_OIDC_ISSUER_URL=https://dev-12345.okta.com
VULCAN_OIDC_CLIENT_ID=your-client-id
VULCAN_OIDC_CLIENT_SECRET=your-secret
VULCAN_OIDC_REDIRECT_URI=https://vulcan.example.com/users/auth/oidc/callback
# Endpoints automatically discovered from /.well-known/openid-configuration
```

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
| `VULCAN_SMTP_SERVER_USERNAME` | SMTP username (defaults to VULCAN_CONTACT_EMAIL if not set) | - | `notifications@example.com` |
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

## Classification Banner

Display a colored banner at the top and bottom of every page, commonly used for DoD classification markings.

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_BANNER_ENABLED` | Enable classification banner | `false` | `true` |
| `VULCAN_BANNER_TEXT` | Banner text displayed on every page (plain text, no formatting) | `""` | `UNCLASSIFIED` |
| `VULCAN_BANNER_BACKGROUND_COLOR` | Banner background color (hex) | `#007a33` | `#c8102e` |
| `VULCAN_BANNER_TEXT_COLOR` | Banner text color (hex) | `#ffffff` | `#000000` |

**DoD Standard Colors:**

| Classification | Background | Text |
|---------------|------------|------|
| UNCLASSIFIED | `#007a33` | `#ffffff` |
| CUI | `#502b85` | `#ffffff` |
| CONFIDENTIAL | `#0033a0` | `#ffffff` |
| SECRET | `#c8102e` | `#ffffff` |
| TOP SECRET | `#ff671f` | `#ffffff` |
| TS/SCI | `#f7ea48` | `#000000` |

## Consent / Terms of Use Modal

Display a blocking consent modal that users must acknowledge before accessing the application. Acknowledgment is stored in the browser's localStorage per version — incrementing the version re-prompts all users.

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_CONSENT_ENABLED` | Enable consent modal | `false` | `true` |
| `VULCAN_CONSENT_VERSION` | Version string for consent (increment to re-prompt) | `1` | `2` |
| `VULCAN_CONSENT_TITLE` | Modal title | `Terms of Use` | `Acceptable Use Policy` |
| `VULCAN_CONSENT_CONTENT` | Modal body content (supports **Markdown**) | `""` | `By using this system you agree to the **AUP**.` |

**Consent Content Formatting**: The `VULCAN_CONSENT_CONTENT` variable supports full [Markdown](https://www.markdownguide.org/basic-syntax/) formatting including headings, bold, italics, numbered/bulleted lists, links, and blockquotes. HTML is sanitized for security. The banner text (`VULCAN_BANNER_TEXT`) is plain text only — no formatting is applied.

## Account Lockout (STIG AC-07)

Lock accounts after consecutive failed login attempts. Enabled by default with STIG AC-07 compliant settings.

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_LOCKOUT_ENABLED` | Enable account lockout | `true` | `false` |
| `VULCAN_LOCKOUT_MAX_ATTEMPTS` | Failed attempts before lock | `3` | `5` |
| `VULCAN_LOCKOUT_UNLOCK_IN_MINUTES` | Minutes before auto-unlock | `15` | `30` |
| `VULCAN_LOCKOUT_UNLOCK_STRATEGY` | Unlock method: `email`, `time`, or `both` | `both` | `time` |
| `VULCAN_LOCKOUT_LAST_ATTEMPT_WARNING` | Warn user on last attempt before lock | `true` | `false` |

**Unlock strategies:**
- `email` — sends an unlock link to the user's email (requires SMTP)
- `time` — automatically unlocks after `VULCAN_LOCKOUT_UNLOCK_IN_MINUTES`
- `both` — either method works (recommended, ensures unlock even without SMTP)

Administrators can also manually unlock accounts from the Users page (`/users`).

## Password Policy

DoD-aligned defaults ("2222" policy). Set any count to `0` to disable that requirement.

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_PASSWORD_MIN_LENGTH` | Minimum password length | `15` | `8` |
| `VULCAN_PASSWORD_MIN_UPPERCASE` | Minimum uppercase letters | `2` | `0` |
| `VULCAN_PASSWORD_MIN_LOWERCASE` | Minimum lowercase letters | `2` | `0` |
| `VULCAN_PASSWORD_MIN_NUMBER` | Minimum digits | `2` | `0` |
| `VULCAN_PASSWORD_MIN_SPECIAL` | Minimum special characters | `2` | `0` |

## Input Length Limits

Configurable maximum lengths for text fields. Defaults are based on analysis of real DISA STIG/SRG
data across 1,785 rules. Group limits by category rather than individual fields — each env var
controls a category of related fields.

See [docs/development/input-length-limits.md](docs/development/input-length-limits.md) for the
complete field-to-setting mapping.

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `VULCAN_LIMIT_SHORT_STRING` | IDs, version strings, reference fields | `255` | `512` |
| `VULCAN_LIMIT_IDENT` | Comma-joined CCI list (real max: 310) | `2048` | `4096` |
| `VULCAN_LIMIT_TITLE` | Rule titles (real max: 436) | `500` | `1000` |
| `VULCAN_LIMIT_MEDIUM_TEXT` | Status justification, brief text | `1000` | `2000` |
| `VULCAN_LIMIT_LONG_TEXT` | Descriptions, check content, fixtext (real max: 6,330) | `10000` | `20000` |
| `VULCAN_LIMIT_INSPEC_CODE` | InSpec control bodies (user-authored) | `50000` | `100000` |
| `VULCAN_LIMIT_COMPONENT_NAME` | Component name | `255` | `500` |
| `VULCAN_LIMIT_COMPONENT_PREFIX` | STIG ID prefix | `10` | `15` |
| `VULCAN_LIMIT_COMPONENT_TITLE` | Component title | `500` | `1000` |
| `VULCAN_LIMIT_COMPONENT_DESCRIPTION` | Component description | `5000` | `10000` |
| `VULCAN_LIMIT_PROJECT_NAME` | Project name | `255` | `500` |
| `VULCAN_LIMIT_PROJECT_DESCRIPTION` | Project description | `5000` | `10000` |
| `VULCAN_LIMIT_USER_NAME` | User display name | `255` | `500` |
| `VULCAN_LIMIT_USER_EMAIL` | User email address | `255` | `500` |
| `VULCAN_LIMIT_REVIEW_COMMENT` | Review comments | `10000` | `20000` |
| `VULCAN_LIMIT_BENCHMARK_NAME` | SRG/STIG display name | `500` | `1000` |
| `VULCAN_LIMIT_BENCHMARK_TITLE` | SRG/STIG title | `500` | `1000` |
| `VULCAN_LIMIT_BENCHMARK_DESCRIPTION` | STIG description | `10000` | `20000` |

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
- `.env` file (created by `setup-docker-secrets.sh`)
- `docker-compose.prod.yml` using the `environment:` section
- Container runtime with `-e` flags

**For Container Deployments** (Docker, ECS, Kubernetes):
```yaml
# docker-compose.prod.yml
environment:
  RAILS_LOG_TO_STDOUT: "true"
  STRUCTURED_LOGGING: "true"  # Enable JSON logging for CloudWatch/monitoring
  # Other environment variables...
```

**AWS ECS Example**:
```json
{
  "environment": [
    {"name": "RAILS_LOG_TO_STDOUT", "value": "true"},
    {"name": "STRUCTURED_LOGGING", "value": "true"}
  ]
}
```

This ensures OIDC auto-discovery events and all application logs are visible in your container orchestration platform's logging system.

## Rails/Framework Settings

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `RAILS_MASTER_KEY` | Rails master key for credentials | - | Generated by Rails |
| `RAILS_LOG_TO_STDOUT` | Log to stdout instead of files | - | `true` |
| `RAILS_SERVE_STATIC_FILES` | Serve static files in production | - | `true` |
| `RAILS_FORCE_SSL` | Force HTTPS redirects (set to `false` for Docker without SSL termination) | `true` | `false` |

## Container Logging (Production)

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `RAILS_LOG_TO_STDOUT` | Enable container-friendly logging | `false` | `true` |
| `STRUCTURED_LOGGING` | Enable JSON structured logging for CloudWatch/monitoring | `false` | `true` |
| `DOCKER_CONTAINER` | Indicates running in Docker container (auto-detected) | - | `true` |
| `ECS_CONTAINER_METADATA_URI` | AWS ECS metadata URI (auto-detected) | - | Auto-set by ECS |

**Container Logging Features**:
- **Automatic Detection**: Vulcan automatically detects container environments (Docker, ECS, Kubernetes)
- **JSON Logging**: When `STRUCTURED_LOGGING=true`, logs are output in JSON format for easy parsing by CloudWatch, Splunk, etc.
- **OIDC Discovery Visibility**: All OIDC auto-discovery events are logged with detailed context for production debugging
- **Request Tracking**: Includes request IDs in structured logs when available

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