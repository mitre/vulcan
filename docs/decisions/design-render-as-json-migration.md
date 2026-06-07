# Design: Migrate render_as_hash → render_as_json

**Status:** Proposed
**Date:** 2026-06-06
**Why:** `render_as_hash` returns symbol keys. `response.parsed_body` returns string keys.
Same data, two key types = bugs (query_performance_spec.rb:135 proved it).
Blueprinter provides `render_as_json` which returns string keys + JSONified values —
matching the wire format exactly.

## Scope

### Production Code — 16 files, ~50 call sites

**Controllers (9 files):**
| File | Call sites | Notes |
|------|-----------|-------|
| `app/controllers/reviews_controller.rb` | 18 | Highest density. All `ReviewBlueprint.render_as_hash` |
| `app/controllers/rules_controller.rb` | 7 | `RuleBlueprint`, `StigBlueprint`, `ComponentBlueprint`, `SrgRuleBlueprint` |
| `app/controllers/components_controller.rb` | 4 | `RuleBlueprint`, `ComponentBlueprint` |
| `app/controllers/users_controller.rb` | 5 | `UserBlueprint`, `CommentRowBlueprint` |
| `app/controllers/application_controller.rb` | 2 | `UserBlueprint` for navbar data |
| `app/controllers/projects_controller.rb` | 1 | `ProjectIndexBlueprint` |
| `app/controllers/personal_access_tokens_controller.rb` | 1 | `PersonalAccessTokenBlueprint` |
| `app/controllers/api/navigation_controller.rb` | 2 | `UserBlueprint` |
| `app/controllers/api/projects_controller.rb` | 1 | `ProjectBlueprint` |

**Blueprints (3 files — nested render calls):**
| File | Call sites | Notes |
|------|-----------|-------|
| `app/blueprints/rule_blueprint.rb` | 1 | `SrgRuleBlueprint.render_as_hash` in field block |
| `app/blueprints/component_blueprint.rb` | 1 | `ProjectBlueprint.render_as_hash` in field block |
| `app/blueprints/project_blueprint.rb` | 1 | `UserBlueprint.render_as_hash` in access_requests field |

**Models + Services (3 files):**
| File | Call sites | Notes |
|------|-----------|-------|
| `app/models/component.rb` | 1 | `ReviewBlueprint.render_as_hash` in `#reviews` |
| `app/models/project.rb` | 1 | `CommentRowBlueprint.render_as_hash` in `#paginated_comments` |
| `app/services/comment_query_service.rb` | 1 | `CommentRowBlueprint.render_as_hash` + **`row[:rule_content]` symbol-key injection** |

### Production Code — Symbol-Key Injection (must change to string key)

Only one site injects into the hash after `render_as_hash`:
- `app/services/comment_query_service.rb:138` — `row[:rule_content] = ...` → must become `row['rule_content'] = ...`

### Test Code — 12 files, ~75 call sites using symbol keys

**Blueprint specs (9 files) — all use symbol keys on render_as_hash output:**
| File | Symbol accesses | Change |
|------|----------------|--------|
| `spec/blueprints/review_membership_blueprints_spec.rb` | 48 | `[:field]` → `['field']` |
| `spec/blueprints/rule_blueprint_spec.rb` | 11 | `[:field]` → `['field']` |
| `spec/blueprints/project_index_blueprint_pending_link_spec.rb` | 9 | `[:field]` → `['field']` |
| `spec/blueprints/project_blueprint_pending_count_spec.rb` | 7 | `[:field]` → `['field']` |
| `spec/blueprints/component_blueprint_spec.rb` | 6 | `[:field]` → `['field']` |
| `spec/blueprints/stig_srg_blueprints_spec.rb` | 6 | `[:field]` → `['field']` |
| `spec/blueprints/user_blueprint_spec.rb` | 4 | `[:field]` → `['field']` |
| `spec/blueprints/comment_row_blueprint_spec.rb` | 3 | `[:field]` → `['field']` |
| `spec/blueprints/leaf_blueprints_spec.rb` | 1 | `[:field]` → `['field']` |

**Model specs (3 files):**
| File | Symbol accesses | Change |
|------|----------------|--------|
| `spec/models/components_paginated_comments_spec.rb` | 36 | `[:field]` → `['field']` |
| `spec/models/rules_spec.rb` | 24 | `[:field]` → `['field']` |
| `spec/models/query_performance_spec.rb` | 12 | `[:field]` → `['field']` (the bug we found) |
| `spec/models/rule_as_json_performance_spec.rb` | 5 | `[:field]` → `['field']` |
| `spec/models/components_creation_spec.rb` | 2 | `[:field]` → `['field']` |

**Request spec (1 file) — already works around the issue:**
| File | Notes |
|------|-------|
| `spec/requests/components_show_spec.rb` | `.keys.map(&:to_s)` workaround → simplify to `.keys` |

### Files NOT affected
- Request specs that use `response.parsed_body` — already string keys, no change needed
- Contract specs — use `response.parsed_body`, no change needed
- Blueprint `.render()` calls (JSON string) — no change needed
- Frontend JavaScript — receives JSON (string keys), no change

## Execution Order

The change is mechanical (find-replace `render_as_hash` → `render_as_json`) but must be
done carefully because symbol-key accesses in production code and tests will silently
return nil with string keys.

### Phase 1 — Production code (controllers + models + services)
Simple `render_as_hash` → `render_as_json` rename. No behavior change for HTTP responses
(Rails `render json:` calls `.to_json` on the hash regardless of key type).
One special case: `comment_query_service.rb` symbol-key injection.

### Phase 2 — Blueprint nested calls
Blueprints that call `render_as_hash` inside field blocks. These return nested hashes
whose key type must match the parent.

### Phase 3 — Test code
All `[:field]` → `['field']` in specs that directly call `render_as_hash` (now `render_as_json`).
Remove the `.keys.map(&:to_s)` workaround in `components_show_spec.rb`.

## Risk Assessment

**Low risk.** The change is:
1. Mechanical rename (`render_as_hash` → `render_as_json`)
2. Key type fix in one production line (`row[:rule_content]` → `row['rule_content']`)
3. Test key type updates (`[:x]` → `['x']`)

HTTP responses are unaffected — `render json: hash` calls `.to_json` which produces
the same JSON string regardless of symbol vs string keys.

**The only production behavior change** is in `comment_query_service.rb` where the
injected `rule_content` key changes from symbol to string. Since this hash is immediately
returned as JSON via `render json:`, the wire format is identical.
