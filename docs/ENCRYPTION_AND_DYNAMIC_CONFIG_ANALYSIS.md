# Encryption & Dynamic Configuration Analysis

## Rails-settings-cached Encryption Support

### ❌ **Rails-settings-cached does NOT provide built-in encryption**
- No `encrypted: true` field option
- No automatic encryption/decryption of sensitive values
- Only offers `readonly: true` for write protection

## Rails 7 Active Record Encryption Alternative

### ✅ **Rails 7 provides built-in encryption for any Active Record model**

```ruby
# We could use Active Record Encryption with rails-settings-cached
class Settings < RailsSettings::Base
  # This WOULD work - encrypt specific fields
  field :smtp_password, type: :string, encrypts: true  # ❌ Not supported
  
  # But we COULD do this since Settings inherits from ActiveRecord:
  encrypts :smtp_password  # ✅ This WOULD work!
end
```

**How Active Record Encryption works:**
- Transparent encryption/decryption at application level
- Uses Rails master key (same as credentials)
- Protects against database breaches, stolen backups
- Performance overhead: ~255 bytes per field, compression helps

## Dynamic Multi-Provider Requirements Analysis

### Current Vulcan Structure (Static)
```yaml
# Single OIDC provider - static configuration
oidc:
  enabled: true
  issuer: <%= ENV['VULCAN_OIDC_ISSUER_URL'] %>
  client_id: <%= ENV['VULCAN_OIDC_CLIENT_ID'] %>
  client_secret: <%= ENV['VULCAN_OIDC_CLIENT_SECRET'] %>

# Single LDAP server - static configuration  
ldap:
  servers:
    main:
      host: <%= ENV['VULCAN_LDAP_HOST'] %>
```

### Future Requirements (Dynamic)
```ruby
# Multiple OIDC providers - dynamic configuration
OidcProvider.create!(
  name: "Company SSO",
  issuer_url: "https://company.okta.com",
  client_id: "abc123",
  client_secret: "secret123",  # ← Needs encryption!
  enabled: true
)

OidcProvider.create!(
  name: "Partner SSO", 
  issuer_url: "https://partner.auth0.com",
  client_id: "def456",
  client_secret: "secret456",  # ← Needs encryption!
  enabled: true
)
```

## Architecture Options Comparison

### Option 1: ENV-Only (Current Approach)
```ruby
# Pros:
✅ Maximum security (secrets never in database)
✅ 12-factor app compliance
✅ Simple, proven approach

# Cons:
❌ No runtime configuration changes
❌ Single provider limitation
❌ Requires app restart for changes
❌ No admin UI possible
```

### Option 2: Database + Active Record Encryption
```ruby
class Settings < RailsSettings::Base
  scope :oidc do
    field :enabled, type: :boolean, default: false
    field :client_secret, type: :string  # Will be encrypted
  end
  
  # Enable encryption for secrets
  encrypts :oidc_client_secret
  encrypts :smtp_password
  encrypts :slack_api_token
end

# Pros:
✅ Runtime configuration changes
✅ Admin UI possible
✅ Database encryption protection
✅ Single provider in Settings works

# Cons:
❌ Still limited to single provider per type
❌ Secrets in database (encrypted, but still there)
❌ More complex security model
```

### Option 3: Hybrid Dedicated Models (Recommended for Future)
```ruby
# Settings for simple configuration
class Settings < RailsSettings::Base
  scope :features do
    field :oidc_enabled, type: :boolean, default: false
    field :ldap_enabled, type: :boolean, default: false
  end
end

# Dedicated models for multi-provider support
class OidcProvider < ApplicationRecord
  encrypts :client_secret
  validates :name, presence: true, uniqueness: true
  scope :enabled, -> { where(enabled: true) }
end

class LdapServer < ApplicationRecord  
  encrypts :bind_password
  validates :name, presence: true, uniqueness: true
  scope :enabled, -> { where(enabled: true) }
end

# Pros:
✅ Multiple providers support
✅ Runtime configuration via admin UI
✅ Encrypted secrets in database
✅ Clean separation of concerns
✅ Easy to extend with new provider types
✅ Per-provider enable/disable

# Cons:
❌ More complex architecture
❌ Requires migration strategy
❌ Need to update devise configuration loading
```

## Security Considerations

### Database Encryption vs ENV-Only

**Database + Encryption provides protection against:**
- Database dumps/backups theft
- Database administrator access
- SQL injection attacks
- Application logs exposure

**ENV-Only provides protection against:**
- All of the above PLUS:
- Application-level vulnerabilities
- Credential rotation complexity
- Admin UI security issues

### Recommendation for Vulcan

**Phase 1 (Current Migration): Option 2 - Database + Encryption**
- Enables current migration to succeed
- Provides foundation for admin UI
- Maintains single-provider support
- Uses Rails 7 Active Record Encryption

**Phase 2 (Future Enhancement): Option 3 - Dedicated Models**
- Enables multiple OIDC/LDAP providers
- Full admin UI for provider management
- Enterprise-grade configuration management

## Implementation Strategy

```ruby
# Phase 1: Enhanced Settings with Encryption
class Settings < RailsSettings::Base
  scope :oidc do
    field :enabled, type: :boolean, default: false
    field :title, type: :string, default: "Single Sign-On"
    field :client_secret, type: :string, default: -> { ENV['VULCAN_OIDC_CLIENT_SECRET'] }
  end
  
  scope :smtp do
    field :enabled, type: :boolean, default: false
    field :password, type: :string, default: -> { ENV['VULCAN_SMTP_SERVER_PASSWORD'] }
  end
  
  # Encrypt secrets when stored in database
  encrypts :oidc_client_secret, :smtp_password, :slack_api_token
end
```

**This approach:**
- ✅ Solves current migration needs
- ✅ Enables admin UI development
- ✅ Provides encrypted secret storage
- ✅ Maintains familiar API
- ✅ Sets foundation for multi-provider future