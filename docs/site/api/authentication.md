# API Authentication

Vulcan supports two authentication methods: session-based (browser) and Personal Access Tokens (programmatic). All API endpoints require authentication.

## Session Authentication (Browser)

When logged in through the web interface, your session cookie authenticates API requests automatically. This is how the Vue frontend communicates with the Rails backend — no extra configuration needed.

CSRF protection is active for session-based requests. The Rails UJS adapter handles CSRF tokens automatically for forms and AJAX.

## Personal Access Tokens (Programmatic)

For scripts, CI/CD pipelines, and external tools, use Personal Access Tokens (PATs).

### Creating a Token

1. Sign in to Vulcan
2. Navigate to **User Settings > API Tokens**
3. Click **Create Token**
4. Enter a name, select scopes, set an expiration date
5. Enter your current password to confirm
6. **Copy the token immediately** — it is shown only once

### Using a Token

Include the token in the `Authorization` header with the `Token` scheme:

```bash
curl -H "Authorization: Token vulcan_abc123..." \
     -H "Accept: application/json" \
     https://vulcan.example.com/srgs
```

### Token Scopes

| Scope | Grants |
|-------|--------|
| `read` | GET requests to all endpoints |
| `write` | POST, PUT, PATCH, DELETE requests |
| `admin` | All operations (includes read + write) |

### IP Allowlist

Tokens can optionally restrict access by IP address or CIDR range. If configured, requests from non-allowed IPs receive `403 Forbidden`. An empty allowlist permits all IPs.

### Token Lifecycle

- **Maximum lifetime**: 365 days
- **Maximum per user**: 20 tokens
- **Idle revocation**: tokens unused for 90 days are auto-revoked via `rake api_tokens:revoke_idle`
- **Expired revocation**: tokens past expiry are cleaned up via `rake api_tokens:revoke_expired`
- **Prefix**: all tokens start with `vulcan_` for secret-scanner detection

### CSRF Bypass

Token-authenticated requests bypass CSRF verification. Session-authenticated requests remain CSRF-protected.

## Authentication Errors

### 401 Unauthorized

Missing, invalid, expired, or revoked token:

```json
{
  "error": "Invalid or expired API token"
}
```

### 403 Forbidden

Valid token but insufficient scope or IP not in allowlist:

```json
{
  "error": "Insufficient token scope for this action"
}
```

```json
{
  "error": "IP address not in token allowlist"
}
```

## Token Management Endpoints

Token management requires **session authentication** — you cannot manage tokens using a token.

### List your tokens

```
GET /personal_access_tokens
Accept: application/json
```

### Create a token

```
POST /personal_access_tokens
Content-Type: application/json

{
  "personal_access_token": {
    "name": "CI/CD Token",
    "scopes": ["read", "write"],
    "expires_at": "2027-01-01",
    "allowed_ips": ["10.0.0.0/8"],
    "current_password": "your_password"
  }
}
```

Returns the raw token in the response body (show-once):

```json
{
  "token": "vulcan_abc123...",
  "personal_access_token": {
    "id": 1,
    "name": "CI/CD Token",
    "scopes": ["read", "write"],
    "token_prefix": "vulcan_a",
    "expires_at": "2027-01-01",
    "last_used_at": null
  }
}
```

### Revoke a token

```
DELETE /personal_access_tokens/:id
```

### Admin: revoke any user's token

```
DELETE /personal_access_tokens/:id/admin_revoke
Content-Type: application/json

{
  "audit_comment": "Compromised credentials"
}
```

## Feature Toggle

PAT authentication can be disabled via `VULCAN_API_TOKENS_ENABLED=false`. When disabled, all PAT management endpoints return `404` and token headers are ignored (falls back to session auth).

## Best Practices

1. **Use the minimum scope needed** — `read` for monitoring, `write` for automation
2. **Set expiration dates** — avoid tokens that never expire
3. **Use IP allowlists** for production CI/CD runners with static IPs
4. **Rotate tokens regularly** — revoke and recreate periodically
5. **Never commit tokens** — use environment variables or secrets managers
6. **HTTPS only in production** — tokens are transmitted in headers
