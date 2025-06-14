# Vulcan Settings Architecture: Old vs New Structure

## Current Settings Tree (settingslogic)

```
Settings
├── local_login
│   ├── enabled (boolean)
│   ├── session_timeout (integer)
│   └── email_confirmation (boolean)
├── oidc
│   ├── enabled (boolean)
│   ├── discovery (boolean)
│   ├── strategy (symbol)
│   ├── title (string)
│   └── args (complex hash)
│       ├── name (symbol)
│       ├── scope (array)
│       ├── uid_field (string)
│       ├── response_type (symbol)
│       ├── issuer (string)
│       └── client_options (hash)
│           ├── identifier (string)
│           ├── secret (string)
│           ├── redirect_uri (string)
│           └── ... (many more)
├── ldap
│   ├── enabled (boolean)
│   └── servers (hash)
│       └── main (hash)
│           ├── host (string)
│           ├── port (integer)
│           ├── title (string)
│           ├── uid (string)
│           ├── encryption (string)
│           ├── bind_dn (string)
│           ├── password (string)
│           └── base (string)
├── smtp
│   ├── enabled (boolean)
│   └── settings (hash)
│       ├── address (string)
│       ├── port (integer)
│       ├── domain (string)
│       ├── authentication (symbol)
│       ├── user_name (string)
│       ├── password (string)
│       └── ... (more SMTP config)
├── slack
│   ├── enabled (boolean)
│   ├── api_token (string)
│   └── channel_id (string)
├── project
│   └── create_permission_enabled (boolean)
├── user_registration
│   └── enabled (boolean)
├── providers (array)
├── contact_email (string)
└── app_url (string)
```

## Proposed New Settings Tree Options

### Option A: Keep Nested Structure (Familiar)
```
Settings
├── local_login
│   ├── enabled (boolean field)
│   ├── session_timeout (integer field)
│   └── email_confirmation (boolean field)
├── oidc
│   ├── enabled (boolean field)
│   ├── discovery (boolean field)
│   ├── title (string field)
│   ├── issuer_url (string field, readonly from ENV)
│   ├── client_id (string field, readonly from ENV)
│   └── client_secret (string field, readonly from ENV)
├── smtp
│   ├── enabled (boolean field)
│   ├── address (string field)
│   ├── port (integer field)
│   ├── username (string field)
│   └── password (encrypted field)
├── slack
│   ├── enabled (boolean field)
│   ├── api_token (encrypted field)
│   └── channel_id (string field)
├── project
│   └── create_permission_enabled (boolean field)
├── user_registration
│   └── enabled (boolean field)
├── contact_email (string field)
└── app_url (string field)
```

**Implementation:** Nested compatibility classes (like we started with LocalLoginSettings)

### Option B: Flat Structure (rails-settings-cached Best Practice)
```
Settings
├── local_login_enabled (boolean field)
├── local_login_session_timeout (integer field)
├── local_login_email_confirmation (boolean field)
├── oidc_enabled (boolean field)
├── oidc_discovery (boolean field)
├── oidc_title (string field)
├── oidc_issuer_url (string field, readonly)
├── oidc_client_id (string field, readonly)
├── smtp_enabled (boolean field)
├── smtp_address (string field)
├── smtp_port (integer field)
├── smtp_username (string field)
├── smtp_password (encrypted field)
├── slack_enabled (boolean field)
├── slack_api_token (encrypted field)
├── slack_channel_id (string field)
├── project_create_permission_enabled (boolean field)
├── user_registration_enabled (boolean field)
├── contact_email (string field)
└── app_url (string field)
```

**Implementation:** Direct field access, simpler API

### Option C: Hybrid Structure (Best of Both)
```
Settings
├── Core App Settings (direct fields)
│   ├── contact_email (string field)
│   ├── app_url (string field)
│   └── project_create_permission_enabled (boolean field)
├── Authentication (grouped with compatibility layer)
│   ├── local_login_* (3 fields)
│   ├── oidc_* (5 fields)
│   ├── ldap_* (3 fields)
│   └── user_registration_enabled (1 field)
└── Integrations (grouped with compatibility layer)
    ├── smtp_* (5 fields)
    └── slack_* (3 fields)
```

**Implementation:** Mix of direct access for simple settings, compatibility classes for complex ones

## Security Analysis: ENV vs Database Storage

Based on our environment variables audit, here's the security categorization:

### 🔒 SECRETS (Must stay ENV-only, readonly)
```
VULCAN_SMTP_SERVER_PASSWORD     # SMTP password
VULCAN_LDAP_ADMIN_PASS         # LDAP bind password  
VULCAN_OIDC_CLIENT_SECRET      # OIDC client secret
VULCAN_SLACK_API_TOKEN         # Slack API token
```

### 🔧 CONFIGURATION (Can be database-backed)
```
VULCAN_ENABLE_SMTP             # Feature flags
VULCAN_ENABLE_OIDC
VULCAN_ENABLE_LDAP
VULCAN_OIDC_PROVIDER_TITLE     # UI customization
VULCAN_LDAP_TITLE
VULCAN_CONTACT_EMAIL           # App configuration
```

### 🏗️ INFRASTRUCTURE (Should stay ENV-only, readonly)
```
VULCAN_OIDC_ISSUER_URL         # External service URLs
VULCAN_LDAP_HOST
VULCAN_SMTP_ADDRESS
VULCAN_APP_URL                 # Base application URL
```

## Research: rails-settings-cached Best Practices

From the official documentation, rails-settings-cached recommends:

1. **Use `scope` for logical grouping** (supports nested structure)
2. **Explicit field types** with validation
3. **readonly: true** for ENV-only values
4. **Default values** with ENV fallbacks

Example from documentation:
```ruby
class Setting < RailsSettings::Base
  scope :application do
    field :app_name, default: "Rails Settings", validates: { presence: true }
    field :host, default: "http://example.com", readonly: true
  end
  
  scope :limits do  
    field :user_limits, type: :integer, default: 20
    field :captcha_enable, type: :boolean, default: true
  end
end
```

## Final Recommendation: **Option A (Nested) + Security Hybrid**

**Why Option A wins:**
- ✅ **Rails-settings-cached natively supports it** with `scope`
- ✅ **Minimal breaking changes** to existing Vulcan code
- ✅ **Familiar API** for team (Settings.local_login.enabled)
- ✅ **Logical grouping** matches Vulcan's domain concepts
- ✅ **Future admin UI** will be cleanly organized

**Implementation Strategy:**
```ruby
class Settings < RailsSettings::Base
  cache_prefix { "v1" }
  
  # Authentication scope
  scope :local_login do
    field :enabled, type: :boolean, default: true
    field :session_timeout, type: :integer, default: 60, validates: { numericality: { greater_than: 0 } }
    field :email_confirmation, type: :boolean, default: false
  end
  
  scope :oidc do
    field :enabled, type: :boolean, default: false
    field :discovery, type: :boolean, default: true
    field :title, type: :string, default: "Single Sign-On"
    field :issuer_url, type: :string, default: -> { ENV['VULCAN_OIDC_ISSUER_URL'] }, readonly: true
    field :client_id, type: :string, default: -> { ENV['VULCAN_OIDC_CLIENT_ID'] }, readonly: true
    # client_secret stays ENV-only, not in Settings at all
  end
  
  scope :smtp do
    field :enabled, type: :boolean, default: false
    field :address, type: :string, default: -> { ENV['VULCAN_SMTP_ADDRESS'] }, readonly: true
    field :port, type: :integer, default: -> { ENV['VULCAN_SMTP_PORT'] || 587 }, readonly: true
    field :username, type: :string, default: -> { ENV['VULCAN_SMTP_SERVER_USERNAME'] }, readonly: true
    # password stays ENV-only, not in Settings at all
  end
  
  # Simple fields (no scope needed)
  field :contact_email, type: :string, default: "admin@vulcan.local", validates: { format: { with: URI::MailTo::EMAIL_REGEXP } }
  field :app_url, type: :string, default: -> { ENV['VULCAN_APP_URL'] }, readonly: true
end
```

**Access Patterns:**
```ruby
# Familiar nested API (unchanged)
Settings.local_login.enabled          # Database-backed, configurable
Settings.oidc.issuer_url              # ENV-backed, readonly  
Settings.contact_email                # Database-backed, configurable

# Secrets accessed directly from ENV (not in Settings)
ENV['VULCAN_OIDC_CLIENT_SECRET']      # Security best practice
ENV['VULCAN_SMTP_SERVER_PASSWORD']
```

**Benefits of This Approach:**
- 🔒 **Security**: Secrets never touch the database
- 🎯 **Familiarity**: Existing code works unchanged  
- 🏗️ **Infrastructure**: External URLs stay environment-specific
- ⚙️ **Configuration**: Business logic becomes runtime-configurable
- 🚀 **Future**: Clean foundation for admin interface