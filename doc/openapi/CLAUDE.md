# OpenAPI Multi-File Specification

This directory contains the multi-file source for Vulcan's OpenAPI 3.2 specification.

## Structure

```
doc/openapi/
  openapi.yaml              # Root file — tags, servers, security, path $refs
  paths/                    # One file per endpoint (path + all HTTP methods)
  components/
    schemas/                # One file per data type
    parameters/             # Reusable path/query parameters
    responses/              # Reusable error responses
```

`doc/openapi.yaml` (one level up) is the **generated bundle** — never edit it directly.

## OpenAPI 3.2 Features We Use

We target OpenAPI 3.2.0 specifically. These 3.2 features reduce duplication:

- **`4XX` / `5XX` wildcard status codes** — define one catch-all error response instead of listing 400, 401, 403, 404 separately. Use `4XX` on every path for the generic ErrorResponse.
- **`components/pathItems`** — reusable path item objects. When multiple endpoints share the same parameter set (e.g., all `/users/{userId}/*` member routes), define a shared path item with the parameters and `$ref` it.
- **Relative `$ref` in multi-file** — 3.2 clarified resolution rules for relative URIs across files. Our `$ref: ../components/schemas/Foo.yaml` paths follow this.
- **JSON Schema alignment** — 3.2 uses full JSON Schema 2020-12. Use `type: [string, 'null']` for nullable fields (not the deprecated `nullable: true` from 3.0).

### NOT using (yet)

- `$self` — explicit base URI. Not needed since all our references are relative file paths.
- `components/mediaTypes` — reusable media type objects. Could DRY up the toast JSON shape but Redocly tooling support is still emerging.
- `additionalOperations` — for non-standard HTTP methods. We only use standard methods.

## Workflow

```bash
# Edit individual files in this directory, then:
yarn openapi:bundle       # Regenerate doc/openapi.yaml from multi-file source
yarn openapi:lint         # Validate the multi-file source (catches broken $refs)
yarn openapi:docs         # Generate docs/data/openapi.json for VitePress API reference
```

Always run bundle + lint after changes. Run `openapi:docs` when updating the public API reference site. Contract tests in `spec/contracts/` validate responses against the bundled output.

## Adding a New Endpoint

1. Create `paths/<path_name>.yaml` using the naming convention below
2. Add a `$ref` entry in `openapi.yaml` under `paths:`
3. Create any new schemas in `components/schemas/`
4. Run `yarn openapi:bundle && yarn openapi:lint`
5. Add contract tests in `spec/contracts/`

## File Naming Convention

Path files use underscores for `/` and `_{param}` for path parameters:

| Route | Filename |
|-------|----------|
| `/users` | `users.yaml` |
| `/users/{userId}` | `users_{userId}.yaml` |
| `/users/{userId}/lock` | `users_{userId}_lock.yaml` |
| `/api/version` | `api_version.yaml` |
| `/components/{componentId}/export/{type}` | `components_{componentId}_export_{type}.yaml` |

## Documentation Standards

Every path and schema file MUST follow these inline documentation standards. These are derived from the OpenAPI 3.1 specification and Redocly's recommended rules.

### Operations (in path files)

Every operation MUST have:

- **`summary`**: 20-60 characters, no trailing period. What the endpoint does.
- **`description`**: 30+ characters, ends with a period. Why/when to use it, auth requirements, side effects.
- **`operationId`**: camelCase, unique across the entire spec.
- **`tags`**: Exactly one tag from the root tags list.
- **Response `description`**: Every status code gets a description.
- **Response `examples`**: At least one named example per success response.
- **Error responses**: Document all known error status codes with descriptions.

```yaml
post:
  operationId: lockUser
  tags:
    - Users
  summary: Lock a user account (admin only)
  description: >-
    Prevents the user from signing in. Requires admin role.
    Returns 422 if the admin attempts to lock their own account.
    Creates an audit trail entry recording who locked the account.
  responses:
    '200':
      description: Account locked successfully
      content:
        application/json:
          schema:
            $ref: ../components/schemas/UserToastResponse.yaml
          examples:
            locked:
              summary: Successful lock
              value:
                toast:
                  title: Account locked.
                  message:
                    - Account target@example.com locked.
                  variant: success
                user:
                  id: 42
                  name: Target User
                  email: target@example.com
                  admin: false
                  locked_at: "2026-05-28T15:00:00Z"
    '422':
      description: Cannot lock own account
```

### Parameters

Every parameter MUST have:

- **`description`**: What the parameter is and valid values.
- **`example`** or **`examples`**: A realistic sample value.

```yaml
parameters:
  - name: userId
    in: path
    required: true
    description: Numeric ID of the target user.
    schema:
      type: integer
    example: 42
```

### Schemas (in components/schemas/)

Every schema MUST have:

- **`description`** on the schema itself: What this data type represents.
- **`required`** array: List all required properties.
- **`description`** on each property: What the field means.
- **`example`** on leaf properties: A realistic sample value.
- **`format`** where applicable: `email`, `date-time`, `uri`, `int64`, etc.

```yaml
description: Summary of a user account for admin management views.
type: object
required:
  - id
  - email
  - admin
properties:
  id:
    type: integer
    description: Unique user identifier.
    example: 42
  name:
    type:
      - string
      - 'null'
    description: Display name. Null for users who haven't set one.
    example: Jane Doe
  email:
    type: string
    format: email
    description: Login email address.
    example: jane@example.com
  admin:
    type: boolean
    description: Whether the user has admin privileges.
    example: false
  locked_at:
    type:
      - string
      - 'null'
    format: date-time
    description: Timestamp when the account was locked. Null if not locked.
    example: null
```

### Reusable Components

- Extract any schema used by 2+ paths into `components/schemas/`.
- Extract any parameter used by 2+ paths into `components/parameters/`.
- Use `$ref` with relative paths: `$ref: ../components/schemas/ToastResponse.yaml`
- The `ToastResponse` schema is the canonical mutation response — use it for all mutation endpoints.

### What NOT to Document

- Internal implementation details (database column names, Ruby class names)
- Authentication flow mechanics (covered in the root `securitySchemes`)
- Rate limiting (not implemented yet — add when it ships)

## Redocly Lint Rules

`redocly.yaml` at the repo root configures lint rules. Current rules:

- `no-unresolved-refs: error` — broken `$ref` links fail the build
- `no-unused-components: warn` — unused schemas get flagged

To add stricter documentation rules later:

```yaml
rules:
  operation-description: warn
  parameter-description: warn
  tag-description: warn
  no-unresolved-refs: error
  no-unused-components: warn
```

## Contract Tests — MANDATORY

`spec/contracts/` validates real API responses against this spec using the `openapi_first` gem. The test support file at `spec/support/openapi_contract.rb` registers `doc/openapi.yaml` (the bundled output) as the `:vulcan` definition.

**Every endpoint in the spec MUST have a contract test.** No exceptions. A path without a contract test is a path where the schema and actual response can silently diverge (see v2-05f.44 — Devise blacklist stripped fields that the schema claimed were present, undetected for weeks).

### When adding a new endpoint:

1. **Write the contract test first** (TDD) — it will fail because the path doesn't exist in the spec
2. Add the path YAML file + any new schemas
3. Bundle: `yarn openapi:bundle`
4. The contract test should now pass
5. Verify: `yarn openapi:lint && DATABASE_PORT=5433 bundle exec rspec spec/contracts/`

### When modifying an existing endpoint:

1. Run the existing contract test — it should pass before your change
2. Make the controller change
3. If the response shape changed, update the schema YAML and re-bundle
4. Run the contract test again — it must pass after your change
5. If the test doesn't catch your change, the test is too weak — strengthen it

### When modifying an API response shape:

Updating the controller render AND the OpenAPI schema is ONE task, not two. A PR that changes a response shape without updating the spec is incomplete. The contract test enforces this — if you change the response but not the schema, the test fails.

### Contract test pattern:

```ruby
describe 'PATCH /reviews/:id/reopen' do
  it 'matches ToastResponse schema' do
    patch "/reviews/#{review.id}/reopen", headers: json_headers, as: :json
    expect(response).to have_http_status(:ok)
    validate_response!(request, response)

    body = response.parsed_body
    expect(body.dig('toast', 'variant')).to eq('success')
  end
end
```

### Coverage target:

Every path in `doc/openapi/openapi.yaml` has a corresponding contract test. Run `grep -c "^  /" doc/openapi/openapi.yaml` to count paths, `grep -c "describe '" spec/contracts/*.rb` to count tests. These numbers should converge.

## Schemathesis API Testing

Two testing modes validate the API against the OpenAPI spec:

### Quick smoke test (GET-only, against dev server)
```bash
rake openapi:smoke
```
Runs Schemathesis against `localhost:3000` with only GET endpoints. No side effects on your dev database. Uses PAT auth. Good for quick validation after spec/controller changes.

### Full CRUD test (disposable Docker environment)
```bash
rake openapi:test          # Or: bin/schemathesis-full
bin/schemathesis-full 50   # Override max-examples per endpoint
```
Spins up a disposable Docker environment (app + ephemeral PostgreSQL with no volumes), seeds data, runs Schemathesis with ALL HTTP methods against all endpoints, then tears everything down. Dev database is untouched. JUnit report at `tmp/schemathesis-full.xml`.

### Authentication
Both modes create a PAT (`Authorization: Token vulcan_xxx`) automatically. The smoke mode cleans up the token and unlocks the admin account on exit.

### What Schemathesis checks
- `not_a_server_error` — no 500s
- `status_code_conformance` — response codes match spec
- `content_type_conformance` — Content-Type matches spec
- `response_schema_conformance` — response body matches schema

### Excluded endpoints
- File uploads (XML/ZIP/spreadsheet — need multipart binary)
- PAT management (session-auth only by design)
- Deprecated operations

## API Completeness Rule

The OpenAPI spec is the **design document** for Vulcan's complete REST API — not just documentation of what currently returns JSON. If a route exists in `config/routes.rb` and serves data, it belongs in the spec.

When you find a route that returns JSON but has no OpenAPI path:
1. That's an API gap — card it
2. Add the path YAML + schema + contract test
3. The spec defines what the API SHOULD be; the code implements it
