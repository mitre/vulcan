# Vulcan API

Vulcan provides a REST API for programmatic access to projects, components, rules, STIGs, and SRGs. All endpoints return JSON and require authentication via Personal Access Tokens (PATs).

::: details Glossary
- **STIG** — Security Technical Implementation Guide. A DoD standard for securing systems.
- **SRG** — Security Requirements Guide. High-level DISA requirements that STIGs implement.
- **PAT** — Personal Access Token. A scoped, time-limited credential for API access.
- **InSpec** — A compliance-as-code framework for automated security testing.
- **XCCDF** — Extensible Configuration Checklist Description Format. The XML schema STIGs use.
:::

## Quick Start

### 1. Create a Personal Access Token

1. Sign in to your Vulcan instance
2. Go to **User Settings > API Tokens**
3. Click **Create Token**, select scopes, set an expiration
4. **Copy the token immediately** — it is shown only once

See [Authentication](./authentication) for full details on token scopes, IP allowlists, and lifecycle.

### 2. Try the API

Every endpoint page in this reference includes an interactive **"Try it out"**
playground. What it looks like depends on where you are reading this reference:

**Inside a running Vulcan instance** (the documentation served at `/docs`):

- Requests go to the instance you are signed in to — there is no server picker.
- **Reads (GET)** work immediately: your session authenticates them.
- **Writes (POST/PUT/PATCH/DELETE)** require a Personal Access Token, because Vulcan
  rejects session-authenticated writes that arrive without a CSRF token and the
  playground cannot supply one. Paste your PAT **including the `Token ` prefix**
  (e.g., `Token vulcan_abc123...`).

**On the published documentation site**:

1. Click **Select a server** and choose **Custom Server**
2. Enter your Vulcan instance URL (e.g., `https://vulcan.example.com`)
3. Paste your PAT **including the `Token ` prefix** in the Token field
4. Click **Try it out**

Your entries are saved in your browser's `localStorage` for subsequent requests. Clear storage on shared machines.

### 3. Or use cURL

```bash
curl -H "Authorization: Token vulcan_abc123..." \
     -H "Accept: application/json" \
     https://vulcan.example.com/projects
```

::: warning Note on auth scheme
Vulcan uses a custom `Token` authentication scheme (not the more common `Bearer`). Always use `Authorization: Token vulcan_...`, not `Authorization: Bearer vulcan_...`.
:::

## Endpoints

Browse the API by resource using the sidebar. Each endpoint page includes request parameters, response schemas, code samples, and an interactive playground.

- **[Projects](/api/tags/Projects)** — CRUD, export, import, member management
- **[Components](/api/tags/Components)** — CRUD, spreadsheet import, export, locking
- **[Rules](/api/tags/Rules)** — CRUD, revert, section locks, satisfaction relationships
- **[Reviews](/api/tags/Reviews)** — Comments, triage, adjudication, admin actions
- **[Reactions](/api/tags/Reactions)** — Thumbs up/down on comment reviews
- **[Memberships](/api/tags/Memberships)** — Project and component member management
- **[Benchmarks](/api/tags/Benchmarks)** — Upload and browse published STIGs and SRGs
- **[Users](/api/tags/Users)** — User management and admin operations
- **[Search](/api/tags/Search)** — Global search across all resources
- **[Auth](/api/tags/Auth)** — Login, logout, session identity
- **[System](/api/tags/System)** — Version, settings, navigation, consent
- **[Personal Access Tokens](</api/tags/Personal Access Tokens>)** — Token CRUD and admin revocation

## Response Format

**Read endpoints** (GET) return the resource directly:

```json
{
  "id": 1,
  "name": "Container Platform",
  "memberships_count": 14
}
```

**Mutation endpoints** (POST, PUT, PATCH, DELETE) return a toast envelope:

```json
{
  "toast": {
    "title": "Success",
    "message": ["Project created successfully."],
    "variant": "success"
  }
}
```

**Error responses**:

```json
{
  "error": "Not found"
}
```

## OpenAPI Specification

The complete OpenAPI 3.2 specification is available for download:

- **JSON**: [openapi.json](/api/openapi.json)
- **YAML**: [openapi.yaml](/api/openapi.yaml)

Every Vulcan instance also serves both formats at `/openapi.json` and `/openapi.yaml`.

Use these with tools like [Postman](https://www.postman.com/), [Bruno](https://www.usebruno.com/), or any OpenAPI-compatible client.

## Rate Limiting

Rate limiting is enforced via [rack-attack](https://github.com/rack/rack-attack):

| Throttle | Limit | Scope |
|----------|-------|-------|
| Login attempts | 5/min | per IP |
| Login attempts | 5/min | per email |
| File uploads | 10/min | per IP |
| Comment creation | 10/min, 100/hour | per user |
| Reaction POST | 60/min | per user |
| API token requests | 300/min | per IP |

When rate-limited, the API returns `429 Too Many Requests` with a toast body:

```json
{
  "toast": {
    "title": "Rate limited",
    "message": ["Too many requests. Please try again later."],
    "variant": "danger"
  }
}
```

---

::: tip Credits
This API reference is auto-generated from the OpenAPI specification using [vitepress-openapi](https://github.com/enzonotario/vitepress-openapi).
:::
