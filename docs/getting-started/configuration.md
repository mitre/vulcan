# Vulcan Configuration

Vulcan can be set up in a few different ways. It can be done by having a vulcan.yml file that has settings for many different configurations. If there is no vulcan.yml file then the configurations will be read in from vulcan.default.yml that has default configuration as well as the ability for the configurations to be set by environment variables.

[**Installation**](installation.md) | **Configuration**

## Index

- [Configure Welcome Text and Contact Email](#configure-welcome-text-and-contact-email)
- [Configure SMTP:](#configure-smtp) Sets up the smtp mailing server
- [Configure Local Login:](#configure-local-login) Enables user to log in as well as turn email confirmation on and off
- [Configure User Registration:](#configure-user-registration) Enables user sign-ups
- [Configure Project Create Permissions:](#configure-project-create-permissions) Logged-In users can create projects
- [Configure LDAP:](#configure-ldap)
- [Configure OIDC:](#configure-oidc)
- [Configure Slack:](#configure-slack)
- [Configure Classification Banner:](#configure-classification-banner) Display colored classification/sensitivity banner
- [Configure Consent Modal:](#configure-consent-modal) Terms-of-use modal that blocks access until acknowledged
- [Configure Account Lockout:](#configure-account-lockout) Lock accounts after failed login attempts (STIG AC-07)
- [Configure Password Policy:](#configure-password-policy) Password complexity requirements (DoD 2222 default)

## Configuration Precedence

Settings are resolved in this order (first match wins):

1. **Environment variables** — `VULCAN_*` env vars set in `.env`, Dockerfile, app.json, or shell
2. **`config/vulcan.yml`** — Optional per-instance override (copy from `vulcan.default.yml`)
3. **`config/vulcan.default.yml`** — ERB template that reads env vars with fallback defaults
4. **`config/initializers/0_settings.rb`** — Ensures all keys exist with sensible defaults

`vulcan.default.yml` is the single source of truth. All other config sources either feed env vars into it or ensure keys exist when no YAML value is present.

## Default Configuration by Deployment Type

Each deployment type ships sensible defaults. Dev-friendly deployments enable local login, registration, and open project creation. Production deployments lock down authentication to external providers.

### Settings Matrix

| Setting | Dev / Docker / Review | Production | Env Var |
|---------|:---------------------:|:----------:|---------|
| Local login | **true** | false | `VULCAN_ENABLE_LOCAL_LOGIN` |
| User registration | **true** | false | `VULCAN_ENABLE_USER_REGISTRATION` |
| Project create (any user) | **true** | **true** | `VULCAN_PROJECT_CREATE_PERMISSION_ENABLED` |
| First user becomes admin | **true** | false | `VULCAN_FIRST_USER_ADMIN` |
| OIDC | false | **true** | `VULCAN_ENABLE_OIDC` |
| LDAP | false | false | `VULCAN_ENABLE_LDAP` |
| SMTP | false | **true** | `VULCAN_ENABLE_SMTP` |
| Slack | false | false | `VULCAN_ENABLE_SLACK_COMMS` |
| Classification banner | false | varies | `VULCAN_BANNER_ENABLED` |
| Consent modal | false | varies | `VULCAN_CONSENT_ENABLED` |
| Account lockout | **enabled** | **enabled** | `VULCAN_LOCKOUT_ENABLED` |
| Lockout attempts | 3 | 3 | `VULCAN_LOCKOUT_MAX_ATTEMPTS` |
| Password min length | 15 | 15 | `VULCAN_PASSWORD_MIN_LENGTH` |
| Password complexity (2222) | **enabled** | **enabled** | `VULCAN_PASSWORD_MIN_*` |

**Bold** = enabled for that deployment type.

### Where Defaults Are Set

| Deployment Type | Config Source | Notes |
|-----------------|-------------|-------|
| Local dev (`foreman start`) | `.env` (copy from `.env.example`) | Open defaults for easy onboarding |
| Docker quickstart (`docker compose up`) | `Dockerfile` ENV + `vulcan.default.yml` | Matches dev defaults |
| Heroku review app | `app.json` env overrides | Matches dev defaults |
| Heroku production | Manual config via Heroku dashboard | Use `.env.production.example` as reference |
| Bare metal production | `.env` (copy from `.env.production.example`) | Hardened: OIDC enabled, local login disabled |
| No env vars at all | `vulcan.default.yml` + `0_settings.rb` | Defaults to dev-friendly (local login enabled) |

### What You Must Provide

#### Development (local Rails or Docker quickstart)

**Required** — nothing beyond what ships in `.env.example`. Copy it and go:

```bash
cp .env.example .env
bundle exec rails db:prepare
foreman start -f Procfile.dev
```

Defaults give you: local login, registration, first-user-becomes-admin, no SMTP, no OIDC. The seed password is `1qaz!QAZ1qaz!QAZ`.

#### Production Deployment

**Required** (you must set these — no usable defaults):

| Variable | Why | How to generate |
|----------|-----|-----------------|
| `SECRET_KEY_BASE` | Rails session encryption | `openssl rand -hex 64` |
| `CIPHER_PASSWORD` | Data encryption at rest | `openssl rand -hex 64` |
| `CIPHER_SALT` | Data encryption salt | `openssl rand -hex 64` |
| `POSTGRES_PASSWORD` | Database access | `openssl rand -hex 33` |
| `VULCAN_APP_URL` | Email links, OIDC callbacks | Your domain (e.g., `https://vulcan.example.com`) |

**Required** — at least one auth provider:

| Provider | Key Variables |
|----------|--------------|
| OIDC (recommended) | `VULCAN_ENABLE_OIDC=true`, `VULCAN_OIDC_ISSUER_URL`, `VULCAN_OIDC_CLIENT_ID`, `VULCAN_OIDC_CLIENT_SECRET` |
| LDAP | `VULCAN_ENABLE_LDAP=true`, `VULCAN_LDAP_HOST`, `VULCAN_LDAP_BASE`, `VULCAN_LDAP_BIND_DN`, `VULCAN_LDAP_ADMIN_PASS` |
| Local login | `VULCAN_ENABLE_LOCAL_LOGIN=true` (not recommended for production) |

**Strongly recommended for production**:

| Variable | Default | Production Value | Why |
|----------|---------|-----------------|-----|
| `VULCAN_ENABLE_LOCAL_LOGIN` | true | **false** | External auth is more secure |
| `VULCAN_ENABLE_USER_REGISTRATION` | true | **false** | Users provisioned via OIDC/LDAP |
| `VULCAN_FIRST_USER_ADMIN` | true | **false** | Use `VULCAN_ADMIN_EMAIL` instead |
| `VULCAN_SESSION_TIMEOUT` | 1h | **15m** | DoD standard (STIG AC-12) |
| `VULCAN_ENABLE_REMEMBER_ME` | true | **false** | Disable for high-security environments |
| `VULCAN_ENABLE_SMTP` | false | **true** | Enables email notifications and unlock |
| `RAILS_FORCE_SSL` | true | **true** | Keep default |

**Optional** (sensible defaults work out of the box):

- Account lockout — enabled by default, STIG AC-07 compliant
- Password policy — DoD 2222 defaults (15 chars, 2 of each type)
- Classification banner — disabled by default, set if required
- Consent modal — disabled by default, set if required

Use `./setup-docker-secrets.sh` to generate all required secrets automatically, or copy `.env.production.example` and fill in your values.

### Design Principles

- **Opt-in services** (LDAP, OIDC, SMTP, Slack) default to `false` — they require external infrastructure
- **Core functionality** (local login, registration, project creation) defaults to `true` — a fresh install should work immediately
- **Production hardening** is explicit — operators configure OIDC/LDAP and disable local login deliberately
- **No surprises** — every deployment type documents its defaults; the "no env vars" path produces a working system

## Configure Welcome Text and Contact Email:

- **welcome_text:** Welcome text is the text shown on the homepage below the "What is Vulcan" blurb on the homepage. It can be configured by the administrator to provide users with any information that may be relevant to their access and usage of the Vulcan application. `(ENV: VULCAN_WELCOME_TEXT)(default: nil)`
- **contact_email:** Contact email is the reply email shown to users on confirmation and notification emails. Also serves as the default SMTP username when not explicitly configured, ensuring authentication alignment. By default this will revert to `vulcan-support@example.com` if no email is specified. `(ENV: VULCAN_CONTACT_EMAIL)(default: vulcan-support@example.com)`
- **app_url:** Allows hyper-linking of vulcan urls when notifications are sent `(ENV: VULCAN_APP_URL)`

## Configure SMTP:

- **enabled:** `(ENV: VULCAN_ENABLE_SMTP)`
- **settings:**
  - **address:** Allows for a remote mail server `(ENV: VULCAN_SMTP_ADDRESS)`
  - **port:** Port for your mail server to run off of `(ENV: VULCAN_SMTP_PORT)`
  - **domain:** For specification of a HELO domain `(ENV: VULCAN_SMTP_DOMAIN)`
  - **authentication:** For specification of authentication type if the mail server requires it `(ENV: VULCAN_SMTP_AUTHENTICATION)`
  - **tls:** Enables SMTP to connect with SMTP/TLS `(ENV: VULCAN_SMTP_TLS)`
  - **openssl_verify_mode:** For specifying how OpenSSL checks certificates `(ENV: VULCAN_SMTP_OPENSSL_VERIFY_MODE)`
  - **enable_starttls_auto:** Checks if SMTP has STARTTLS enabled and starts to use it `(ENV: VULCAN_SMTP_ENABLE_STARTTLS_AUTO)`
  - **user_name:** For mail server authentication. Defaults to contact_email if not specified. `(ENV: VULCAN_SMTP_SERVER_USERNAME)`
  - **password:** For mail server authentication `(ENV: VULCAN_SMTP_SERVER_PASSWORD)`

## Configure Local Login

- **enabled:** Allows for users to be able to log in as a local user instead of using ldap. `(ENV: VULCAN_ENABLE_LOCAL_LOGIN)(default: true)`
- **email_confirmation:** Turns on email confirmation for local registration. `(ENV: VULCAN_ENABLE_EMAIL_CONFIRMATION)(default: false)`
- **session_timeout:** Automatically logs user out after a period of inactivity. Accepts explicit suffixes (`30s`, `15m`, `1h`) or plain numbers where 1-9 = hours, 10-299 = minutes, 300+ = seconds. DoD standard is 900 seconds (15 minutes). `(ENV: VULCAN_SESSION_TIMEOUT)(default: 1h)`

## Configure User Registration
- **enabled:** Allows users to register themselves on the Vulcan app. `(ENV: VULCAN_ENABLE_USER_REGISTRATION)(default: true)`

## Configure Project Create Permissions
- **create_permission_enabled:** Allows any logged-in users to create new projects in Vulcan if enabled, otherwise only Vulcan Admins are allowed to create projects. `(ENV: VULCAN_PROJECT_CREATE_PERMISSION_ENABLED)(default: true)`

## Configure LDAP

- **enabled:** `(ENV: ENABLE_LDAP)(default: false)`
- **servers:**
  - **main:**
    - **host:** `(ENV: VULCAN_LDAP_HOST)(default: localhost)`
    - **port:** Port which the LDAP server communicates through `(ENV: VULCAN_LDAP_PORT)(default: 389)`
    - **title:** `(ENV: VULCAN_LDAP_TITLE)(default: LDAP)`
    - **uid:** Attribute for the username `(ENV: VULCAN_LDAP_ATTRIBUTE)(default: uid)`
    - **encryption:** `(ENV: VULCAN_LDAP_ENCRYPTION)(default: plain)`
    - **bind_dn:** The DN of the user you will bind with `(ENV: VULCAN_LDAP_BIND_DN)`
    - **password:** Password to log into the LDAP server `(ENV: VULCAN_LDAP_ADMIN_PASS)`
    - **base:** The point where a server will search for users `(ENV: VULCAN_LDAP_BASE)`

## Configure OIDC

- **enabled:** `(ENV: VULCAN_ENABLE_OIDC)(default: false)`
- **strategy:** :openid_connect `Omniauth Strategy for working with OIDC providers`
- **title:** : Description or Title for the OIDC Provider `(ENV: VULCAN_OIDC_PROVIDER_TITLE)`
- **args:** 
  - **name:** Name of the OIDC provider `(ENV: VULCAN_OIDC_PROVIDER_TITLE)`
  - **scope:** Which OpenID scope to include (:openid is always required) `default: [:openid]`
  - **uid_field:** The field of the user info response to be used as a unique id
  - **response_type:** Which OAuth2 response type to use with the authorization request `default: [:code]`
  - **issuer:** Root url for the authorization server `(ENV: VULCAN_OIDC_ISSUER_URL)`
  - **client_auth_method:** Which authentication method to use to authenticate your app with the authorization server `default: :secret`
  - **client_signing_alg:** Signing algorithms, specify the base64-encoded secret used to sign the JWT token `(ENV: VULCAN_OIDC_CLIENT_SIGNING_ALG)`
  - **nonce:** 
  - **client_options:**
      - **port:** The port for the authorization server `(ENV: VULCAN_OIDC_PORT)(default: 443)`
      - **scheme:** The http scheme to use `(ENV: VULCAN_OIDC_SCHEME)(default: https)`
      - **host:** The host for the authorization server `(ENV: VULCAN_OIDC_HOST)`
      - **identifier:** The OIDC client_id `(ENV: VULCAN_OIDC_CLIENT_ID)`
      - **secret:** The OIDC client secret `(ENV: VULCAN_OIDC_CLIENT_SECRET)`
      - **redirect_uri:** The OIDC authorization callback url in vulcan app. `(ENV: VULCAN_OIDC_REDIRECT_URI)`
      - **authorization_endpoint:** The authorize endpoint on the authorization server `(ENV: VULCAN_OIDC_AUTHORIZATION_URL)`
      - **token_endpoint:** The token endpoint on the authorization server `(ENV: VULCAN_OIDC_TOKEN_URL)`
      - **userinfo_endpoint:** The user info endpoint on the authorization server `(ENV: VULCAN_OIDC_USERINFO_URL)`
      - **jwks_uri:** The jwks_uri on the authorization server `(ENV: VULCAN_OIDC_JWKS_URI)`
      - **post_logout_redirect_uri:** '/'

## Configure Slack

- **enabled:** Enable Integration with Slack `(ENV: VULCAN_ENABLE_SLACK_COMMS)(default: false)`
- **api_token:** Slack Authentication token bearing required scopes.`(ENV: VULCAN_SLACK_API_TOKEN)`
- **channel_id:**  Slack Channel, private group, or IM channel to send message to. Can be an encoded ID, or a name. `(ENV: VULCAN_SLACK_CHANNEL_ID)`

## Configure Classification Banner

Display a colored banner at the top and bottom of every page. Commonly used for DoD classification markings or environment identification (e.g., STAGING, TRAINING).

- **enabled:** Show the banner on every page. `(ENV: VULCAN_BANNER_ENABLED)(default: false)`
- **text:** Plain text displayed in the banner — no formatting applied. `(ENV: VULCAN_BANNER_TEXT)(default: "")`
- **background_color:** Banner background color as a hex value. `(ENV: VULCAN_BANNER_BACKGROUND_COLOR)(default: #007a33)`
- **text_color:** Banner text color as a hex value. `(ENV: VULCAN_BANNER_TEXT_COLOR)(default: #ffffff)`

### DoD Standard Colors

| Classification | Background | Text |
|---------------|------------|------|
| UNCLASSIFIED | `#007a33` | `#ffffff` |
| CUI | `#502b85` | `#ffffff` |
| CONFIDENTIAL | `#0033a0` | `#ffffff` |
| SECRET | `#c8102e` | `#ffffff` |
| TOP SECRET | `#ff671f` | `#ffffff` |
| TS/SCI | `#f7ea48` | `#000000` |

### Example

```bash
VULCAN_BANNER_ENABLED=true
VULCAN_BANNER_TEXT=UNCLASSIFIED
VULCAN_BANNER_BACKGROUND_COLOR=#007a33
VULCAN_BANNER_TEXT_COLOR=#ffffff
```

## Configure Consent Modal

Display a blocking consent/terms-of-use modal that users must acknowledge before accessing the application. Acknowledgment is stored in the browser's localStorage. Incrementing the version re-prompts all users — useful when policies change.

- **enabled:** Show the consent modal on page load. `(ENV: VULCAN_CONSENT_ENABLED)(default: false)`
- **version:** Version identifier for the consent terms. Increment this value to force all users to re-acknowledge. `(ENV: VULCAN_CONSENT_VERSION)(default: 1)`
- **title:** Modal dialog title. `(ENV: VULCAN_CONSENT_TITLE)(default: Terms of Use)`
- **content:** Modal body content. Supports **Markdown** formatting including headings, bold, italics, numbered/bulleted lists, links, and blockquotes. HTML is sanitized for security. `(ENV: VULCAN_CONSENT_CONTENT)(default: "")`

### Example

```bash
VULCAN_CONSENT_ENABLED=true
VULCAN_CONSENT_VERSION=1
VULCAN_CONSENT_TITLE=Acceptable Use Policy
VULCAN_CONSENT_CONTENT="## Terms of Use

By accessing this system you agree to the following:

1. **Authorized use only** — this system is for official use
2. **Activity is monitored** — all actions may be logged
3. **No expectation of privacy** — on this government system

> Contact your administrator with questions."
```

::: tip Version-Based Re-prompting
When you update your terms, increment `VULCAN_CONSENT_VERSION` (e.g., from `1` to `2`). All users will see the modal again on their next visit, regardless of prior acknowledgment.
:::

## Configure Account Lockout

STIG AC-07 compliant account lockout. Locks accounts after consecutive failed login attempts and provides multiple unlock methods.

- **enabled:** Enable account lockout. `(ENV: VULCAN_LOCKOUT_ENABLED)(default: true)`
- **maximum_attempts:** Number of failed attempts before the account is locked. `(ENV: VULCAN_LOCKOUT_MAX_ATTEMPTS)(default: 3)`
- **unlock_in_minutes:** Minutes before a locked account automatically unlocks. `(ENV: VULCAN_LOCKOUT_UNLOCK_IN_MINUTES)(default: 15)`
- **unlock_strategy:** How locked accounts can be unlocked. `(ENV: VULCAN_LOCKOUT_UNLOCK_STRATEGY)(default: both)`
  - `email` — sends an unlock link (requires SMTP)
  - `time` — auto-unlocks after the configured minutes
  - `both` — either method works (recommended)
- **last_attempt_warning:** Show a warning on the last attempt before lock. `(ENV: VULCAN_LOCKOUT_LAST_ATTEMPT_WARNING)(default: true)`

### Admin Unlock

Administrators can manually unlock any account from the Users page (`/users`). Click the edit (pencil) icon on a locked user to see the unlock button. Admin unlock works regardless of SMTP configuration.

### Example: STIG AC-07 (default)

```bash
VULCAN_LOCKOUT_ENABLED=true
VULCAN_LOCKOUT_MAX_ATTEMPTS=3
VULCAN_LOCKOUT_UNLOCK_IN_MINUTES=15
VULCAN_LOCKOUT_UNLOCK_STRATEGY=both
VULCAN_LOCKOUT_LAST_ATTEMPT_WARNING=true
```

### Example: Disabled for Development

```bash
VULCAN_LOCKOUT_ENABLED=false
```

::: tip
When SMTP is not configured, the `both` strategy ensures locked accounts still auto-unlock via the time-based method. Administrators can also unlock accounts manually from the Users page at any time.
:::

## Configure Password Policy

Configurable password complexity enforcement. Defaults are DoD-aligned ("2222" policy: 15 characters minimum, 2 uppercase, 2 lowercase, 2 numbers, 2 special characters). Set any count to `0` to disable that requirement.

Validation is enforced both server-side (Rails model validation) and client-side (real-time checklist on registration, password reset, and profile pages).

- **min_length:** Minimum total password length. `(ENV: VULCAN_PASSWORD_MIN_LENGTH)(default: 15)`
- **min_uppercase:** Minimum uppercase letters required. `(ENV: VULCAN_PASSWORD_MIN_UPPERCASE)(default: 2)`
- **min_lowercase:** Minimum lowercase letters required. `(ENV: VULCAN_PASSWORD_MIN_LOWERCASE)(default: 2)`
- **min_number:** Minimum digits required. `(ENV: VULCAN_PASSWORD_MIN_NUMBER)(default: 2)`
- **min_special:** Minimum special characters required. `(ENV: VULCAN_PASSWORD_MIN_SPECIAL)(default: 2)`

### Example: DoD Standard (default)

```bash
VULCAN_PASSWORD_MIN_LENGTH=15
VULCAN_PASSWORD_MIN_UPPERCASE=2
VULCAN_PASSWORD_MIN_LOWERCASE=2
VULCAN_PASSWORD_MIN_NUMBER=2
VULCAN_PASSWORD_MIN_SPECIAL=2
```

### Example: Relaxed Development

```bash
VULCAN_PASSWORD_MIN_LENGTH=8
VULCAN_PASSWORD_MIN_UPPERCASE=0
VULCAN_PASSWORD_MIN_LOWERCASE=0
VULCAN_PASSWORD_MIN_NUMBER=0
VULCAN_PASSWORD_MIN_SPECIAL=0
```

::: tip OmniAuth Users
Password complexity is only validated for local (email/password) accounts. OmniAuth users (OIDC, LDAP, GitHub) use random token passwords and skip complexity validation.
:::

## Example Vulcan.yml

```
defaults: &defaults
  welcome_text:
  contact_email:
  app_url:
  smtp:
    enabled:
    settings:
      address:
      port:
      domain:
      authentication:
      tls:
      openssl_verify_mode:
      enable_starttls_auto:
      user_name:
      password:
  local_login:
    enabled:
    email_confirmation:
  ldap:
    enabled:
    servers:
      main:
        host:
        port:
        title:
        uid:
        encryption:
        bind_dn:
        password:
        base:
  oidc:
    enabled: 
    strategy:
    title:
    args:
      name: 
      scope:
      uid_field: 
      response_type:
      issuer: 
      client_auth_method:
      client_signing_alg:
      nonce:
      client_options:
        port:
        scheme:
        host:
        identifier:
        secret:
        redirect_uri:
        authorization_endpoint:
        token_endpoint:
        userinfo_endpoint:
        jwks_uri:
        post_logout_redirect_uri:
  banner:
    enabled:
    text:
    background_color:
    text_color:
  consent:
    enabled:
    version:
    title:
    content:
  lockout:
    enabled:
    maximum_attempts:
    unlock_in_minutes:
    unlock_strategy:
    last_attempt_warning:
  password:
    min_length:
    min_uppercase:
    min_lowercase:
    min_number:
    min_special:
  slack:
    enabled:
    api_token:
    channel_id:
  providers:
    # - { name: 'github',
    #     app_id: '<APP_ID>',
    #     app_secret: '<APP_SECRET>',
    #     args: { scope: 'user:email' } }

development:
  <<: *defaults
test:
  <<: *defaults
production:
  <<: *defaults
```