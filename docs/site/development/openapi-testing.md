# OpenAPI Testing

Vulcan validates its API against the OpenAPI 3.2 specification using two complementary approaches: contract tests (RSpec) and live API fuzzing (Schemathesis).

## Contract Tests (RSpec)

Specs in `spec/contracts/` validate real API responses against the bundled OpenAPI schema using the `openapi_first` gem.

```bash
bundle exec rspec spec/contracts/
```

Each test makes a real HTTP request, then validates the response status, content-type, and body against the schema defined in `doc/openapi.yaml`.

```ruby
describe 'GET /stigs/:id (JSON)' do
  it 'returns StigDetailResponse' do
    get "/stigs/#{stig.id}", headers: json_headers
    expect(response).to have_http_status(:ok)
    validate_response!(request, response)
  end
end
```

`validate_response!` is a shared helper (`spec/support/openapi_contract.rb`) that loads the bundled spec and validates against it.

### When to write contract tests

Every OpenAPI path MUST have a contract test. A path without a test means the schema and response can silently diverge. When modifying a controller:

1. Run the existing contract test — it should pass before your change
2. Make the controller change
3. If the response shape changed, update the YAML schema and re-bundle
4. Run the contract test — it must pass after

## Schemathesis (Live API Fuzzing)

[Schemathesis](https://github.com/schemathesis/schemathesis) is a property-based API testing tool that generates requests from the OpenAPI spec and validates responses. It catches issues contract tests miss: unhandled inputs, 500 errors, schema drift.

### Smoke Test (GET-only, against dev server)

```bash
bundle exec rake openapi:smoke
```

Runs Schemathesis against `localhost:3000` with only GET endpoints. No side effects on your dev database. Creates a temporary PAT for authentication and cleans it up on exit.

- **Phase:** examples only (uses parameter examples from the spec)
- **Checks:** `not_a_server_error`, `status_code_conformance`, `content_type_conformance`, `response_schema_conformance`
- **Output:** JUnit XML at `tmp/schemathesis-smoke.xml`

### Full CRUD Test (disposable Docker)

```bash
bundle exec rake openapi:test
# Or directly:
bin/schemathesis-full
bin/schemathesis-full --max-examples 50    # More thorough
```

Spins up an ephemeral Docker environment (app + PostgreSQL, no volumes), seeds data, creates a PAT, runs all HTTP methods against all endpoints, then tears everything down. Dev database is untouched.

### Excluded Endpoints

The following are excluded from Schemathesis testing:

| Pattern | Reason |
|---------|--------|
| `/upload`, `/import_backup`, `/create_from_backup` | Multipart file upload — Schemathesis can't generate valid files |
| `/detect_srg`, `/preview_spreadsheet`, `/apply_spreadsheet` | Spreadsheet processing endpoints |
| `/personal_access_tokens` | Session-auth-only by design |
| `/components/history` | Requires `project_id` param that Schemathesis can't infer |
| Export endpoints (`/export/`, `/bulk_export/`) | Binary download — returns file, not JSON |

### Interpreting Results

- **0 failures** = spec and API are consistent
- **"Missing valid test data" warning** = Schemathesis used random IDs that don't exist (404s). Expected for parameterized endpoints.
- **"Missing authentication" warning** = token didn't reach an endpoint. Usually a scope issue.

## OpenAPI Spec Management

The spec is multi-file (managed via Redocly CLI) with the bundled output at `doc/openapi.yaml`.

```bash
yarn openapi:bundle    # Regenerate doc/openapi.yaml from doc/openapi/ source
yarn openapi:lint      # Validate the multi-file source
```

Always run both after spec changes. See `doc/openapi/CLAUDE.md` for full spec authoring standards.

## File Map

```
doc/openapi/                    # Multi-file source (paths/, components/schemas/)
doc/openapi.yaml                # Bundled output (generated, do not edit)
lib/tasks/openapi.rake          # Smoke + CRUD rake tasks
bin/schemathesis-full            # Full CRUD orchestration script
docker-compose.schemathesis.yml # Disposable Docker environment
spec/contracts/                 # RSpec contract tests
spec/support/openapi_contract.rb # Shared validation helper
```
