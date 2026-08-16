# Login.gov Setup Guide

Login.gov is the U.S. government's shared sign-in service. It supports
PIV/CAC authentication — users select their credential type on the
Login.gov side, and Vulcan receives the verified identity. No
PIV-specific code is needed in Vulcan.

## Prerequisites

- A Login.gov sandbox team at [dashboard.int.identitysandbox.gov](https://dashboard.int.identitysandbox.gov)
- An RSA-2048 keypair (login.gov uses `private_key_jwt`, not a client secret)
- Vulcan running with `VULCAN_ENABLE_OIDC=true` and the multi-provider registry

## 1. Generate the Keypair

```bash
# Generate a 2048-bit RSA private key
openssl genrsa -out login_gov_private.pem 2048

# Extract the public certificate (self-signed, login.gov only needs the public key)
openssl req -new -x509 -key login_gov_private.pem \
  -out login_gov_public.crt -days 365 \
  -subj "/CN=vulcan-dev-login-gov"
```

Store the private key securely:
- **Local dev:** `~/.vulcan/login_gov_dev_private.pem` (0600 permissions, NEVER commit)
- **Heroku/cloud:** Set as an inline PEM env var (`VULCAN_OIDC_LOGIN_GOV_PRIVATE_KEY`)

## 2. Register in the Login.gov Sandbox Portal

1. Go to [dashboard.int.identitysandbox.gov](https://dashboard.int.identitysandbox.gov)
2. Create a new app configuration:

| Setting | Value |
|---|---|
| App name | `MITRE-VULCAN-DEV` (or your org name) |
| Friendly name | `Vulcan (Your Org) — Dev` |
| Identity Protocol | `openid_connect_private_key_jwt` |
| Level of Service | Authentication only (no verified attributes) |
| Default AAL | MFA required, remember device disallowed (AAL2) |
| Issuer | `urn:gov:gsa:openidconnect.profiles:sp:sso:your-org:vulcan-dev` |

3. Upload the public certificate (`login_gov_public.crt`)
4. Add redirect URIs:

```
http://localhost:3000/users/auth/login_gov/callback
http://localhost:3000/users/signed_out
```

5. Set the attribute bundle to: `email, x509_presented, x509_subject`

## 3. Configure Vulcan Environment Variables

### Local Development (`.env`)

```bash
# Enable the multi-provider registry
VULCAN_OIDC_PROVIDERS=okta,login_gov

# Login.gov provider
VULCAN_OIDC_LOGIN_GOV_ISSUER_URL=https://idp.int.identitysandbox.gov/
VULCAN_OIDC_LOGIN_GOV_CLIENT_ID=urn:gov:gsa:openidconnect.profiles:sp:sso:your-org:vulcan-dev
VULCAN_OIDC_LOGIN_GOV_CLIENT_AUTH_METHOD=jwt_bearer
VULCAN_OIDC_LOGIN_GOV_PRIVATE_KEY_PATH=/path/to/login_gov_dev_private.pem
VULCAN_OIDC_LOGIN_GOV_ACR_VALUES=urn:acr.login.gov:auth-only
VULCAN_OIDC_LOGIN_GOV_REDIRECT_URI=http://localhost:3000/users/auth/login_gov/callback
VULCAN_OIDC_LOGIN_GOV_TITLE=Login.gov
```

### Heroku / Cloud (inline PEM)

Heroku has no persistent filesystem — use the inline PEM env var instead of a file path:

```bash
heroku config:set \
  VULCAN_OIDC_LOGIN_GOV_PRIVATE_KEY="$(cat login_gov_private.pem)" \
  -a your-app-name
```

Do NOT set `_PRIVATE_KEY_PATH` on Heroku — use `_PRIVATE_KEY` (inline).

## 4. Test the Integration

### Create a sandbox test account

Sandbox test accounts are self-service: go to
[idp.int.identitysandbox.gov](https://idp.int.identitysandbox.gov) and sign up
with any email address (the sandbox delivers its confirmation codes on-screen —
no real inbox required). Set up any MFA method; the authenticator-app and
backup-code options work fully inside the sandbox.

### Walk the sign-in flow

1. Restart Vulcan after setting the environment variables — providers register
   at boot, so a running server will not pick up registry changes.
2. Open the sign-in page. A **Login.gov** tab (the `_TITLE` value) should
   appear alongside your other providers. If it doesn't, the registry didn't
   load — check `VULCAN_OIDC_PROVIDERS` and the boot log.
3. Click **Sign in with Login.gov** → you land on the sandbox IdP → authenticate
   with the test account (password + MFA, or PIV/CAC if your workstation has
   one) → consent to sharing the attribute bundle.
4. You return to Vulcan signed in. First sign-in creates the account (or links
   to an existing one when verified auto-linking applies).

### Verify the result

- Your profile page lists the Login.gov identity under linked accounts
  (provider, email, last used).
- Sign out via the avatar menu: Vulcan performs RP-initiated logout at
  Login.gov and must land back on `/users/signed_out` — this round trip is
  exactly why that second URI is registered in the portal.

### Troubleshooting

| Symptom | Cause |
|---|---|
| "Issuer mismatch" on callback | Missing trailing slash on `_ISSUER_URL` (see below) |
| `400 invalid_request` at sign-out | `/users/signed_out` not registered as a redirect URI in the portal |
| Client-assertion / JWT signature error at token exchange | Private key doesn't match the certificate uploaded to the portal (regenerated key, wrong file, or stale cert) |
| `redirect_uri` mismatch at the IdP | Callback URI in the portal doesn't byte-match `<app_url>/users/auth/login_gov/callback` (scheme, host, and port all count) |
| No Login.gov button on the sign-in page | Registry not loaded — `VULCAN_OIDC_PROVIDERS` unset/typo, or the server wasn't restarted |

## Important Notes

### Issuer URL Trailing Slash

Login.gov's discovery document returns the issuer as `https://idp.int.identitysandbox.gov/`
**with a trailing slash**. The OIDC strategy does a strict string comparison. Omitting the
trailing slash causes an "Issuer mismatch" error on callback.

### Provider Registry Key

The registry key `login_gov` becomes the callback path segment:
`/users/auth/login_gov/callback`. This URI must be registered in the Login.gov
portal. When migrating from a legacy single-provider setup (`oidc`), you also need to:

1. Add the new callback URI to the Login.gov portal
2. Run `rails vulcan:auth:rename_provider[oidc,login_gov]` to update existing users

### ACR Values

| Value | Meaning |
|---|---|
| `urn:acr.login.gov:auth-only` | Authentication only, no identity proofing (IAL1) |
| `urn:acr.login.gov:verified` | Identity-proofed (IAL2) — requires Level of Service upgrade |
| `urn:acr.login.gov:verified-facial-match-preferred` | IAL2 with facial match preferred |

Vulcan uses `auth-only` by default. Identity proofing requires a signed IAA
agreement with Login.gov and a Level of Service upgrade in the portal.

### Sandbox vs Production

| | Sandbox | Production |
|---|---|---|
| Portal | dashboard.int.identitysandbox.gov | dashboard.login.gov |
| IdP | idp.int.identitysandbox.gov | secure.login.gov |
| Test accounts | Create at idp.int.identitysandbox.gov | Real users only |
| IAA required | No | Yes |

### PIV/CAC

Login.gov handles PIV/CAC authentication upstream. When a user clicks
"Sign in with Login.gov," they choose their credential type (password + MFA,
PIV/CAC, etc.) on the Login.gov side. Vulcan receives the authenticated
identity regardless of the credential used. No PIV-specific code is needed.
