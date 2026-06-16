# Okta / OIDC Setup Guide for Vulcan

Vulcan ships complete OIDC support — login, logout with provider session
termination (RP-initiated logout), 2FA pass-through, and CSRF protection are
all built in. **You configure two things and nothing else: the application in
your identity provider, and Vulcan's environment variables.** You never write
or modify application code to enable SSO.

This guide covers Okta specifically. For other providers:
- **Login.gov** (PIV/CAC): See [Login.gov Setup Guide](login-gov.md)
- **Keycloak, Azure AD/Entra, Auth0**: Follow this guide, substituting your provider's admin console names
- **Multiple providers simultaneously**: Configure `VULCAN_OIDC_PROVIDERS` — see `ENVIRONMENT_VARIABLES.md`

## Quick Setup

### 1. Create the app in your Okta Admin Console

Applications → Create App Integration → **OIDC - OpenID Connect** →
**Web Application**, then set:

| Okta setting | Value |
|---|---|
| Application type | Web |
| Grant type: Authorization Code | ✅ ON (the only grant Vulcan uses) |
| Grant type: Refresh Token | OFF (Vulcan exchanges tokens once at login, then runs its own session) |
| Grant type: Client Credentials | OFF (no machine-to-machine calls) |
| Require DPoP | OFF (not supported by the OIDC client library) |
| Require consent | OFF (first-party app; Vulcan has its own AC-8 consent banner) |
| Allow wildcard in login URI | OFF (exact-match URIs only — OAuth 2.0 Security BCP) |
| Login initiated by | App Only |
| Initiate login URI | blank |
| Email Verification Experience → Callback URI | blank |
| Public keys / ID Token Encryption | none / None (Vulcan authenticates with the client secret; ID tokens are RS256-signed, not encrypted) |

### 2. Register the redirect URIs

One row per environment, in **both** lists. The paths are fixed by Vulcan;
only the host changes:

| Purpose | URI pattern | Example |
|---|---|---|
| **Sign-in redirect URI** | `<app_url>/users/auth/oidc/callback` | `https://vulcan.example.com/users/auth/oidc/callback` |
| **Sign-out redirect URI** | `<app_url>/users/signed_out` | `https://vulcan.example.com/users/signed_out` |

> **The sign-out entry is required.** When a user signs out, Vulcan ends the
> Okta session (RP-initiated logout) and Okta sends the browser back to
> `/users/signed_out`, which shows the "Signed out successfully."
> confirmation (AC-12(02)) on the sign-in page. Okta rejects the logout with
> `400 invalid_request` if this URI is not registered.

Save, then note the **Client ID** and **Client Secret**.

### 3. Set Vulcan's environment variables

| Variable | Required | Value |
|---|---|---|
| `VULCAN_ENABLE_OIDC` | ✅ | `true` |
| `VULCAN_APP_URL` | ✅ | Your Vulcan URL, e.g. `https://vulcan.example.com` (builds the sign-out landing URL — must match what you registered) |
| `VULCAN_OIDC_ISSUER_URL` | ✅ | `https://your-domain.okta.com/oauth2/default` |
| `VULCAN_OIDC_CLIENT_ID` | ✅ | from step 2 |
| `VULCAN_OIDC_CLIENT_SECRET` | ✅ | from step 2 |
| `VULCAN_OIDC_REDIRECT_URI` | ✅ | `<app_url>/users/auth/oidc/callback` — exactly as registered |
| `VULCAN_OIDC_PROVIDER_TITLE` | optional | Button label on the sign-in page, e.g. `Okta` |
| `VULCAN_OIDC_DISCOVERY` | optional | defaults `true` — endpoints come from the issuer's `/.well-known/openid-configuration` |
| `VULCAN_OIDC_PROMPT` | optional | `login` to force re-authentication (and 2FA) on every Vulcan sign-in |

With discovery on (the default), that's the complete list. The manual
endpoint variables (`VULCAN_OIDC_AUTHORIZATION_URL`, `VULCAN_OIDC_TOKEN_URL`,
`VULCAN_OIDC_USERINFO_URL`, `VULCAN_OIDC_JWKS_URI`, `VULCAN_OIDC_HOST`) are
needed only when `VULCAN_OIDC_DISCOVERY=false` — see
[ENVIRONMENT_VARIABLES.md](https://github.com/mitre/vulcan/blob/master/ENVIRONMENT_VARIABLES.md)
for the full reference.

### 4. Verify

| Check | Expected |
|---|---|
| Sign-in page shows the provider button | "Sign in with Okta" (your `VULCAN_OIDC_PROVIDER_TITLE`) |
| Clicking it → Okta login (with MFA per your Okta policy) → back in Vulcan | Landed signed in; a user record is created/linked by email |
| User menu → Sign Out | Brief hop through Okta, landing on the Vulcan sign-in page with a green **"Signed out successfully."** toast |
| Sign in again after sign-out | Okta prompts for credentials again (the provider session was really ended) |

## How sign-out works (built in — nothing to implement)

`DELETE /users/sign_out` ends the Vulcan session, then redirects to the
provider's `end_session_endpoint` (taken from OIDC discovery, with an Okta
fallback) carrying `id_token_hint` and
`post_logout_redirect_uri=<VULCAN_APP_URL>/users/signed_out`. The provider
ends its own session and returns the browser to `/users/signed_out`, a
public landing that sets the signed-out flash and forwards to the sign-in
page — that's where the confirmation toast renders. The only operator duty
in this flow is registering the sign-out redirect URI (step 2).

## Provider Quick-Reference

Okta is the worked example above; any OIDC-compliant provider uses the same
Vulcan env vars. Per provider, set `VULCAN_OIDC_ISSUER_URL`, register the
same two URIs (sign-in callback + sign-out landing), and note the quirks:

| Provider | Issuer URL | Register the app at | Sign-out behavior | Quirks |
|---|---|---|---|---|
| **Okta** | `https://<org>.okta.com/oauth2/default` | Admin Console → Applications → Create App Integration | Full provider logout (`end_session_endpoint`, with a built-in fallback for Okta orgs that omit it from discovery) | Register the sign-out landing or logout fails with `400 invalid_request` |
| **GitLab** (gitlab.com or self-hosted) | `https://gitlab.com` / `https://<your-gitlab>` | User, Group, or Admin area → **Applications** (scopes `openid profile email`) | **Local sign-out only** — GitLab publishes no `end_session_endpoint`, so Vulcan ends its own session and shows the toast; the GitLab session remains | Verified against gitlab.com discovery: `client_secret` auth supported, works with Vulcan as-is |
| **Keycloak** | `https://<host>/realms/<realm>` | Admin Console → **Clients** (confidential client) | Full provider logout (`/realms/<realm>/protocol/openid-connect/logout` via discovery) | Register the sign-out landing under the client's *Valid post logout redirect URIs* |
| **Azure AD / Entra ID** | `https://login.microsoftonline.com/<tenant-id>/v2.0` | Entra admin center → **App registrations** → Authentication (Web platform) | Full provider logout (`end_session_endpoint`); `post_logout_redirect_uri` must be among the app's registered redirect URIs | Use the tenant ID, not `common`, for a single-tenant app |
| **login.gov** | `https://secure.login.gov` (prod) / `https://idp.int.identitysandbox.gov` (sandbox) | Partner Portal (team → app) | Supports RP-initiated logout | ⚠️ **Not yet usable with Vulcan**: login.gov only accepts `private_key_jwt` or PKCE — Vulcan currently authenticates with a client secret (`client_auth_method: :secret`). Requires a Vulcan code change first. |

Providers without an `end_session_endpoint` are handled automatically:
Vulcan signs out locally and shows the confirmation toast instead of
redirecting to a guessed (broken) provider URL.

## Kubernetes ConfigMap Example

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vulcan-oidc-config
data:
  VULCAN_ENABLE_OIDC: "true"
  VULCAN_OIDC_PROVIDER_TITLE: "Okta"
  VULCAN_APP_URL: "https://your-vulcan-app.com"
  VULCAN_OIDC_ISSUER_URL: "https://your-domain.okta.com/oauth2/default"
  VULCAN_OIDC_CLIENT_ID: "your-okta-client-id"
  VULCAN_OIDC_REDIRECT_URI: "https://your-vulcan-app.com/users/auth/oidc/callback"
  # VULCAN_OIDC_CLIENT_SECRET belongs in a Secret, not a ConfigMap
```

## Troubleshooting

### Okta error 400 `invalid_request` on sign-out

> The 'post_logout_redirect_uri' parameter must be a Logout redirect URI in
> the client app settings

The sign-out landing isn't registered. Add
`<VULCAN_APP_URL>/users/signed_out` to the app's **Sign-out redirect URIs**
(step 2). Also confirm `VULCAN_APP_URL` matches the registered host exactly
— the URL is built from it.

### Users not prompted for 2FA on subsequent logins

1. Set `VULCAN_OIDC_PROMPT=login` to force re-authentication every time
2. Check Okta's session lifetime settings (shorter = more frequent MFA)
3. Ensure Okta sign-on policies require MFA for this application

### "Invalid Credentials" error

1. Verify `VULCAN_OIDC_CLIENT_ID` / `VULCAN_OIDC_CLIENT_SECRET`
2. Confirm the issuer URL includes the authorization server
   (`/oauth2/default` for Okta's default server)
3. Check the sign-in redirect URI matches exactly — protocol, host, path,
   no trailing slash

### Login redirect issues

1. The redirect URI must match the registered value exactly
2. `VULCAN_APP_URL` must include the protocol (`https://`)
3. Use HTTPS for everything except `http://localhost` development

### CSRF token errors

Vulcan ships `omniauth-rails_csrf_protection`; the sign-in button submits a
POST. If you see CSRF errors, check that a proxy isn't stripping cookies and
that `RAILS_FORCE_SSL` / cookie security settings match how the app is
actually served (TLS-terminating proxy vs plain HTTP).

## Best Practices

1. **Keep discovery on** (`VULCAN_OIDC_DISCOVERY=true`, the default) —
   endpoints stay correct when the provider rotates them.
2. **Exact-match redirect URIs, no wildcards** — one entry per environment
   per list (OAuth 2.0 Security Best Current Practice).
3. **Enable only the Authorization Code grant** — unused grants are attack
   surface.
4. **Test the full round trip after any provider change**: login with MFA,
   sign-out toast, and re-login prompting for credentials.
