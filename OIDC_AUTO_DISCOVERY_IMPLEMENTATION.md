# OIDC Auto-Discovery Implementation Plan

**Issue**: [#667 - Implement OIDC auto-discovery to simplify configuration](https://github.com/mitre/vulcan/issues/667)  
**Branch**: `okta-discovery-enhancement`  
**LOE**: 4-8 hours  
**Status**: Ready for implementation

## Overview

Transform Vulcan's OIDC configuration from requiring 8+ manual environment variables to just 4 essential ones by enabling OIDC auto-discovery via the `/.well-known/openid-configuration` endpoint.

## Current State Analysis

### Existing OIDC Implementation
- **Location**: `config/vulcan.default.yml` (lines 46-74)
- **Strategy**: Manual endpoint configuration
- **Variables Required**: 8+ environment variables
- **Partial Discovery**: Already implemented for logout endpoint in `sessions_controller.rb`

### Current Configuration Structure
```yaml
oidc:
  enabled: <%= ENV['VULCAN_ENABLE_OIDC'] || false %>
  strategy: :openid_connect
  args:
    name: :oidc
    scope: [:openid, :email, :profile]
    issuer: <%= ENV['VULCAN_OIDC_ISSUER_URL'] %>
    client_options:
      authorization_endpoint: <%= ENV['VULCAN_OIDC_AUTHORIZATION_URL'] %>
      token_endpoint: <%= ENV['VULCAN_OIDC_TOKEN_URL'] %>
      userinfo_endpoint: <%= ENV['VULCAN_OIDC_USERINFO_URL'] %>
      jwks_uri: <%= ENV['VULCAN_OIDC_JWKS_URI'] %>
```

## Implementation Plan

### Phase 1: Core Discovery Implementation (2-3 hours)

#### 1.1 Update Configuration Structure
**File**: `config/vulcan.default.yml`

```yaml
oidc:
  enabled: <%= ENV['VULCAN_ENABLE_OIDC'] || false %>
  discovery: <%= ENV['VULCAN_OIDC_DISCOVERY'] || true %>  # NEW: Default to auto-discovery
  strategy: :openid_connect
  title: <%= ENV['VULCAN_OIDC_PROVIDER_TITLE'] || 'OIDC Provider' %>
  args:
    name: :oidc
    scope: [:openid, :email, :profile]
    uid_field: 'sub'
    response_type: :code
    discovery: <%= Settings.oidc.discovery %>  # NEW: Enable discovery
    issuer: <%= ENV['VULCAN_OIDC_ISSUER_URL'] %>
    client_id: <%= ENV['VULCAN_OIDC_CLIENT_ID'] %>
    client_secret: <%= ENV['VULCAN_OIDC_CLIENT_SECRET'] %>
    redirect_uri: <%= ENV['VULCAN_OIDC_REDIRECT_URI'] %>
    client_auth_method: <%= ENV['VULCAN_OIDC_CLIENT_SIGNING_ALG']&.to_sym || :RS256 %>
    client_options:
      # Fallback/override endpoints (only used if discovery fails or disabled)
      authorization_endpoint: <%= ENV['VULCAN_OIDC_AUTHORIZATION_URL'] %>
      token_endpoint: <%= ENV['VULCAN_OIDC_TOKEN_URL'] %>
      userinfo_endpoint: <%= ENV['VULCAN_OIDC_USERINFO_URL'] %>
      jwks_uri: <%= ENV['VULCAN_OIDC_JWKS_URI'] %>
```

#### 1.2 Update Settings Initialization  
**File**: `config/initializers/0_settings.rb`

```ruby
# Add after existing OIDC settings
Settings['oidc'] ||= Settingslogic.new({})
Settings.oidc['enabled'] = false if Settings.oidc['enabled'].nil?
Settings.oidc['discovery'] = true if Settings.oidc['discovery'].nil?  # NEW: Default discovery
```

### Phase 2: Enhanced Discovery Logic (1-2 hours)

#### 2.1 Generalize Discovery Helper
**File**: `app/controllers/concerns/oidc_discovery_helper.rb` (NEW)

```ruby
module OidcDiscoveryHelper
  extend ActiveSupport::Concern

  private

  def fetch_oidc_discovery_document(issuer_url, cache_key = 'oidc_discovery')
    # Try session cache first (1 hour TTL)
    cached = session[cache_key]
    return cached if cached&.[]('expires_at')&.> Time.current

    discovery_url = "#{issuer_url.to_s.chomp('/')}/.well-known/openid-configuration"
    
    begin
      response = Net::HTTP.get_response(URI(discovery_url))
      
      if response.is_a?(Net::HTTPSuccess)
        config = JSON.parse(response.body)
        validate_discovery_document(config, issuer_url)
        
        # Cache with expiration
        config['expires_at'] = 1.hour.from_now
        session[cache_key] = config
        
        Rails.logger.info "OIDC Discovery successful for #{issuer_url}"
        return config
      else
        Rails.logger.warn "OIDC Discovery failed: HTTP #{response.code} for #{discovery_url}"
        return nil
      end
    rescue JSON::ParserError => e
      Rails.logger.error "OIDC Discovery: Invalid JSON response from #{discovery_url}: #{e.message}"
      return nil
    rescue => e
      Rails.logger.error "OIDC Discovery error for #{discovery_url}: #{e.message}"
      return nil
    end
  end

  def validate_discovery_document(config, expected_issuer)
    # OIDC spec requirement: issuer must match
    actual_issuer = config['issuer']
    unless actual_issuer == expected_issuer
      raise "OIDC Discovery: Issuer mismatch. Expected '#{expected_issuer}', got '#{actual_issuer}'"
    end
    
    # Check required fields per OIDC spec
    required_fields = %w[
      issuer 
      authorization_endpoint 
      response_types_supported 
      subject_types_supported 
      id_token_signing_alg_values_supported
    ]
    
    missing_fields = required_fields - config.keys
    if missing_fields.any?
      raise "OIDC Discovery: Missing required fields: #{missing_fields.join(', ')}"
    end
    
    true
  end

  def fetch_oidc_endpoint(endpoint_name, fallback_url = nil)
    return fallback_url unless Settings.oidc.discovery

    issuer_url = Settings.oidc.args.issuer || ENV['VULCAN_OIDC_ISSUER_URL']
    return fallback_url unless issuer_url

    discovery = fetch_oidc_discovery_document(issuer_url)
    discovery&.[](endpoint_name) || fallback_url
  end
end
```

#### 2.2 Update Sessions Controller
**File**: `app/controllers/sessions_controller.rb`

```ruby
class SessionsController < ApplicationController
  include OidcDiscoveryHelper  # NEW: Include helper

  # ... existing code ...

  private

  def fetch_oidc_logout_endpoint
    # Use generalized discovery helper
    fetch_oidc_endpoint('end_session_endpoint', okta_fallback_logout_url)
  end

  def okta_fallback_logout_url
    issuer_url = Settings.oidc.args.issuer || ENV['VULCAN_OIDC_ISSUER_URL']
    "#{issuer_url.to_s.chomp('/')}/oauth2/v1/logout"
  end
end
```

### Phase 3: Testing & Validation (1-2 hours)

#### 3.1 Update Existing Tests
**File**: `spec/controllers/sessions_controller_spec.rb`

```ruby
# Add new test cases for discovery functionality
describe '#fetch_oidc_logout_endpoint' do
  context 'when discovery is enabled' do
    before { Settings.oidc.discovery = true }
    
    it 'uses discovered endpoint when available' do
      # Test discovery success
    end
    
    it 'falls back to manual config when discovery fails' do
      # Test discovery failure fallback
    end
  end

  context 'when discovery is disabled' do
    before { Settings.oidc.discovery = false }
    
    it 'uses manual configuration' do
      # Test manual config path
    end
  end
end
```

#### 3.2 Add Discovery Integration Tests
**File**: `spec/features/oidc_discovery_spec.rb` (NEW)

```ruby
require 'rails_helper'

RSpec.describe 'OIDC Discovery Integration', type: :feature do
  let(:mock_discovery_response) do
    {
      issuer: 'https://example.okta.com',
      authorization_endpoint: 'https://example.okta.com/oauth2/v1/authorize',
      token_endpoint: 'https://example.okta.com/oauth2/v1/token',
      userinfo_endpoint: 'https://example.okta.com/oauth2/v1/userinfo',
      end_session_endpoint: 'https://example.okta.com/oauth2/v1/logout'
    }
  end

  before do
    # Mock discovery endpoint
    stub_request(:get, 'https://example.okta.com/.well-known/openid-configuration')
      .to_return(status: 200, body: mock_discovery_response.to_json)
  end

  context 'with discovery enabled' do
    it 'automatically configures OIDC endpoints' do
      # Test end-to-end discovery functionality
    end
  end

  context 'with discovery disabled' do
    it 'uses manual configuration' do
      # Test manual configuration still works
    end
  end
end
```

## Configuration Migration Guide

### Before (8+ Environment Variables)
```bash
VULCAN_ENABLE_OIDC=true
VULCAN_OIDC_PROVIDER_TITLE="Okta"
VULCAN_OIDC_ISSUER_URL="https://dev-12345.okta.com"
VULCAN_OIDC_CLIENT_ID="client_id"
VULCAN_OIDC_CLIENT_SECRET="client_secret"
VULCAN_OIDC_REDIRECT_URI="https://vulcan.example.com/users/auth/oidc/callback"
VULCAN_OIDC_AUTHORIZATION_URL="https://dev-12345.okta.com/oauth2/default/v1/authorize"
VULCAN_OIDC_TOKEN_URL="https://dev-12345.okta.com/oauth2/default/v1/token"
VULCAN_OIDC_USERINFO_URL="https://dev-12345.okta.com/oauth2/default/v1/userinfo"
VULCAN_OIDC_JWKS_URI="https://dev-12345.okta.com/oauth2/default/v1/keys"
```

### After (4 Essential Variables)
```bash
VULCAN_ENABLE_OIDC=true
VULCAN_OIDC_ISSUER_URL="https://dev-12345.okta.com"
VULCAN_OIDC_CLIENT_ID="client_id"
VULCAN_OIDC_CLIENT_SECRET="client_secret"
VULCAN_OIDC_REDIRECT_URI="https://vulcan.example.com/users/auth/oidc/callback"

# Optional: Disable discovery if needed
# VULCAN_OIDC_DISCOVERY=false

# Optional: Manual overrides (only used as fallbacks)
# VULCAN_OIDC_AUTHORIZATION_URL="custom_auth_endpoint"
```

## Provider Compatibility Matrix

| Provider | Discovery Support | Known Issues | Recommended Settings |
|----------|-------------------|--------------|---------------------|
| **Okta** | ✅ Full | None | Default settings work |
| **Auth0** | ✅ Full | Custom domain setup | Verify issuer URL |
| **Keycloak** | ✅ Full | None | `client_auth_method: :secret` |
| **Azure AD** | ✅ Full | Issuer validation | Match exact issuer |
| **Google** | ✅ Full | None | Default settings work |

## Error Handling Strategy

### 1. Discovery Failure Scenarios
- **Network timeout**: Fall back to manual configuration
- **Invalid JSON**: Log error, use manual configuration  
- **Missing required fields**: Log validation error, use manual configuration
- **Issuer mismatch**: Log security warning, use manual configuration

### 2. Configuration Precedence
1. **Manual endpoints** (highest priority) - always respected if provided
2. **Auto-discovered endpoints** (medium priority) - used when discovery succeeds
3. **Gem defaults** (lowest priority) - omniauth_openid_connect defaults

### 3. Logging Strategy
- **Info**: Successful discovery
- **Warn**: Discovery failed, falling back
- **Error**: Security issues (issuer mismatch, validation failures)

## Testing Checklist

- [ ] Discovery enabled with valid provider (Okta/Auth0/etc.)
- [ ] Discovery disabled - manual configuration works
- [ ] Discovery failure - graceful fallback to manual config
- [ ] Network timeout during discovery
- [ ] Invalid JSON response from discovery endpoint
- [ ] Missing required fields in discovery document
- [ ] Issuer mismatch validation
- [ ] Session caching of discovery results
- [ ] Multiple OIDC providers compatibility
- [ ] Backward compatibility with existing configurations

## Security Considerations

1. **Issuer Validation**: Always validate discovery issuer matches expected issuer
2. **HTTPS Only**: Discovery endpoints must use HTTPS
3. **Cache Expiration**: Discovery results cached max 1 hour
4. **Error Logging**: No sensitive information in logs
5. **Fallback Security**: Manual configuration as secure fallback

## Success Criteria

1. ✅ Reduce OIDC configuration from 8+ to 4 environment variables
2. ✅ Maintain backward compatibility with existing manual configurations
3. ✅ Automatic endpoint updates when provider changes endpoints
4. ✅ Robust error handling and fallback mechanisms
5. ✅ Comprehensive test coverage for all scenarios
6. ✅ Production-ready logging and monitoring

## Implementation Notes

- **Non-breaking change**: Existing configurations continue to work
- **Gradual migration**: Teams can migrate at their own pace
- **Provider agnostic**: Works with any OIDC-compliant provider
- **Rails best practices**: Uses concerns, proper error handling, caching
- **Security first**: Validates all discovery responses per OIDC spec

---

**Ready for Implementation**: This document provides a complete roadmap for implementing OIDC auto-discovery in Vulcan with proper error handling, testing, and security considerations.