# Design: ApiFilterable Concern

**Companion to:** [ADR: API Filtering](adr-api-filtering-concern.md)
**Cards:** v2-btu.38 (concern), v2-btu.39 (version sort fix), v2-btu.33 (list endpoints)

## Gems

```bash
bundle add pagy has_scope
```

Both are already decided per ADR. No custom pagination math, no custom filter DSL.

## Pagy Initializer

```ruby
# config/initializers/pagy.rb
Pagy::OPTIONS[:limit]     = 25
Pagy::OPTIONS[:max_limit] = 100
Pagy::OPTIONS[:page_key]  = 'page'
Pagy::OPTIONS[:limit_key] = 'per_page'
Pagy::OPTIONS.freeze
```

Matches CommentQueryService defaults (25/page, max 100).

## Concern: `app/controllers/concerns/api_filterable.rb`

```ruby
module ApiFilterable
  extend ActiveSupport::Concern
  include Pagy::Method

  def paginate(scope, **opts)
    pagy(:offset, scope, **opts)
  end

  def pagy_response(pagy_obj, records, **extra)
    {
      rows: records,
      pagination: {
        page: pagy_obj.page,
        per_page: pagy_obj.limit,
        total: pagy_obj.count
      }
    }.merge(extra)
  end

  def apply_sort(scope, allowed:)
    field = params[:sort]
    return scope unless field.present? && allowed.include?(field)
    direction = %w[asc desc].include?(params[:order]) ? params[:order] : 'asc'
    scope.order(field => direction)
  end
end
```

**What each method does:**
- `paginate` — thin wrapper around `pagy(:offset, ...)`. Returns `[pagy_obj, records]`.
- `pagy_response` — maps pagy instance to our established `{rows, pagination}` envelope. Accepts `**extra` for endpoint-specific metadata (e.g., `status_counts`).
- `apply_sort` — whitelist-validated sort. Unknown fields are silently ignored (not 400 — simpler for frontend, matches GitLab).

**What the concern does NOT do:**
- Search — model scopes handle ILIKE via has_scope
- Filter mapping — has_scope handles `?param=` → `Model.scope()` declaratively
- Version parsing — model scopes own that logic

## Controller Pattern

```ruby
class Api::SrgsController < Api::BaseController
  include ApiFilterable

  has_scope :by_family, as: :family
  has_scope :search, as: :q

  def index
    scope = apply_scopes(SecurityRequirementsGuide.all)
    scope = apply_sort(scope, allowed: %w[title version created_at])
    pagy_obj, records = paginate(scope)
    render json: pagy_response(pagy_obj, SrgBlueprint.render_as_hash(records))
  end

  def latest
    records = SecurityRequirementsGuide.latest_versions
    records = records.search(params[:q]) if params[:q].present?
    render json: { rows: SrgBlueprint.render_as_hash(records, view: :latest) }
  end
end
```

**Pattern rules:**
- `apply_scopes` first (has_scope), then `apply_sort`, then `paginate`
- Blueprint renders the records, not `.as_json`
- `latest` is unpaginated (family count is small)

## Model Scope Pattern

Each model declares its own scopes. has_scope maps params to them.

```ruby
class SecurityRequirementsGuide < ApplicationRecord
  scope :by_family, ->(family) {
    where('title ILIKE ?', "%#{sanitize_sql_like(family)}%")
  }

  scope :search, ->(q) {
    sanitized = sanitize_sql_like(q)
    where('title ILIKE :q OR srg_id ILIKE :q', q: "%#{sanitized}%")
  }

  scope :latest_versions, -> {
    where(id: select(<<~SQL.squish))
      DISTINCT ON (title) id
      FROM security_requirements_guides
      ORDER BY title,
        CAST(SUBSTRING(version FROM 'V(\\d+)R') AS INTEGER) DESC NULLS LAST,
        CAST(SUBSTRING(version FROM 'R(\\d+)')  AS INTEGER) DESC NULLS LAST
    SQL
  }
end
```

**Version sort fix (.39):** Replace `MAX(version)` string comparison with
`DISTINCT ON` + numeric `SUBSTRING` + `CAST`. `V10R1` correctly ranks above `V4R4`.

## Response Envelope (unchanged)

```json
{
  "rows": [...],
  "pagination": {
    "page": 1,
    "per_page": 25,
    "total": 47
  }
}
```

Same shape as CommentQueryService. Frontend code doesn't change.

## 8-Layer Checklist (per endpoint)

1. **Blueprint** — create or reuse (SrgBlueprint, StigBlueprint)
2. **Controller** — include ApiFilterable + has_scope declarations
3. **Route** — add to `namespace :api` in routes.rb
4. **Request spec** — test filtering, pagination, sorting, auth
5. **OpenAPI schema** — YAML path + response schema
6. **Contract test** — validate real response against OpenAPI schema
7. **Bundle + lint** — `yarn openapi:bundle && yarn openapi:lint && bundle exec rubocop`
8. **Live test** — curl with real PAT + real data, paste output in card notes

## Card Execution Order

```
.38  Install gems + build ApiFilterable concern + test via dummy endpoint
      ↓
.39  Fix SecurityRequirementsGuide.latest + add Stig.latest (version sort)
      ↓
.33  Wire GET /api/srgs + /stigs list endpoints using concern + scopes
```

## CommentQueryService Coexistence

CommentQueryService stays for now — it has comment-specific logic (status_counts,
resolved tri-state, preload chains) beyond generic filtering. Future card can
migrate its pagination internals to pagy while keeping the service API.

## Error Handling

```ruby
# In Api::BaseController or ApplicationController
rescue_from Pagy::RangeError do |e|
  render json: { error: "Page #{e.pagy.page} is out of range (1..#{e.pagy.last})" },
         status: :bad_request
end
```
