# OpenAPI Full Audit — 2026-05-29

> **Method:** Every schema file read against its Blueprint/controller source.
> Every contract test read for quality.
> Nothing assumed — everything verified by reading source code.
>
> **Next step:** Hit real API endpoints to verify schemas against actual responses.

## Status: SCHEMA + CONTRACT TEST AUDIT COMPLETE. REAL API VERIFICATION PENDING.

---

## Schema-by-Schema Audit (33 files)

### CORRECT — Schema matches source exactly

| # | Schema | Source | Fields | Notes |
|---|--------|--------|--------|-------|
| 1 | UserSummary.yaml | UsersController::USER_JSON_FIELDS + last_sign_in_at | 8/8 | id, name, email, provider, admin, last_sign_in_at, failed_attempts, locked_at |
| 2 | MembershipSummary.yaml | MembershipBlueprint default | 7/7 | id, user_id, role, membership_type, membership_id, name, email |
| 3 | ProjectIndexResponse.yaml | ProjectIndexBlueprint | 15/15 | Includes admin, is_member, access_request_id, pending/total comment counts, pending_comment_link |
| 4 | CheckSummary.yaml | CheckBlueprint | 6/6 | id, system, content_ref_name, content_ref_href, content, _destroy |
| 5 | DisaRuleDescription.yaml | DisaRuleDescriptionBlueprint | 15/15 | All DISA fields including vuln_discussion through poam + _destroy |
| 6 | SatisfactionSummary.yaml | SatisfactionBlueprint | 3/3 | id, rule_id, srg_id |
| 7 | SatisfiedBySummary.yaml | SatisfiedByBlueprint | 4/4 | Extends SatisfactionSummary + fixtext |
| 8 | RuleDescriptionSummary.yaml | RuleDescriptionBlueprint | 3/3 | id, description, _destroy |
| 9 | AdditionalAnswerSummary.yaml | AdditionalAnswerBlueprint | 3/3 | id, additional_question_id, answer |
| 10 | SrgRuleSummary.yaml | SrgRuleBlueprint | 19+ | All fields + nested $refs to RuleDescriptionSummary, DisaRuleDescription, CheckSummary |
| 11 | StigRuleSummary.yaml | StigRuleBlueprint | 16+ | All fields + nested $refs to DisaRuleDescription, CheckSummary |
| 12 | ToastResponse.yaml | ApplicationController#render_toast (line 66-74) | 3/3 | toast { title: string, message: array, variant: enum } |
| 13 | UserToastResponse.yaml | UsersController lock/unlock/update (multi-key responses) | 2/2 | toast + user $ref UserSummary. DRY note: toast inlined, could $ref ToastResponse |
| 14 | ResetLinkResponse.yaml | UsersController#generate_reset_link (line 191-196) | 2/2 | toast { title, message, variant } + reset_url: string |
| 15 | ReactionToggleResponse.yaml | ReactionsController#create → Reaction.summary (line 27-33) | 3/3 | reactions { up: int, down: int, mine: [string, null] } |
| 16 | ReactionsSummary.yaml | ReactionsController#index (line 17-24) | 2/2 | up: [{ name }], down: [{ name }]. Naming misleading — this is the detailed list, not summary counts |
| 17 | StatusOk.yaml | Multiple endpoints: `render json: { status: :ok }` | 1/1 | { status: string } |
| 18 | PaginatedComments.yaml | CommentQueryService#call (line 31-35) | 3/3 | rows + pagination + status_counts — structure correct BUT rows $ref CommentRow which is WRONG (see below) |

### WRONG — Fabricated fields, missing fields, or incorrect types

#### 19. ReviewSummary.yaml — CRITICAL

**Source:** ReviewBlueprint (app/blueprints/review_blueprint.rb)

| Category | Field | Detail |
|----------|-------|--------|
| **FABRICATED** | `user_id` | **SECURITY.** Blueprint line 7 explicitly says "user_id stays excluded as a public-comment correlation guard." Schema has it. |
| MISSING | `triage_status` | Blueprint line 12 |
| MISSING | `triage_set_at` | Blueprint line 12 |
| MISSING | `adjudicated_at` | Blueprint line 12 |
| MISSING | `section` | Blueprint line 17 |
| MISSING | `duplicate_of_review_id` | Blueprint line 17 |
| MISSING | `triage_set_by_id` | Blueprint line 17 |
| MISSING | `name` | Blueprint line 20-22 (computed: review.user.name) |
| MISSING | `author_name` | Blueprint line 27-29 (computed: review.user.name) |
| MISSING | `triager_display_name` | Blueprint line 53 via ImportedAttributionFields |
| MISSING | `triager_imported` | Blueprint line 53 |
| MISSING | `adjudicator_display_name` | Blueprint line 54 |
| MISSING | `adjudicator_imported` | Blueprint line 54 |
| MISSING | `commenter_display_name` | Blueprint line 55 |
| MISSING | `commenter_imported` | Blueprint line 55 |
| MISSING | `reactions` | Blueprint line 60-63: `{ up: int, down: int, mine: string\|nil }` |

Schema has 7 fields, Blueprint outputs 22. **15 missing, 1 fabricated.**

#### 20. ComponentSummary.yaml — CRITICAL

**Source:** ComponentBlueprint DEFAULT view (app/blueprints/component_blueprint.rb lines 14-38)

Default view fields: id, name, prefix, version, release, based_on_title, based_on_version, severity_counts, pending_comment_count

| Category | Field | Detail |
|----------|-------|--------|
| **FABRICATED** | `project_id` | Not in ANY Blueprint view |
| **MISPLACED** | `title` | Only in :show/:editor, NOT default |
| **MISPLACED** | `released` | Only in :show/:editor/:index, NOT default |
| **MISPLACED** | `rules_count` | Only in :index/:editor, NOT default |
| **MISPLACED** | `description` | Only in :show/:editor, NOT default |
| MISSING | `based_on_title` | Blueprint line 19-21 (computed) |
| MISSING | `based_on_version` | Blueprint line 23-25 (computed) |
| MISSING | `severity_counts` | Blueprint line 27-29 (computed) |
| MISSING | `pending_comment_count` | Blueprint line 35-38 (computed) |

Schema has 10 fields. 5 wrong (fabricated/misplaced), 4 missing from default view.

#### 21. RuleSummary.yaml — MAJOR

**Source:** RuleBlueprint DEFAULT view (app/blueprints/rule_blueprint.rb lines 14-51)

Default view fields: id, rule_id, title, version, status, rule_severity, locked, review_requestor_id, changes_requested, comment_summary

| Category | Field | Detail |
|----------|-------|--------|
| **FABRICATED** | `component_id` | Not in default view (only in :viewer) |
| MISSING | `version` | Blueprint line 15 |
| MISSING | `rule_severity` | Blueprint line 15 |
| MISSING | `review_requestor_id` | Blueprint line 16 |
| MISSING | `changes_requested` | Blueprint line 16 |
| MISSING | `comment_summary` | Blueprint line 29-51: computed `{ open: int, total: int }` |

Schema has 6 fields. 1 fabricated, 5 missing.

#### 22. ProjectSummary.yaml — MAJOR

**Source:** ProjectBlueprint DEFAULT view (app/blueprints/project_blueprint.rb lines 4-8)

Default view fields: id, name, description, visibility, memberships_count, admin_name, admin_email, created_at, updated_at

| Category | Field | Detail |
|----------|-------|--------|
| **FABRICATED** | `components_count` | Not in any ProjectBlueprint view. Only exists in SearchController (line 65). |
| MISSING | `memberships_count` | Blueprint line 7 |
| MISSING | `admin_name` | Blueprint line 8 |
| MISSING | `admin_email` | Blueprint line 8 |

Schema has 7 fields. 1 fabricated, 3 missing.

#### 23. CommentRow.yaml — MAJOR

**Source:** CommentQueryService#serialize_rows (app/services/comment_query_service.rb lines 129-166)

| Category | Field | Detail |
|----------|-------|--------|
| MISSING | `duplicate_of_review_id` | Line 144 |
| MISSING | `addressed_by_rule_id` | Line 145 |
| MISSING | `addressed_by_rule_name` | Line 146 |
| MISSING | `triager_display_name` | Line 147 |
| MISSING | `triager_imported` | Line 148 |
| MISSING | `adjudicator_display_name` | Line 149 |
| MISSING | `adjudicator_imported` | Line 150 |
| MISSING | `commenter_display_name` | Line 151 |
| MISSING | `commenter_imported` | Line 152 |
| MISSING | `updated_at` | Line 156 |
| MISSING | `rule_status` | Line 157 |
| MISSING | `parent_rule_displayed_name` | Line 158 |
| MISSING | `group_rule_displayed_name` | Line 159/162 |
| MISSING | `rule_content` | Line 163 (conditional, when include_rule_content=true) |

Schema has 14 fields. 13+ missing.

#### 24. AuditEntry.yaml — MAJOR

**Source:** VulcanAudit#format (app/lib/vulcan_audit.rb lines 117-138)

Returns: `{ id, action, auditable_type, auditable_id, name, audited_name, comment, created_at, audited_changes: [{ field, prev_value, new_value }] }`

| Category | Field | Detail |
|----------|-------|--------|
| **FABRICATED** | `user_id` | VulcanAudit#format returns `name` (line 124), NOT user_id |
| **WRONG TYPE** | `audited_changes` | Schema says `oneOf [object, string, null]`. Actual is an ARRAY of `{ field: str, prev_value: any, new_value: any }` (lines 128-136) |
| MISSING | `name` | Line 124 — username who made the change |
| MISSING | `audited_name` | Line 125 — username of audited record owner |
| MISSING | `comment` | Line 126 — audit comment text |

#### 25. BenchmarkSummary.yaml — DESIGN ISSUE

**Source:** Two separate Blueprints with different date fields:
- SrgBlueprint: `release_date` (line 7)
- StigBlueprint: `benchmark_date` (line 9)

Schema conflates both into one type with only `release_date`. STIGs have `benchmark_date` which is missing. Should be split into SrgSummary + StigSummary.

#### 26. VersionResponse.yaml — MINOR

**Source:** Api::VersionController#show (line 16-22)

Returns: `{ name: 'Vulcan', version:, rails:, ruby:, environment: }`

Schema has: version, rails, ruby (3 fields)
Missing: `name`, `environment` (2 fields)

#### 27. GlobalSearchResponse.yaml — PARTIALLY WRONG

**Source:** Api::SearchController#global (line 31-39)

| Sub-schema | Schema fields | Actual fields | Issues |
|------------|--------------|---------------|--------|
| projects | id, name, description, components_count | id, name, description, components_count | OK |
| components | id, name, version, release, project_id, project_name | + metadata | **Missing: metadata** |
| rules | id, rule_id, title, status, component_id, component_prefix, snippet, matched_field, comment_count | + parent_rule_id, parent_display_name | **Missing: parent_rule_id, parent_display_name** |
| srgs | `type: object` (empty) | id, srg_id, name, title, version | **EMPTY — 5 fields missing** |
| stigs | `type: object` (empty) | id, stig_id, name, title, version, description | **EMPTY — 6 fields missing** |
| stig_rules | `type: object` (empty) | id, rule_id, vuln_id, title, fixtext, ident, stig_id, stig_name | **EMPTY — 8 fields missing** |
| srg_rules | `type: object` (empty) | id, rule_id, title, fixtext, ident, srg_id, srg_name | **EMPTY — 7 fields missing** |

4 sub-schemas are completely empty (no properties defined). 2 have missing fields.

#### 28. AdminCreateResponse.yaml — PARTIALLY WRONG

**Source:** UsersController#admin_create (lines 27-56)

Success: `{ user: as_json(only: USER_JSON_FIELDS), toast: STRING, reset_url?: STRING }`
Error: `{ toast: { title, message, variant } }` — NO `user` key

Issues:
- `required: [toast, user]` is wrong — error response has no `user` key
- Toast correctly typed as `[string, object]` (string on success, object on error)
- `reset_url` correctly marked optional

### INPUT SCHEMAS

| # | Schema | Strong params source | Verdict | Notes |
|---|--------|---------------------|---------|-------|
| 29 | ComponentInput.yaml | components_controller.rb:770-776 | INCOMPLETE | Schema has 6 fields. Strong params permit 13+ fields including admin_name, admin_email, advanced_fields, comment_phase, closed_reason, comment_period_starts_at, comment_period_ends_at, additional_questions_attributes, component_metadata_attributes. Not all needed in schema (some are separate endpoints) but worth documenting what's accepted. |
| 30 | ProjectInput.yaml | projects_controller.rb:519-523 | INCOMPLETE | Schema has 3 fields. Strong params also permit project_metadata_attributes: { data: {} }. Missing metadata input. |
| 31 | RuleInput.yaml | rules_controller.rb:273-287 | INCOMPLETE | Schema has 7 fields. Strong params permit 17 scalar fields + 4 nested attribute groups (checks, rule_descriptions, additional_answers, disa_rule_descriptions). Missing: rule_severity, rule_weight, version, ident, ident_system, fix_id, fixtext_fixref, audit_comment, inspec_*, and ALL nested attribute groups. |
| 32 | ReviewInput.yaml | reviews_controller.rb:706 | CLOSE | Schema has 4 fields: action, comment, section, responding_to_review_id. Strong params permit 5: component_id, action, comment, section, responding_to_review_id. Missing: component_id (only for component-level comments). |
| 33 | MembershipInput.yaml | (memberships_controller.rb) | NEEDS VERIFICATION | Has user_id, membership_id, membership_type, role — appears reasonable but needs controller strong params check. |

### MISSING SCHEMAS (needed but don't exist)

| Schema | Source | Why needed |
|--------|--------|-----------|
| ComponentEditorResponse | ComponentBlueprint :editor (30+ fields) | GET /components/:id returns this to project members |
| ComponentIndexResponse | ComponentBlueprint :index | Lists with updated_at, released, rules_count, component_id |
| RuleEditorResponse | RuleBlueprint :editor (35+ fields) | GET /rules/:id and nested inside ComponentEditorResponse |
| RulePickerResponse | RuleBlueprint :picker | /components/:id/rules/picker endpoint |
| ProjectShowResponse | ProjectBlueprint :show | GET /projects/:id returns this — nested components, memberships, histories, users, access_requests |
| SrgDetailResponse | SrgBlueprint :show | GET /srgs/:id — includes nested srg_rules array |
| StigDetailResponse | StigBlueprint :show | GET /stigs/:id — includes nested stig_rules + description |
| RuleToastResponse | Composite | { toast:, rule: } — returned by rule CRUD mutations |
| TriageResponse | Composite | { review:, response_review: } — returned by triage/adjudicate |
| AdminDestroyResponse | Reviews controller | { review: null, destroyed_id: int } — admin hard delete |

---

## Contract Test Audit (2 files, 23 tests)

### File 1: openapi_contract_validation_spec.rb (14 tests)

| Test | Quality | Issues |
|------|---------|--------|
| GET /api/version | WEAK | Only checks 3 keys exist. Doesn't assert `name` or `environment` (which the response actually includes and the schema doesn't document). |
| GET /api/search/global | WEAK | Checks 5 keys exist but not values. Doesn't check any sub-array item shapes. 4 sub-schemas are empty so openapi_first can't validate them. |
| GET /projects (JSON) | VERY WEAK | validate_response! only. No field assertions at all. |
| GET /projects/:id (JSON) | VERY WEAK | validate_response! only. No field assertions. Calls it "ProjectSummary" but ProjectBlueprint :show returns much more. |
| GET /components/:id (JSON) | VERY WEAK | validate_response! only. No field assertions. Response is ComponentBlueprint :editor (30+ fields) but schema is ComponentSummary (wrong). |
| GET /components/:id/comments | MODERATE | Checks rows/pagination/status_counts keys exist. Doesn't check any CommentRow field names. |
| GET /srgs (JSON) | WEAK | Checks array and first id. Doesn't check srg_id, name, title, version, severity_counts. |
| GET /stigs (JSON) | VERY WEAK | validate_response! + checks body is array. No field checks. |
| GET /users (JSON) | WEAK | Checks id and email exist. Doesn't check other 6 fields. |
| POST /projects | MODERATE | Checks toast.title is string. Doesn't check message array or variant. |
| PATCH /reviews/:id/reopen | MODERATE | Checks review key + review.id matches. Doesn't check any other review fields. |
| PATCH /reviews/:id/section | GOOD | Checks review key + review.section matches value. Best test in this file. |
| GET /rules/:id/related_rules | MODERATE | Checks rules and parents arrays exist. |
| POST /components/:id/find | WEAK | Checks body is array. No item shape checks. |

### File 2: users_admin_contract_spec.rb (9 tests)

| Test | Quality | Issues |
|------|---------|--------|
| POST admin_create (with password) | MODERATE | Checks toast + user keys, user.id, user.email. Doesn't check toast is string (not object). |
| POST admin_create (no SMTP) | GOOD | Checks reset_url includes token path. |
| POST send_password_reset (no SMTP) | GOOD | Checks 422 + toast.variant=danger. |
| POST generate_reset_link | GOOD | Checks toast + reset_url + token path + variant=success. Best test quality. |
| POST set_password (success) | MODERATE | Checks toast.variant=success. |
| POST set_password (blank) | MODERATE | Checks 422 + toast.variant=danger. |
| POST lock | GOOD | Checks toast + user + locked_at not nil. |
| POST lock self | MODERATE | Checks 422 + toast.variant=danger. |
| POST unlock | GOOD | Checks toast + user + locked_at nil. |

### Contract Test Summary

- **23 total tests** across 67 endpoints. **44 endpoints have NO contract test at all.**
- **0 tests** check for ABSENT fields (e.g., user_id on ReviewSummary)
- **0 tests** check nested object field names (e.g., rule.checks_attributes inside ComponentEditorResponse)
- **5 tests** are "validate_response! only" — they pass with ANY response shape because the schemas themselves are wrong/loose
- The openapi_first gem CANNOT catch missing fields unless schemas use `additionalProperties: false` + `required` on every property — current schemas don't.

### Why These Tests Don't Catch Bugs

1. **Wrong schemas pass validation.** If ReviewSummary says user_id is optional and the Blueprint never sends it, openapi_first doesn't flag it — optional means "may be absent."
2. **No `additionalProperties: false`.** Extra fields in the response are silently accepted. A response with 22 fields passes a schema with 7.
3. **No absent-field assertions.** Nobody checks `expect(body['review']).not_to have_key('user_id')`.
4. **No nested field assertions.** Nobody checks that rules inside a component have checks_attributes.
5. **Many endpoints untested.** 44 of 67 path operations have zero tests.

---

## Path File Audit Status

**NOT YET DONE.** 67 path files need to be read to verify every `$ref` points to the correct schema. Given that 10 schemas are wrong and 10 are missing, many paths will $ref wrong schemas. This audit should happen AFTER schemas are fixed, since the $refs need to point to the corrected/new schemas.

---

## Real API Verification Status

**NOT YET DONE.** Need to start the dev server and hit real endpoints with `DATABASE_PORT=5433 bundle exec rails runner` to compare actual responses against schemas.

---

## Summary of All Findings

### Response Schemas: 10 wrong, 18 correct, 10 missing

| Category | Count | Items |
|----------|-------|-------|
| CORRECT | 18 | UserSummary, MembershipSummary, ProjectIndexResponse, CheckSummary, DisaRuleDescription, SatisfactionSummary, SatisfiedBySummary, RuleDescriptionSummary, AdditionalAnswerSummary, SrgRuleSummary, StigRuleSummary, ToastResponse, UserToastResponse, ResetLinkResponse, ReactionToggleResponse, ReactionsSummary, StatusOk, PaginatedComments (structure) |
| WRONG | 10 | ReviewSummary, ComponentSummary, RuleSummary, ProjectSummary, CommentRow, AuditEntry, BenchmarkSummary, VersionResponse, GlobalSearchResponse, AdminCreateResponse |
| MISSING | 10 | ComponentEditorResponse, ComponentIndexResponse, RuleEditorResponse, RulePickerResponse, ProjectShowResponse, SrgDetailResponse, StigDetailResponse, RuleToastResponse, TriageResponse, AdminDestroyResponse |

### Input Schemas: 4 incomplete, 1 needs verification

| Category | Count | Items |
|----------|-------|-------|
| INCOMPLETE | 4 | ComponentInput, ProjectInput, RuleInput, ReviewInput |
| NEEDS CHECK | 1 | MembershipInput |

### Contract Tests: 23 exist, 44 endpoints untested

| Quality | Count |
|---------|-------|
| GOOD | 5 |
| MODERATE | 8 |
| WEAK | 5 |
| VERY WEAK | 5 |
| MISSING | 44 endpoints |

### Security Issues

1. ReviewSummary.yaml has fabricated `user_id` — Blueprint explicitly excludes it as a public-comment correlation guard

### Total Work Items

| Work type | Count |
|-----------|-------|
| Schemas to rewrite | 10 |
| Schemas to create | 10 |
| Input schemas to complete | 4-5 |
| Path files to audit + fix $refs | 67 |
| Contract tests to write | 44 |
| Contract tests to strengthen | 18 |
| Real API verification runs | all endpoints |
