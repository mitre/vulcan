# Okta OIDC Setup Guide for Vulcan

## Overview

This guide covers the complete setup for Okta authentication in Vulcan, including solutions for common issues like:
- Users not being prompted for 2FA on subsequent logins
- Session persistence issues
- Proper logout implementation
- CSRF token problems

## Working Environment Variables Configuration

Based on a proven working setup, here's the complete configuration for Okta authentication:

```bash
# Core OIDC Settings
VULCAN_ENABLE_LDAP=false
VULCAN_ENABLE_OIDC=true
VULCAN_OIDC_PROVIDER_TITLE=OKTA

# Okta Domain and URLs
VULCAN_OIDC_HOST=your-domain.okta.com
VULCAN_APP_URL=https://your-vulcan-app.com

# Okta OAuth2 Endpoints (using default authorization server)
VULCAN_OIDC_ISSUER_URL=https://your-domain.okta.com/oauth2/default
VULCAN_OIDC_AUTHORIZATION_URL=https://your-domain.okta.com/oauth2/default/v1/authorize
VULCAN_OIDC_TOKEN_URL=https://your-domain.okta.com/oauth2/default/v1/token
VULCAN_OIDC_USERINFO_URL=https://your-domain.okta.com/oauth2/default/v1/userinfo
VULCAN_OIDC_JWKS_URI=https://your-domain.okta.com/oauth2/default/v1/keys

# Client Configuration
VULCAN_OIDC_CLIENT_ID=your-okta-client-id
VULCAN_OIDC_CLIENT_SECRET=your-okta-client-secret
VULCAN_OIDC_REDIRECT_URI=https://your-vulcan-app.com/users/auth/oidc/callback

# Optional: Force re-authentication with 2FA
# Add this to vulcan.yml under oidc.args section:
# prompt: 'login'
```

## Okta Application Setup

### 1. Create Application in Okta Admin Console

1. Navigate to Applications > Create App Integration
2. Configure with these settings:
   - **Sign-in method**: OIDC - OpenID Connect
   - **Application type**: Web Application
   - **Grant type**: Authorization Code
   - **Sign-in redirect URIs**: `https://your-vulcan-app.com/users/auth/oidc/callback`
   - **Sign-out redirect URIs**: `https://your-vulcan-app.com/`
   - **Controlled access**: Configure based on your organization's policies

3. Save and note the Client ID and Client Secret

### 2. Configure Authorization Server

- Using the default authorization server (`/oauth2/default`) is recommended
- For custom authorization servers, adjust the URLs accordingly
- Ensure the following scopes are granted: `openid`, `profile`, `email`

### 3. Important Configuration Notes

- The redirect URI must match EXACTLY (protocol, domain, path, no trailing slash)
- Always use HTTPS in production environments
- Configure Okta policies to enforce MFA as needed

## Kubernetes ConfigMap Example

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vulcan-oidc-config
data:
  VULCAN_ENABLE_LDAP: "false"
  VULCAN_ENABLE_OIDC: "true"
  VULCAN_OIDC_PROVIDER_TITLE: "OKTA"
  VULCAN_OIDC_HOST: "your-domain.okta.com"
  VULCAN_APP_URL: "https://your-vulcan-app.com"
  VULCAN_OIDC_ISSUER_URL: "https://your-domain.okta.com/oauth2/default"
  VULCAN_OIDC_AUTHORIZATION_URL: "https://your-domain.okta.com/oauth2/default/v1/authorize"
  VULCAN_OIDC_USERINFO_URL: "https://your-domain.okta.com/oauth2/default/v1/userinfo"
  VULCAN_OIDC_TOKEN_URL: "https://your-domain.okta.com/oauth2/default/v1/token"
  VULCAN_OIDC_REDIRECT_URI: "https://your-vulcan-app.com/users/auth/oidc/callback"
  VULCAN_OIDC_JWKS_URI: "https://your-domain.okta.com/oauth2/default/v1/keys"
```

## Okta Application Setup

1. **Create Application in Okta Admin Console**:
   - Application type: `Web`
   - Grant type: `Authorization Code`
   - Sign-in redirect URIs: `https://your-vulcan-app.com/users/auth/oidc/callback`
   - Sign-out redirect URIs: `https://your-vulcan-app.com/`
   - Controlled access: Configure based on your organization's needs

2. **Important Notes**:
   - Using `/oauth2/default` authorization server is recommended
   - Ensure your Okta app has the correct redirect URI that matches exactly
   - The redirect URI must use HTTPS in production

## Fixing 2FA Re-authentication Issues

If users are not being prompted for 2FA on subsequent logins, add a custom `vulcan.yml`:

```yaml
defaults: &defaults
  oidc:
    enabled: true
    strategy: :openid_connect
    title: "OKTA"
    args:
      name: :oidc
      scope:
      - :openid
      - :email
      - :profile
      uid_field: 'sub'
      response_type: :code
      # Force re-authentication with 2FA
      prompt: 'login'
      issuer: <%= ENV['VULCAN_OIDC_ISSUER_URL'] %>
      client_auth_method: :secret
      client_signing_alg: :RS256
      nonce: <%= proc { SecureRandom.hex(32) } %>
      client_options:
        port: 443
        scheme: https
        host: <%= ENV['VULCAN_OIDC_HOST'] %>
        identifier: <%= ENV['VULCAN_OIDC_CLIENT_ID'] %>
        secret: <%= ENV['VULCAN_OIDC_CLIENT_SECRET'] %>
        redirect_uri: <%= ENV['VULCAN_OIDC_REDIRECT_URI'] %>
        authorization_endpoint: <%= ENV['VULCAN_OIDC_AUTHORIZATION_URL'] %>
        token_endpoint: <%= ENV['VULCAN_OIDC_TOKEN_URL'] %>
        userinfo_endpoint: <%= ENV['VULCAN_OIDC_USERINFO_URL'] %>
        jwks_uri: <%= ENV['VULCAN_OIDC_JWKS_URI'] %>
        # For proper logout (optional)
        end_session_endpoint: https://your-domain.okta.com/oauth2/default/v1/logout
        post_logout_redirect_uri: <%= ENV['VULCAN_APP_URL'] %>

development:
  <<: *defaults

production:
  <<: *defaults
```

## Additional Security Configurations

### 1. Implement Proper Logout with Session Cleanup

Create a custom sessions controller to handle both local and Okta session termination:

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < Devise::SessionsController
  def destroy
    id_token = session[:id_token]
    session.clear
    reset_session
    
    if Settings.oidc.enabled && id_token
      # Construct Okta logout URL
      okta_logout_params = {
        id_token_hint: id_token,
        post_logout_redirect_uri: root_url
      }.to_query
      
      okta_logout_url = "https://#{ENV['VULCAN_OIDC_HOST']}/oauth2/default/v1/logout?#{okta_logout_params}"
      redirect_to okta_logout_url, allow_other_host: true
    else
      super
    end
  end
end
```

Update routes to use the custom controller:
```ruby
# config/routes.rb
devise_for :users, controllers: {
  omniauth_callbacks: 'users/omniauth_callbacks',
  registrations: 'users/registrations',
  sessions: 'sessions'
}
```

### 2. Store ID Token for Logout

Modify the OmniAuth callback to store the ID token:

```ruby
# app/controllers/users/omniauth_callbacks_controller.rb
def oidc
  auth = request.env['omniauth.auth']
  user = User.from_omniauth(auth)
  
  # Store ID token for logout
  session[:id_token] = auth.credentials.id_token if auth.credentials.id_token
  
  flash.notice = I18n.t('devise.sessions.signed_in')
  sign_in_and_redirect(user)
end
```

### 3. Add CSRF Protection for OmniAuth

Ensure CSRF protection is properly configured:

```ruby
# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  # This handles CSRF protection
  provider :developer unless Rails.env.production?
end

# Ensure omniauth-rails_csrf_protection gem is in Gemfile
```

### 4. Configure Session Security

Add session security settings:

```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :cookie_store, 
  key: '_vulcan_session',
  secure: Rails.env.production?, # HTTPS only in production
  httponly: true,
  same_site: :lax # Prevents CSRF attacks
```

## Troubleshooting

### Users not prompted for 2FA
1. Add `prompt: 'login'` to force re-authentication
2. Clear browser cookies for both your app and Okta domains
3. Ensure Okta policies require 2FA for the application
4. Check Okta's session lifetime settings (shorter = more frequent 2FA)

### "Invalid Credentials" Error
1. Verify all environment variables are set correctly
2. Ensure you're using the correct authorization server (`/oauth2/default` or custom)
3. Check that redirect URI matches exactly (protocol, domain, path)
4. Verify client ID and secret are correct

### Login redirect issues
1. Verify the redirect URI matches exactly (including trailing slashes)
2. Check that VULCAN_APP_URL is set correctly and includes protocol (https://)
3. Ensure HTTPS is used in production
4. Add redirect URI to Okta app's allowed list

### Session timeout issues
1. Check `Settings.local_login.session_timeout` configuration
2. Verify Devise `:timeoutable` is configured properly
3. Consider Okta session lifetime settings
4. Implement activity-based session extension if needed

### CSRF Token Errors
1. Ensure `omniauth-rails_csrf_protection` gem is installed
2. Verify `protect_from_forgery` is enabled in ApplicationController
3. Check that session cookies are properly configured

## Best Practices

1. **Use Discovery Endpoint**: Consider using OIDC discovery for automatic configuration:
   ```ruby
   # In vulcan.yml
   discovery: true
   issuer: https://your-domain.okta.com/oauth2/default
   ```

2. **Monitor Auth Logs**: Enable detailed logging in development:
   ```ruby
   # config/initializers/omniauth.rb
   OmniAuth.config.logger = Rails.logger if Rails.env.development?
   ```

3. **Handle Auth Failures Gracefully**:
   ```ruby
   # app/controllers/application_controller.rb
   def after_sign_in_path_for(resource)
     stored_location_for(resource) || projects_path
   end
   
   def after_sign_out_path_for(resource_or_scope)
     new_user_session_path
   end
   ```

4. **Test Integration Thoroughly**:
   - Test login flow with 2FA enabled
   - Test logout from both app and Okta
   - Test session timeout behavior
   - Test with multiple browser tabs

[vulcan-okta-auth-fixes.zip](https://github.com/user-attachments/files/20616258/vulcan-okta-auth-fixes.zip)
