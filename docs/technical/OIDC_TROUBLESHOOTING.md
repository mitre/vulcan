# OIDC Auto-Discovery Troubleshooting Guide

This guide helps diagnose and resolve common issues with Vulcan's OIDC auto-discovery functionality.

## Quick Diagnostics

### Check Discovery Status
1. **Enable debug logging** by setting `RAILS_LOG_LEVEL=debug`
2. **Restart Vulcan** and attempt authentication
3. **Check logs** for discovery-related messages:
   ```bash
   # Look for discovery success
   grep "OIDC Discovery successful" logs/production.log

   # Look for discovery failures
   grep "OIDC Discovery" logs/production.log | grep -E "(failed|error|timeout)"
   ```

### Verify Configuration
```bash
# Check if discovery is enabled (should be true by default)
echo $VULCAN_OIDC_DISCOVERY

# Verify essential variables are set
echo $VULCAN_OIDC_ISSUER_URL
echo $VULCAN_OIDC_CLIENT_ID
echo $VULCAN_OIDC_CLIENT_SECRET
```

## Common Issues & Solutions

### 1. Discovery Endpoint Not Found (HTTP 404)

**Symptoms:**
- Log message: `OIDC Discovery failed: HTTP 404`
- Authentication fails to start

**Causes & Solutions:**

**Incorrect Issuer URL:**
```bash
# ❌ Wrong
VULCAN_OIDC_ISSUER_URL=https://dev-12345.okta.com/oauth2/default

# ✅ Correct
VULCAN_OIDC_ISSUER_URL=https://dev-12345.okta.com
```

**Provider-Specific Issues:**
- **Auth0**: Ensure using correct domain format
  ```bash
  # ✅ Correct
  VULCAN_OIDC_ISSUER_URL=https://your-domain.auth0.com
  ```
- **Keycloak**: Include realm in URL
  ```bash
  # ✅ Correct
  VULCAN_OIDC_ISSUER_URL=https://keycloak.example.com/realms/your-realm
  ```

### 2. Issuer Mismatch Security Error

**Symptoms:**
- Log message: `OIDC Discovery: Issuer mismatch`
- Discovery fails with security error

**Cause:**
The `issuer` field in the discovery document doesn't match your configured `VULCAN_OIDC_ISSUER_URL`.

**Solutions:**
1. **Check the actual issuer** by manually fetching the discovery document:
   ```bash
   curl https://your-domain.okta.com/.well-known/openid-configuration | jq .issuer
   ```

2. **Update your configuration** to match the exact issuer:
   ```bash
   # Example: If discovery returns "https://dev-12345.okta.com/"
   VULCAN_OIDC_ISSUER_URL=https://dev-12345.okta.com/
   ```

### 3. Network Timeouts

**Symptoms:**
- Log message: `OIDC Discovery timeout`
- Slow or failed authentication

**Causes & Solutions:**

**Firewall/Network Issues:**
1. **Test connectivity** from the Vulcan server:
   ```bash
   curl -I https://your-domain.okta.com/.well-known/openid-configuration
   ```

2. **Check network configuration:**
   - Ensure outbound HTTPS (port 443) is allowed
   - Verify DNS resolution works
   - Check for proxy settings

**High Network Latency:**
- Discovery has built-in timeouts (5s connection, 10s read)
- Consider using manual configuration if network is consistently slow

### 4. HTTPS Requirement Errors

**Symptoms:**
- Log message: `OIDC issuer must use HTTPS in production`
- Discovery fails in production

**Cause:**
Vulcan enforces HTTPS for security in production environments.

**Solutions:**
1. **Use HTTPS URLs:**
   ```bash
   # ❌ Wrong in production
   VULCAN_OIDC_ISSUER_URL=http://provider.com

   # ✅ Correct
   VULCAN_OIDC_ISSUER_URL=https://provider.com
   ```

2. **Development environments** allow HTTP for testing:
   ```bash
   RAILS_ENV=development  # HTTP allowed
   ```

### 5. Discovery Document Too Large

**Symptoms:**
- Log message: `Discovery document too large`
- Discovery fails with security error

**Cause:**
Discovery document exceeds 100KB security limit.

**Solution:**
This is rare with standard providers. If encountered:
1. **Verify the endpoint** returns valid OIDC discovery
2. **Check for proxy issues** that might be returning error pages
3. **Disable discovery** and use manual configuration:
   ```bash
   VULCAN_OIDC_DISCOVERY=false
   # Add manual endpoint configurations
   ```

### 6. Authentication Flow Fails After Discovery

**Symptoms:**
- Discovery succeeds but authentication fails
- Redirect loops or authorization errors

**Common Causes:**

**Incorrect Redirect URI:**
```bash
# Ensure this matches your app configuration
VULCAN_OIDC_REDIRECT_URI=https://your-domain.com/users/auth/oidc/callback
```

**Client Credentials Issues:**
- Double-check `VULCAN_OIDC_CLIENT_ID` and `VULCAN_OIDC_CLIENT_SECRET`
- Verify client is configured correctly in your provider

**Provider Configuration Issues:**
- Check that authorization code flow is enabled
- Verify required scopes are granted (openid, email, profile)

### 7. Cache-Related Issues

**Symptoms:**
- Stale endpoints after provider configuration changes
- Discovery not picking up new endpoints

**Solutions:**
1. **Clear user sessions:**
   ```bash
   # Restart Vulcan to clear all sessions
   sudo systemctl restart vulcan
   ```

2. **Verify cache TTL:**
   - Discovery cache expires after 1 hour
   - Wait for cache expiration or restart application

## Provider-Specific Troubleshooting

### Okta
- **Discovery URL:** `https://your-domain.okta.com/.well-known/openid-configuration`
- **Common Issue:** Authorization server vs organization URL
  ```bash
  # ✅ Organization URL (recommended)
  VULCAN_OIDC_ISSUER_URL=https://dev-12345.okta.com
  
  # ⚠️ Authorization server URL (if using custom server)
  VULCAN_OIDC_ISSUER_URL=https://dev-12345.okta.com/oauth2/your-auth-server
  ```

### Auth0
- **Discovery URL:** `https://your-domain.auth0.com/.well-known/openid-configuration`
- **Common Issue:** Custom domains require exact configuration
- **Verify issuer:** Should match your Auth0 domain exactly

### Keycloak
- **Discovery URL:** `https://keycloak.example.com/realms/your-realm/.well-known/openid-configuration`
- **Common Issue:** Realm must be included in issuer URL
- **Client Settings:** Ensure "Standard Flow" is enabled

### Azure AD
- **Discovery URL:** `https://login.microsoftonline.com/your-tenant-id/v2.0/.well-known/openid-configuration`
- **Common Issue:** Tenant ID vs tenant name in URL
- **App Registration:** Ensure "ID tokens" is enabled

## Fallback to Manual Configuration

If auto-discovery continues to fail, you can disable it and use manual configuration:

```bash
# Disable auto-discovery
VULCAN_OIDC_DISCOVERY=false

# Manual endpoint configuration
VULCAN_OIDC_AUTHORIZATION_URL=https://provider.com/oauth2/authorize
VULCAN_OIDC_TOKEN_URL=https://provider.com/oauth2/token
VULCAN_OIDC_USERINFO_URL=https://provider.com/oauth2/userinfo
VULCAN_OIDC_JWKS_URI=https://provider.com/oauth2/jwks

# Optional logout endpoint
VULCAN_OIDC_END_SESSION_URL=https://provider.com/oauth2/logout
```

## Getting Help

### Enable Debug Logging
```bash
# Add to your environment
RAILS_LOG_LEVEL=debug

# Restart Vulcan and check logs
tail -f logs/production.log | grep -i oidc
```

### Collect Information
When seeking help, please provide:

1. **Configuration (redacted):**
   ```bash
   echo "Issuer: $VULCAN_OIDC_ISSUER_URL"
   echo "Discovery: $VULCAN_OIDC_DISCOVERY"
   echo "Provider: [Okta/Auth0/Keycloak/Azure AD]"
   ```

2. **Discovery document (if accessible):**
   ```bash
   curl https://your-domain.okta.com/.well-known/openid-configuration
   ```

3. **Relevant log entries:**
   ```bash
   grep "OIDC Discovery" logs/production.log | tail -20
   ```

### Community Support
- **GitHub Issues:** [https://github.com/mitre/vulcan/issues](https://github.com/mitre/vulcan/issues)
- **Documentation:** [https://vulcan.mitre.org/docs/](https://vulcan.mitre.org/docs/)

## Security Notes

- Always use HTTPS in production environments
- Regularly rotate client secrets
- Monitor logs for security-related messages
- Keep discovery cache TTL reasonable (default: 1 hour)
- Validate provider certificates in production