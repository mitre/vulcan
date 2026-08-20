# OpenAPI Spec Redo — Complete Corrected Plan

> **Context:** Session 15 created 50+ OpenAPI spec files that are fundamentally wrong.
> 117 audit findings (44 critical, 63 major, 10 minor). Every major endpoint
> references the wrong schema. Schemas were fabricated without reading Blueprints.
> Contract tests are too loose to catch any of it. This plan fixes everything.

## Verification standard — EVERY schema, EVERY path, EVERY test

Nothing is "done" until:
1. The Blueprint source file has been READ (not guessed)
2. The schema matches the Blueprint output EXACTLY (every field, correct types, correct nesting)
3. The path file references the CORRECT schema for the controller's render call
4. A contract test hits the REAL endpoint with REAL data
5. The contract test asserts SPECIFIC FIELDS by name and value type
6. Fields that should NOT be present are asserted absent (e.g., user_id on reviews)
7. `additionalProperties: false` on schemas where all fields are documented
8. Live tested via Playwright or curl against the running dev server
9. `yarn openapi:bundle && yarn openapi:lint` passes
10. `DATABASE_PORT=5435 bundle exec rspec spec/contracts/` passes

## Phase 1: Core Schema Rewrites (23 schema creates/rewrites)

### Method for EACH schema:
```
1. Read app/blueprints/{name}_blueprint.rb — get EXACT field list per view
2. Read the controller action — confirm which Blueprint view is rendered
3. Hit the real endpoint: DATABASE_PORT=5435 bundle exec rails runner '...'
4. Compare real response fields against schema
5. Write/rewrite schema to match EXACTLY
6. No field in schema that isn't in Blueprint output
7. No field in Blueprint output that isn't in schema
```

### Schemas to rewrite (8):
| Schema | Finding | Fix |
|--------|---------|-----|
| ReviewSummary.yaml | C1: fabricated user_id, missing 15 fields | Remove user_id (SECURITY). Add triage_status, triage_set_at, adjudicated_at, section, duplicate_of_review_id, triage_set_by_id, name, author_name, triager/adjudicator/commenter display fields, reactions {up, down, mine} |
| RuleSummary.yaml | C2: 6 fields vs 35+ actual | Add version, rule_severity, rule_weight, review_requestor_id, changes_requested, comment_summary, displayed_name, nist_control_family. Keep as default-view only. |
| ComponentSummary.yaml | C3: fabricated project_id/title/description | Remove fabricated fields. Add based_on_title, based_on_version, severity_counts, pending_comment_count. Match DEFAULT view only. |
| ProjectSummary.yaml | C4: fabricated components_count | Remove components_count. Add memberships_count, admin_name, admin_email. |
| CommentRow.yaml | C16: fabricated author fields, missing 13+ fields | Rewrite from paginated_comments controller output. Add all triage attribution, addressed_by, reactions.mine. |
| PaginatedComments.yaml | C15: requires nonexistent fields | Remove status_counts from required. Fix 'total' description. |
| AuditEntry.yaml | M27: wrong field names | Remove user_id. Add name, audited_name, comment. Fix audited_changes to array. |
| BenchmarkSummary.yaml | C23: release_date vs benchmark_date | Split into SrgSummary.yaml + StigSummary.yaml. |
| AdminCreateResponse.yaml | M32: mixed toast types | Split success (toast=string) vs error (toast=object). |

### New schemas to create (14):
| Schema | Blueprint source | Fields |
|--------|-----------------|--------|
| RuleEditorResponse.yaml | RuleBlueprint :editor | 35+ fields with nested checks, descriptions, satisfactions |
| RulePickerResponse.yaml | RuleBlueprint :picker | 13 fields (id, rule_id, title, displayed_name, ...) |
| ComponentEditorResponse.yaml | ComponentBlueprint :editor | 30+ fields with nested rules, memberships, histories, reviews |
| ComponentIndexResponse.yaml | jbuilder index output | 9 fields (id, name, prefix, version, release, updated_at, severity_counts, ...) |
| ProjectShowResponse.yaml | ProjectBlueprint :show | 17+ fields with nested components, memberships, histories |
| RelatedComponentSummary.yaml | Controller inline hash | 7 fields (id, name, version, prefix, release, project_id, project_name) |
| ReviewResponseRow.yaml | Controller hand-built hash | (id, responding_to_review_id, section, comment, created_at, commenter_display_name, reactions) |
| SrgSummary.yaml | SrgBlueprint :index | (id, srg_id, name, title, version, release_date, severity_counts) |
| SrgDetailResponse.yaml | SrgBlueprint :show | Full SRG with nested srg_rules array |
| StigSummary.yaml | StigBlueprint :index | (id, stig_id, name, title, version, benchmark_date, severity_counts) |
| StigDetailResponse.yaml | StigBlueprint :show | Full STIG with nested stig_rules array |
| RuleToastResponse.yaml | Composite | {rule: RuleEditorResponse, toast: ToastResponse} |
| TriageResponse.yaml | Composite | {review: ReviewSummary, response_review: ReviewSummary|null} |
| AdminDestroyResponse.yaml | Controller | {review: null, destroyed_id: integer} |
| RuleCreateResponse.yaml | Composite | {toast: ToastResponse, data: RuleEditorResponse} |
| ImportBackupResponse.yaml | Controller | {toast: string, summary: object, warnings: array} |

## Phase 2: Path File $ref Fixes (30 path files)

Every path file must reference the schema that matches what the controller ACTUALLY renders.

30 path files listed in audit findings C5-C25. Each one: read controller → confirm Blueprint view → change $ref.

## Phase 3: Request Body Fixes (8 path files)

Fix fabricated parameter names and wrong nesting:
- lock_sections: {sections, locked, comment} not {locked_fields}
- reactions: flat {kind} not {reaction: {kind}}
- move_to_rule: rule_id not target_rule_id
- triage: flat params not nested under review
- admin_restore: add required audit_comment
- bulk_section_locks: flat {sections, locked, comment} not {rule: {locked_fields}}
- section_locks: add requestBody (currently missing entirely)
- adjudicate: add optional resolution_comment

## Phase 4: Query Params + Enum Fixes (6 path files)

- users/:id/comments: add project_id param
- components/:id/comments: add resolved, commentable_type params
- projects/:id/export/:type: add excel, disposition_csv to enum
- stigs/:id/export/:type: remove fabricated inspec from enum
- users/:id DELETE: add 422 response for last-admin guard
- rules/:id/related_rules: fix parents and rules schemas

## Phase 5: Contract Tests — CORRECTED

### The standard for EVERY contract test:

```ruby
describe 'GET /components/:id (JSON)' do
  it 'matches ComponentEditorResponse and includes all nested objects' do
    get "/components/#{component.id}", headers: { 'Accept' => 'application/json' }
    expect(response).to have_http_status(:ok)
    
    # Schema validation — catches structural drift
    validate_response!(request, response)
    
    body = response.parsed_body
    
    # SPECIFIC field assertions — catches missing fields
    expect(body['id']).to eq(component.id)
    expect(body['name']).to eq(component.name)
    expect(body['prefix']).to eq(component.prefix)
    expect(body).to have_key('rules')
    expect(body['rules']).to be_an(Array)
    expect(body).to have_key('memberships')
    expect(body).to have_key('histories')
    expect(body).to have_key('status_counts')
    expect(body).to have_key('severity_counts')
    expect(body).to have_key('comment_phase')
    
    # ABSENT field assertions — catches security leaks
    # (none for this endpoint, but reviews must NOT have user_id)
    
    # NESTED object assertions — catches unwired schemas
    if body['rules'].any?
      rule = body['rules'].first
      expect(rule).to have_key('rule_id')
      expect(rule).to have_key('fixtext')
      expect(rule).to have_key('checks_attributes')
      expect(rule).to have_key('disa_rule_descriptions_attributes')
    end
  end
end

describe 'PATCH /reviews/:id/triage' do
  it 'matches TriageResponse with review + optional response_review' do
    patch "/reviews/#{review.id}/triage",
          params: { triage_status: 'concur' },
          headers: json_headers, as: :json
    expect(response).to have_http_status(:ok)
    validate_response!(request, response)
    
    body = response.parsed_body
    
    # Multi-key response — BOTH keys must be present
    expect(body).to have_key('review')
    expect(body['review']['id']).to eq(review.id)
    expect(body['review']['triage_status']).to eq('concur')
    
    # Security: user_id must NOT be in the response
    expect(body['review']).not_to have_key('user_id')
    
    # Attribution fields MUST be present
    expect(body['review']).to have_key('triager_display_name')
    expect(body['review']).to have_key('reactions')
    expect(body['review']['reactions']).to have_key('mine')
  end
end
```

### What makes a test CATCH bugs (vs pass with garbage):

1. **validate_response!** — openapi_first structural check. Catches extra/missing top-level keys IF schema uses `additionalProperties: false`.
2. **Specific field assertions by name** — `expect(body['triage_status']).to eq('concur')` not `expect(body).to be_present`. Catches missing fields.
3. **Absent field assertions** — `expect(body['review']).not_to have_key('user_id')`. Catches security leaks.
4. **Nested object field assertions** — `expect(rule).to have_key('checks_attributes')`. Catches unwired nested schemas.
5. **Value type assertions** — `expect(body['rules']).to be_an(Array)`. Catches shape mismatches.
6. **Pin to specific test data** — `expect(body['id']).to eq(component.id)`. Catches wrong-record bugs.

### Coverage target:
- Every one of the 67 path operations gets a contract test
- Every test has at least 3 specific field assertions
- Every review endpoint asserts user_id is ABSENT
- Every multi-key response asserts ALL keys present
- Every nested association asserts nested fields exist

### Endpoints to test (52+ missing):
- Users: 4 missing (PUT/DELETE users/:id, GET users/:id/comments, POST unlink_identity)
- Components: 16+ missing (full CRUD + lock + comments + rules + related + detect_srg + history + compare + preview/apply spreadsheet + bulk_export)
- Rules+Reviews: 21 missing (all review lifecycle + rule CRUD + section locks + satisfactions + reactions)
- Projects+Benchmarks: 15 missing (comments + histories + import + export + components + memberships + SRG/STIG CRUD + export)
- Existing tests: strengthen all 23 existing tests with specific field assertions

## Phase 6: Examples and Minor Fixes (7 fixes)

Fix example text, provider example, enum verification. Low priority but must be correct.

## Execution Rules

1. DO NOT close a card until ALL verification steps (1-10 above) pass
2. DO NOT use agents for schema/YAML work — do it yourself inline
3. DO NOT write a schema without reading the Blueprint source first
4. DO NOT write a contract test against a schema you haven't verified against real data
5. DO NOT use --force close on any beads card
6. Every schema change must be verified by hitting the real API endpoint
7. Show Aaron the real API response vs the schema for each major endpoint before closing
