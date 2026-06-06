# ADR: API Filtering, Pagination, and Sorting Concern

**Status:** Proposed  
**Date:** 2026-06-06  
**Deciders:** Aaron Lippold  
**Card:** v2-btu.37 → v2-btu.38

## Context

Every API list endpoint needs pagination, filtering, search, and sorting. We currently have:

- **CommentQueryService** — hand-rolled pagination with `{rows, pagination: {page, per_page, total}}` envelope
- **Api::SearchController** — ILIKE search with `sanitize_sql_like` + `pg_search`
- **Component#search_members** — ILIKE with limit

These 3 implementations solve the same problem differently. The SPA migration will add 10+ new list endpoints (SRGs, STIGs, Components, Users, Audit trail, etc.). Without a shared concern, we'll have 13+ hand-rolled implementations.

## Research: Industry Patterns

### GitLab (offset + keyset)
- Offset: `?page=2&per_page=20`, `Link` headers for prev/next
- Keyset: `?pagination=keyset&per_page=20`, opaque `cursor` in Link header
- Default per_page: 20, max: 100
- Filtering: `?state=opened&labels=bug` (flat query params)
- Sorting: `?order_by=created_at&sort=desc`
- Source: https://docs.gitlab.com/ee/api/rest/#pagination

### GitHub
- Offset: `?page=2&per_page=30`, `Link` headers
- Default per_page: 30, max: 100
- Filtering: flat query params per endpoint
- Sorting: `?sort=created&direction=desc`
- Source: https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api

### Stripe (cursor-based)
- Cursor: `?starting_after=obj_123&limit=10`
- Response: `{data: [...], has_more: true}`
- No page numbers — cursor only
- Source: https://docs.stripe.com/api/pagination

### JSON:API spec
- Pagination: `?page[number]=2&page[size]=20` (nested params)
- Filtering: `?filter[status]=active` (nested params)
- Sorting: `?sort=-created_at,name` (comma-separated, `-` prefix for desc)
- Source: https://jsonapi.org/format/#fetching-filtering

## Research: Rails Gems

### Pagy (recommended)
- Fastest pagination gem (40x faster than kaminari)
- Supports offset AND keyset pagination
- Built-in JSON:API support (`jsonapi: true`)
- Clean controller API: `@pagy, @records = pagy(:offset, scope)`
- `max_limit` enforcement built in
- Already has `limit.clamp` pattern we use in CommentQueryService
- Source: https://github.com/ddnexus/pagy

### Kaminari
- Older, slower, heavier
- AR scope-based: `Model.page(2).per(25)`
- No keyset support
- Template-centric (designed for HTML, not JSON APIs)

### has_scope
- Declarative filter DSL: `has_scope :status, :section`
- Maps query params to model scopes automatically
- Lightweight, composable
- Source: https://github.com/heartcombo/has_scope

### ransack
- Full-featured search/filter engine
- Heavy, complex, security surface area
- Overkill for our use case

## Research: Existing Vulcan Patterns

### CommentQueryService (the gold standard we already have)
```ruby
# Response envelope — keep this exactly
{ rows: [...], pagination: { page:, per_page:, total: }, status_counts: {} }

# Page/per_page handling — keep this exactly
@page = [params.fetch(:page, 1).to_i, 1].max
@per_page = params.fetch(:per_page, 25).to_i.clamp(1, 100)
```

### Api::SearchController
```ruby
# ILIKE with sanitize_sql_like — keep this pattern
sanitized = ActiveRecord::Base.sanitize_sql_like(query)
scope.where('name ILIKE :q OR title ILIKE :q', q: "%#{sanitized}%")
```

## Decision

### Pagination: Pagy gem (NOT hand-rolled)

**Why:** Hand-rolling pagination is reinventing the wheel. Pagy is:
- The fastest Ruby pagination gem (40x faster than kaminari)
- Battle-tested edge case handling (out-of-range pages, zero results, overflow)
- Built-in keyset/cursor pagination for when we outgrow offset
- JSON:API support out of the box (`jsonapi: true`)
- Clean controller API: `@pagy, @records = pagy(:offset, scope)`
- Built-in `max_limit` enforcement
- High reputation, actively maintained, 850+ code snippets in docs

**Install:** `bundle add pagy`

**Response envelope:** Pagy provides its own metadata. We map it to our established shape:
```ruby
def pagy_response(pagy, records)
  {
    rows: records,
    pagination: { page: pagy.page, per_page: pagy.limit, total: pagy.count }
  }
end
```

This preserves the `{rows, pagination}` shape CommentQueryService established while using pagy's math underneath. CommentQueryService migrates to pagy internally (same external interface).

### Filtering: has_scope gem (NOT hand-rolled)

**Why:** has_scope provides declarative, auditable filter mapping:
```ruby
class Api::SrgsController < Api::BaseController
  has_scope :by_family, as: :family
  has_scope :search, as: :q

  def index
    @pagy, @records = pagy(:offset, apply_scopes(SecurityRequirementsGuide.all))
    render json: pagy_response(@pagy, @records)
  end
end
```

- Maps query params to model scopes automatically
- Scopes live on the model (testable, reusable)
- No custom DSL to maintain — follows Rails conventions
- Lightweight (no ransack complexity)
- Source: https://github.com/heartcombo/has_scope

**Install:** `bundle add has_scope`

### Sorting: `?sort=field&order=asc|desc` (GitLab/GitHub pattern)

**Why:** Simpler than JSON:API's `?sort=-created_at,name`. The GitLab pattern is widely understood. Implemented as a concern method that validates the sort field against a whitelist:
```ruby
def apply_sort(scope, allowed: [])
  field = params[:sort]
  return scope unless allowed.include?(field)
  scope.order(field => params.fetch(:order, 'asc'))
end
```

### Search: ILIKE with sanitize_sql_like + pg_search

**Why:** `pg_search` is already installed. Use it for full-text search on content-heavy fields (rule descriptions). Use ILIKE for simple substring matching (names, titles, IDs). Both patterns already proven in the codebase.

### Latest: `?latest=true` with numeric version parsing

**Why:** Specific to SRG/STIG/Component resources. Implemented as a model scope:
```ruby
scope :latest_per_family, -> {
  where(id: select('DISTINCT ON (srg_id) id')
    .order(Arel.sql("srg_id, CAST(SUBSTRING(version FROM 'V(\\d+)R') AS INTEGER) DESC, CAST(SUBSTRING(version FROM 'R(\\d+)') AS INTEGER) DESC")))
}
```

### Concern Architecture

The ApiFilterable concern provides the GLUE — not the implementation:
```ruby
module ApiFilterable
  extend ActiveSupport::Concern
  include Pagy::Backend
  include HasScope

  def pagy_response(pagy, records)
    { rows: records, pagination: { page: pagy.page, per_page: pagy.limit, total: pagy.count } }
  end

  def apply_sort(scope, allowed: [])
    # validates + applies sort
  end
end
```

Each controller uses pagy + has_scope + the concern's helpers. No custom DSL — just Rails conventions + proven gems.

## Consequences

### Positive
- Two well-maintained gems handle the hard parts (pagy, has_scope)
- No hand-rolled pagination math
- Keyset pagination available when we need it (pagy supports both)
- Declarative, auditable filter mapping via has_scope
- Response envelope matches existing CommentQueryService shape
- Scopes on models are independently testable

### Negative
- Two new dependencies (pagy ~3KB, has_scope ~2KB — both tiny)
- CommentQueryService needs migration to pagy (same interface, different internals)

### Risks
- If pagy's response metadata shape changes in a major version, the mapping function needs updating. Low risk — pagy is stable.

## References

- GitLab pagination: https://docs.gitlab.com/ee/api/rest/#pagination
- GitHub pagination: https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api
- Stripe pagination: https://docs.stripe.com/api/pagination
- JSON:API filtering: https://jsonapi.org/format/#fetching-filtering
- Pagy gem: https://github.com/ddnexus/pagy (evaluated, not adopted)
- CommentQueryService: app/services/comment_query_service.rb (existing pattern)
