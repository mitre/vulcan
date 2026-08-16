# API Errors

Every JSON error the Vulcan API returns is an [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) problem details document, served as `application/problem+json`. The `type` member is a URI pointing at a section of this page; `title` names the error class, `status` repeats the HTTP status code, and `detail` explains the specific occurrence. Some errors carry extension members noted below.

```json
{
  "type": "/docs/api/errors#not_authenticated",
  "title": "Not authenticated",
  "status": 401,
  "detail": "This request included no API token and no valid signed-in session. ...",
  "how_to_authenticate": { "session": "...", "token": "..." }
}
```

Validation and domain feedback (the toast contract used by the web UI) is a separate channel and never flows through these documents.

## Authentication errors (401)

### not_authenticated

The request included no API token and no valid signed-in session. If you were signed in, the session may have timed out, been signed out, or ended because the account signed in from another location. The `how_to_authenticate` extension lists both credential paths: sign in through the web UI for a session cookie, or send a personal access token as `Authorization: Token <your-token>`.

### invalid_token

The `Authorization` header carried a token that does not match any active personal access token — it may be revoked, expired, or mistyped. Create a new token from your profile page (or `POST /personal_access_tokens`) and retry. Carries `how_to_authenticate`.

### invalid_credentials

A sign-in attempt supplied an incorrect email or password.

### session_superseded

You were signed out because this account signed in from another location. Only one active session per account is allowed at a time. Carries `how_to_authenticate`.

### session_timed_out

Your session timed out after a period of inactivity. Sign in again to continue. Carries `how_to_authenticate`.

## Permission errors (403)

### permission_denied

The authenticated identity does not hold the role this action requires. When the denial is project-scoped, the `admins` extension lists the project administrators (name and email) who can grant access, and a `toast` extension carries the legacy UI message.

### session_authentication_required

Token management requires a signed-in browser session; API tokens cannot create or revoke tokens.

### ip_not_allowed

The request came from an IP address outside this token's allowlist.

### insufficient_token_scope

The request requires a scope (named in `detail`) that the presented token does not grant. Create a token with the needed scope.

## Validation errors (422)

### incorrect_password

Creating or managing API tokens re-verifies your identity, and the current password provided does not match. The caller is already signed in — the re-verification challenge failed — so the status is 422, not 401.

## Request errors (400 and 404)

### not_found

The requested resource could not be found — or it exists but is not visible to the authenticated identity, which answers identically.

### parameter_missing

A required request parameter was absent; `detail` names it.

### page_out_of_range

The requested page number falls outside the collection's page range; `detail` states the valid range.
