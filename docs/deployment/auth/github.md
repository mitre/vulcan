# GitHub OAuth Authentication

This guide covers configuring GitHub OAuth for user authentication in Vulcan.

## Prerequisites

- GitHub account with ability to create OAuth Apps
- Vulcan instance with public URL (for callback)
- Admin access to Vulcan configuration

## GitHub OAuth App Setup

### 1. Create OAuth Application

1. Go to GitHub Settings -> Developer settings -> OAuth Apps
2. Click **"New OAuth App"**
3. Fill in the application details:
   - **Application name**: `Vulcan` (or your custom name)
   - **Homepage URL**: `https://vulcan.example.com`
   - **Authorization callback URL**: `https://vulcan.example.com/users/auth/github/callback`
4. Click **"Register application"**

### 2. Get Application Credentials

After creating the app, you'll receive:
- **Client ID**: Public identifier for your app
- **Client Secret**: Private key (keep secure!)

## Vulcan Configuration

### Using Environment Variables

Set the following environment variables:

```bash
# Enable GitHub authentication
VULCAN_ENABLE_GITHUB_AUTH=true

# GitHub OAuth credentials
VULCAN_GITHUB_APP_ID=your_client_id_here
VULCAN_GITHUB_APP_SECRET=your_client_secret_here

# Optional: Request additional scopes
VULCAN_GITHUB_SCOPE="user:email,read:org"
```

### Using Configuration File

Edit `config/vulcan.yml`:

```yaml
production:
  providers:
    - name: 'github'
      app_id: 'your_client_id_here'
      app_secret: 'your_client_secret_here'
      args:
        scope: 'user:email,read:org'
        # Optional: Restrict to organization members
        # organizations: ['your-org-name']
```

## Advanced Configuration

### Organization Restrictions

Limit access to members of specific GitHub organizations:

```yaml
providers:
  - name: 'github'
    app_id: 'your_client_id'
    app_secret: 'your_client_secret'
    args:
      scope: 'user:email,read:org'
      organizations:
        - 'mitre'
        - 'your-org'
      # Require organization membership
      organization_member: true
```

### Team Restrictions

Further restrict to specific teams within organizations:

```yaml
providers:
  - name: 'github'
    app_id: 'your_client_id'
    app_secret: 'your_client_secret'
    args:
      scope: 'user:email,read:org'
      organizations:
        - 'mitre'
      teams:
        - 'mitre/vulcan-developers'
        - 'mitre/security-team'
```

### Enterprise GitHub

For GitHub Enterprise instances:

```yaml
providers:
  - name: 'github'
    app_id: 'your_client_id'
    app_secret: 'your_client_secret'
    args:
      scope: 'user:email,read:org'
      client_options:
        site: 'https://github.enterprise.com'
        authorize_url: 'https://github.enterprise.com/login/oauth/authorize'
        token_url: 'https://github.enterprise.com/login/oauth/access_token'
```

## User Experience

### Login Flow

1. User clicks "Sign in with GitHub" on login page
2. Redirected to GitHub authorization page
3. User approves access (first time only)
4. Redirected back to Vulcan, logged in
5. Account created automatically if new user

### Account Linking

For existing Vulcan accounts:

1. User logs in with local credentials
2. Navigate to Settings -> Connected Accounts
3. Click "Connect GitHub Account"
4. Complete GitHub authorization
5. Accounts are now linked

## Scopes and Permissions

### Available GitHub Scopes

| Scope | Description | Required |
|-------|-------------|----------|
| `user:email` | Access user's email addresses | Yes |
| `read:user` | Read user profile information | Yes |
| `read:org` | Read organization membership | For org restrictions |
| `repo` | Access repositories | No |
| `admin:org` | Manage organization | No |

### Recommended Minimal Scope

```yaml
scope: 'user:email'  # Minimum required
```

### Organization Access Scope

```yaml
scope: 'user:email,read:org'  # For organization features
```

## Security Considerations

### 1. Secure Credentials

- Never commit OAuth secrets to version control
- Use environment variables or secure vaults
- Rotate secrets periodically

### 2. Callback URL Validation

Ensure callback URL exactly matches:
- Protocol (http vs https)
- Domain name
- Path including trailing slash

### 3. HTTPS Required

Always use HTTPS in production:
- GitHub requires HTTPS for OAuth callbacks
- Protects tokens in transit

## Troubleshooting

### Common Issues

#### "Redirect URI Mismatch"

**Problem**: Callback URL doesn't match GitHub app configuration

**Solution**:
1. Verify URL in GitHub OAuth app settings
2. Check for trailing slashes
3. Ensure HTTPS is used
4. Confirm correct domain/subdomain

#### "Bad Authentication Credentials"

**Problem**: Invalid client ID or secret

**Solution**:
1. Regenerate client secret in GitHub
2. Update Vulcan configuration
3. Restart Vulcan application
4. Clear browser cookies

#### "Organization Access Denied"

**Problem**: User not member of required organization

**Solution**:
1. Verify user's organization membership
2. Check organization visibility settings
3. Ensure correct scope requested
4. Review organization's third-party access policy

### Debug Mode

Enable OAuth debug logging:

```ruby
# config/initializers/omniauth.rb
OmniAuth.config.logger = Rails.logger
OmniAuth.config.full_host = 'https://vulcan.example.com'
```

### Testing Authentication

```bash
# Test GitHub API access
curl -H "Authorization: token YOUR_OAUTH_TOKEN" \
     https://api.github.com/user

# Check organization membership
curl -H "Authorization: token YOUR_OAUTH_TOKEN" \
     https://api.github.com/user/orgs
```

## Multiple GitHub Instances

Support both GitHub.com and Enterprise:

```yaml
providers:
  - name: 'github'
    display_name: 'GitHub.com'
    app_id: 'public_github_client_id'
    app_secret: 'public_github_secret'
    
  - name: 'github_enterprise'
    display_name: 'GitHub Enterprise'
    app_id: 'enterprise_client_id'
    app_secret: 'enterprise_secret'
    args:
      client_options:
        site: 'https://github.enterprise.com'
```

## Revoking Access

### For Users

1. Go to GitHub Settings -> Applications -> Authorized OAuth Apps
2. Find Vulcan application
3. Click "Revoke access"

### For Administrators

```ruby
# Rails console command to unlink GitHub account
user = User.find_by(email: 'user@example.com')
user.identities.where(provider: 'github').destroy_all
```

## Migration from Other Auth Providers

### Migrating Existing Users

```ruby
# Script to link existing users with GitHub accounts
User.find_each do |user|
  # Match by email
  github_email = user.email
  
  # Create identity record
  user.identities.create!(
    provider: 'github',
    uid: github_user_id,
    email: github_email
  )
end
```

## Best Practices

1. **Use Organization Restrictions**: Limit access to your organization
2. **Minimal Scopes**: Only request necessary permissions
3. **Regular Audits**: Review authorized users periodically
4. **Monitor Usage**: Track login patterns and anomalies
5. **Backup Authentication**: Keep alternative auth methods enabled

## Additional Resources

- [GitHub OAuth Documentation](https://docs.github.com/en/developers/apps/building-oauth-apps)
- [GitHub OAuth Scopes](https://docs.github.com/en/developers/apps/building-oauth-apps/scopes-for-oauth-apps)
- [OmniAuth GitHub Strategy](https://github.com/omniauth/omniauth-github)