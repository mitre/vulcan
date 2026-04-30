# Task 29: DISA disposition matrix CSV export

**Depends on:** none (uses existing export infrastructure)
**Estimate:** 45 min Claude-pace
**File touches:**
- `app/controllers/components_controller.rb` (add `:disposition_csv` export type)
- `app/helpers/export_helper.rb` (or new `app/lib/disposition_matrix_export.rb`) — CSV row generator
- `app/javascript/components/components/ComponentComments.vue` (download button on the triage panel header)
- `spec/controllers/components_controller_spec.rb` or `spec/requests/components_controller_spec.rb` (extend)
- `spec/helpers/export_helper_spec.rb` (extend) or `spec/lib/disposition_matrix_export_spec.rb` (new)
- `spec/javascript/components/components/ComponentComments.spec.js` (extend)

## Why this task exists

The DISA public-comment-review process is a **federal compliance
artifact**: at the end of a review window, DISA expects a structured
record of every comment raised, its triage decision, the response, and
the adjudication outcome. The "disposition matrix" is that record.

Without an export, the comment data stays inside Vulcan and DISA
adjudicators have to extract it manually. For the Container SRG window
with DISA watching, this is the difference between "we built a
workflow" and "we built a workflow that produces deliverables."

This task is the **export side** of the comments-as-objects design —
comments live on rules, decisions live on comments, and the export
flattens that into a per-row CSV that DISA can consume.

OSCAL export is intentionally **out of scope** for this task — OSCAL
schemas for comment-review processes are a larger undertaking and not
required by DISA at the public-comment phase. CSV satisfies the
federal-compliance need; OSCAL is filed in Task 99's follow-ups.

## Verified facts

- `ComponentsController#export` (lines 171-219) already accepts a
  `:type` param and dispatches via `perform_export`. New types are
  added by extending the whitelist (line 175) and adding a `case`
  branch.
- Existing `:csv` type is rule-based (one row per Rule via
  `csv_attributes_hash`). The disposition matrix is comment-based
  (one row per top-level Review, with replies optionally flattened
  or shown in a "responses" column).
- `Component#paginated_comments` (component.rb:599+) already produces
  the right per-comment shape with rule_displayed_name, author_name,
  triage_status, adjudicated metadata, etc. — reuse as the data
  source for the export.
- DISA reviewers' typical workflow: open the CSV in Excel,
  filter/sort by `triage_status`, generate disposition reports.
- Authorization: **author tier minimum** (`authorize_author_project`
  or equivalent) — viewer-tier export is rejected to prevent
  commenter-email scraping. Email column is admin-only opt-in via
  `?include_email=true`. (Revised 2026-04-30 after agent review; see
  PII handling section below.)

## Design decisions

- **CSV format only** for v1. OSCAL deferred to follow-up phase.
- **One row per top-level Review** (responding_to_review_id IS NULL).
  Replies are NOT a separate row by default — collapsed into a
  `triager_response` column (text of the most recent reply by a
  triager). If multiple replies exist, concatenate with `\n---\n`
  separators.
- **DISA-friendly column headers** — use the canonical disposition
  vocabulary in the column names but keep the cell values in DISA
  format (concur, non_concur, concur_with_comment, etc.) since DISA
  consumes the CSV as raw data, not for human display.
- **Stable column order** so DISA can build their pivot tables
  reliably.
- **Filtering:** the export includes ALL comments in the component
  by default. Optional `?triage_status=` query param filters (e.g.
  `?triage_status=pending` for an in-progress snapshot).
- **Filename**: `{project_name}-{component_prefix}-disposition-matrix-{YYYY-MM-DD}.csv`
- **Audit log entry** when an export is generated (compliance — who
  exported what, when).

## Column schema (locked)

| Column | Source | Example |
|---|---|---|
| Comment ID | `review.id` | `142` |
| Rule | `review.rule_displayed_name` | `CNTR-01-000001` |
| SRG ID | `review.rule.version` | `SRG-APP-000014-CTR-000035` |
| Section | `review.section` (raw XCCDF key) | `check_content` |
| Commenter Name | `review.user.name` | `Sarah K` |
| Commenter Email | `review.user.email` (admin + `?include_email=true` only — see PII note below) | `sarahk@redhat.com` |
| Comment | `review.comment` | `"TLS 1.2 EOL by 2025..."` |
| Posted | `review.created_at` (ISO 8601) | `2026-04-26T10:00:00Z` |
| Triage Status | `review.triage_status` (DISA vocab) | `concur_with_comment` |
| Triaged By | `review.triage_set_by.name` | `Aaron Lippold` |
| Triaged At | `review.triage_set_at` | `2026-04-27T14:30:00Z` |
| Triager Response | most recent reply text from a triager | `"Will fix in next revision"` |
| Adjudicated | `review.adjudicated_at IS NOT NULL` | `true` / `false` |
| Adjudicated By | `review.adjudicated_by.name` | `Aaron Lippold` |
| Adjudicated At | `review.adjudicated_at` | `2026-04-28T09:00:00Z` |
| Duplicate Of | `review.duplicate_of_review_id` (if set) | `99` |

### PII handling — REVISED 2026-04-30 after agent review

The in-app `paginated_comments` deliberately omits `author_email` to
prevent commenter-email scraping by anyone with read access (see
component.rb:641-644 for the comment). The CSV export was originally
going to deviate from that for the federal-compliance record — but
authorization at viewer-tier reproduces the very leak the in-app
scrubber prevents (viewers include external commenters who could
download the whole roster).

**Final decision (revised after agent review):**

1. **Authorization tier raised from viewer to author**: use
   `authorize_author_project` (or the controller's existing
   triager-equivalent gate). Project members at viewer tier cannot
   export. This blocks the scraping vector at the endpoint.

2. **Email column is opt-in, admin-only**: the default CSV export
   does NOT include `Commenter Email`. To include it, the request
   must pass `?include_email=true` AND the user must satisfy
   `current_user.can_admin_project?(@component.project)`. Without
   admin role, the param is silently ignored and email is omitted
   (server-side enforcement, not just UI hiding).

3. **Audit logging always**: every export records who exported what,
   when, and whether `include_email` was set. This satisfies the
   federal-compliance "who has the email roster" question.

The default-without-email export remains useful for the disposition
record (DISA can match against their own commenter identity store via
name + comment ID). The admin-only email column is for the rare cases
where DISA explicitly needs the email roster as part of the formal
record.

Logging: write an audit entry when the export is generated, capturing
exporter user_id + timestamp + component_id + `include_email` flag.

## Step 1: Failing spec — backend

```ruby
# spec/requests/components_disposition_matrix_export_spec.rb (new)
require 'rails_helper'

RSpec.describe 'GET /components/:id/export?type=disposition_csv', type: :request do
  let(:component) { create(:component) }
  let(:project) { component.project }
  let(:rule) { create(:rule, component: component) }
  let(:user) { create(:user) }
  let(:commenter) { create(:user, name: 'Sarah K', email: 'sarah@example.com') }
  let(:triager) { create(:user, name: 'Aaron Lippold') }

  let(:viewer) { create(:user) }
  let(:admin) { create(:user) }
  before do
    Membership.create!(user: viewer, membership: project, role: 'viewer')
    Membership.create!(user: triager, membership: project, role: 'author')
    Membership.create!(user: admin, membership: project, role: 'admin')
    Membership.create!(user: commenter, membership: project, role: 'viewer')
  end

  let!(:c1) do
    Review.create!(rule: rule, user: commenter, action: 'comment',
                   section: 'check_content', comment: 'check text issue',
                   triage_status: 'concur_with_comment',
                   triage_set_by: triager, triage_set_at: 1.day.ago,
                   adjudicated_at: 12.hours.ago, adjudicated_by: triager)
  end
  let!(:reply) do
    Review.create!(rule: rule, user: triager, action: 'comment',
                   responding_to_review_id: c1.id,
                   comment: 'will fix in next revision',
                   triage_status: 'pending')
  end

  context 'as author (triager tier — minimum allowed)' do
    before { sign_in triager }

    it 'returns 200 with CSV content type and disposition headers' do
      get "/components/#{component.id}/export", params: { type: 'disposition_csv' }
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/csv')
      expect(response.body).to include('Comment ID,Rule,SRG ID,Section,')
    end

    it 'OMITS the Commenter Email column by default' do
      get "/components/#{component.id}/export", params: { type: 'disposition_csv' }
      expect(response.body).not_to include('Commenter Email')
      expect(response.body).not_to include('sarah@example.com')
    end

    it 'IGNORES include_email=true for non-admin users (server-side enforcement)' do
      get "/components/#{component.id}/export",
          params: { type: 'disposition_csv', include_email: 'true' }
      expect(response.body).not_to include('Commenter Email')
      expect(response.body).not_to include('sarah@example.com')
    end

    it 'includes one row per top-level comment (replies collapsed into Triager Response)' do
      get "/components/#{component.id}/export", params: { type: 'disposition_csv' }
      csv = CSV.parse(response.body, headers: true)
      expect(csv.length).to eq(1)
      row = csv.first
      expect(row['Comment ID']).to eq(c1.id.to_s)
      expect(row['Rule']).to eq("#{component.prefix}-#{rule.rule_id}")
      expect(row['Triager Response']).to include('will fix')
      expect(row['Triage Status']).to eq('concur_with_comment')
      expect(row['Adjudicated']).to eq('true')
    end

    it 'filters by triage_status query param' do
      Review.create!(rule: rule, user: commenter, action: 'comment',
                     comment: 'pending one', triage_status: 'pending')
      get "/components/#{component.id}/export",
          params: { type: 'disposition_csv', triage_status: 'pending' }
      csv = CSV.parse(response.body, headers: true)
      expect(csv.length).to eq(1)
      expect(csv.first['Triage Status']).to eq('pending')
    end

    it 'sets a sensible filename via Content-Disposition' do
      get "/components/#{component.id}/export", params: { type: 'disposition_csv' }
      expect(response.headers['Content-Disposition']).to match(/disposition-matrix.*\.csv/)
    end
  end

  context 'as admin with include_email=true' do
    before { sign_in admin }

    it 'INCLUDES the Commenter Email column' do
      get "/components/#{component.id}/export",
          params: { type: 'disposition_csv', include_email: 'true' }
      csv = CSV.parse(response.body, headers: true)
      expect(csv.first['Commenter Email']).to eq('sarah@example.com')
    end

    it 'OMITS the Commenter Email column when include_email is not set (default safe)' do
      get "/components/#{component.id}/export", params: { type: 'disposition_csv' }
      expect(response.body).not_to include('Commenter Email')
    end
  end

  context 'as viewer (rejected — too loose for PII)' do
    before { sign_in viewer }

    it 'returns 403 — viewers cannot export disposition data' do
      get "/components/#{component.id}/export", params: { type: 'disposition_csv' }
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'unauthenticated' do
    it 'redirects to sign in' do
      get "/components/#{component.id}/export", params: { type: 'disposition_csv' }
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  it 'records an audit entry capturing exporter + include_email flag' do
    sign_in admin
    expect do
      get "/components/#{component.id}/export",
          params: { type: 'disposition_csv', include_email: 'true' }
    end.to change { component.audits.count }.by_at_least(1)
    latest = component.audits.last
    expect(latest.user_id).to eq(admin.id)
  end
end
```

## Step 2: Backend implementation

### 2a. Whitelist + dispatch in components_controller#export

```ruby
# components_controller.rb line 175 — add :disposition_csv
unless %i[csv inspec xccdf json_archive disposition_csv].include?(export_type)
  # ...
end

# Inside the case block:
when :disposition_csv
  # Server-side authorization: include_email is admin-only.
  include_email = params[:include_email] == 'true' &&
                  current_user.can_admin_project?(@component.project)
  csv_data = DispositionMatrixExport.generate(
    component: @component,
    triage_status_filter: params[:triage_status],
    include_email: include_email
  )
  filename = "#{@component.project.name}-#{@component.prefix}-disposition-matrix-#{Date.current}.csv"
  send_data csv_data, type: 'text/csv', disposition: "attachment; filename=\"#{filename}\""
end
```

Add a before_action to gate the disposition_csv export at author tier:

```ruby
before_action :authorize_author_for_disposition_export, only: %i[export]

private

def authorize_author_for_disposition_export
  return unless params[:type].to_s == 'disposition_csv'
  return if current_user.can_author_project?(@component.project)  # or equivalent
  head :forbidden
end
```

### 2b. New module: `app/lib/disposition_matrix_export.rb`

```ruby
# frozen_string_literal: true

require 'csv'

# Generates the DISA disposition matrix CSV for a component's comments.
# One row per top-level review (responding_to_review_id IS NULL); reply
# threads are collapsed into the Triager Response column.
module DispositionMatrixExport
  BASE_HEADERS = [
    'Comment ID', 'Rule', 'SRG ID', 'Section',
    'Commenter Name', 'Comment', 'Posted',
    'Triage Status', 'Triaged By', 'Triaged At', 'Triager Response',
    'Adjudicated', 'Adjudicated By', 'Adjudicated At', 'Duplicate Of'
  ].freeze

  # `include_email: true` adds a Commenter Email column AFTER Commenter
  # Name. Default is FALSE — viewer/author tier can't request it; admin
  # must opt in explicitly via the controller's authorization gate.
  def self.generate(component:, triage_status_filter: nil, include_email: false)
    reviews = top_level_reviews(component, triage_status_filter)
    replies_by_parent = load_replies(reviews.map(&:id))
    headers = build_headers(include_email)

    CSV.generate do |csv|
      csv << headers
      reviews.each do |r|
        responses = (replies_by_parent[r.id] || [])
                      .sort_by(&:created_at)
                      .map { |x| x.comment.to_s.strip }
                      .reject(&:blank?)
                      .join("\n---\n")
        row = [
          r.id, "#{component.prefix}-#{r.rule.rule_id}",
          r.rule.version, r.section.to_s,
          r.user&.name
        ]
        row << r.user&.email if include_email
        row += [
          r.comment, r.created_at.iso8601,
          r.triage_status,
          r.triage_set_by&.name, r.triage_set_at&.iso8601,
          responses,
          r.adjudicated_at.present?,
          r.adjudicated_by&.name, r.adjudicated_at&.iso8601,
          r.duplicate_of_review_id
        ]
        csv << row
      end
    end
  end

  def self.build_headers(include_email)
    return BASE_HEADERS unless include_email
    BASE_HEADERS.dup.insert(BASE_HEADERS.index('Comment'), 'Commenter Email')
  end

  def self.top_level_reviews(component, status_filter)
    scope = Review.top_level_comments
                  .joins(:rule)
                  .merge(Rule.where(component_id: component.id))
                  .preload(:user, :triage_set_by, :adjudicated_by, :rule)
                  .order(created_at: :asc)
    scope = scope.where(triage_status: status_filter) if status_filter.present? && status_filter != 'all'
    scope.to_a
  end

  def self.load_replies(parent_ids)
    Review.where(responding_to_review_id: parent_ids)
          .preload(:user)
          .group_by(&:responding_to_review_id)
  end
end
```

### 2c. Audit logging on export

Inside the controller's `disposition_csv` branch, after generation.
Component is `vulcan_audited` (component.rb:51), so `@component.audits`
is always defined — no guard needed.

```ruby
@component.audits.create!(
  user: current_user,
  action: 'export_disposition_csv',
  audited_changes: {
    triage_status_filter: params[:triage_status],
    include_email: include_email
  }
)
```

(`include_email` should be a boolean computed earlier in the action
from `params[:include_email] == 'true' && current_user.can_admin_project?(@component.project)`
so the audit log records BOTH the user's request and the system's
authorization decision.)

## Step 3: Frontend — download button

In `ComponentComments.vue` triage panel header, add a download button:

```vue
<b-button
  v-b-tooltip.hover
  variant="outline-secondary"
  size="sm"
  :href="dispositionExportUrl"
  title="Download disposition matrix (CSV)"
  class="ml-2"
>
  <b-icon icon="download" /> Export CSV
</b-button>
```

```javascript
computed: {
  dispositionExportUrl() {
    const params = new URLSearchParams();
    params.set('type', 'disposition_csv');
    if (this.filterStatus && this.filterStatus !== 'all') {
      params.set('triage_status', this.filterStatus);
    }
    return `/components/${this.componentId}/export?${params}`;
  },
},
```

(Optional polish: only show the button when `effectivePermissions` is
viewer+; skip for unauthenticated.)

## Step 4: Vocabulary check + lint

```bash
grep -nE "concur|adjudicat" app/lib/disposition_matrix_export.rb \
  | grep -v -i "triage_status\|adjudicated_at\|adjudicated_by"
# ↑ Expect no match — DISA vocabulary in cell values is intentional;
#   the wider grep ensures no friendly-English leaks into raw data.

bundle exec rubocop app/lib/disposition_matrix_export.rb \
                    app/controllers/components_controller.rb
yarn lint app/javascript/components/components/ComponentComments.vue
```

## Step 5: Manual smoke test

1. Open the Container Platform component as a project member
2. Click the new "Export CSV" button on the triage panel
3. Verify the file downloads with a sensible name
4. Open in Excel — confirm headers + row format
5. Verify replies are collapsed into the Triager Response column
6. Add `?triage_status=pending` to the URL — verify only pending rows
7. Sign out and verify the export endpoint rejects unauthenticated access

## Step 6: Commit + DONE rename

Standard pattern.

## Acceptance criteria

- [ ] `:disposition_csv` accepted by `ComponentsController#export`
- [ ] CSV has the locked column schema (15 base columns; +1 if `include_email`)
- [ ] One row per top-level comment; replies collapsed into Triager Response
- [ ] Optional `?triage_status=` filter works
- [ ] Filename includes project name + component prefix + date
- [ ] Authorization: **author tier minimum** — viewer-tier export rejected (403)
- [ ] `include_email=true` adds the Commenter Email column ONLY for admin-tier users; non-admin requests with the param silently omit the column (server-side enforcement)
- [ ] Default export omits `Commenter Email` regardless of role
- [ ] Audit entry recorded on every export, capturing exporter user_id + component_id + triage_status_filter + include_email flag
- [ ] Frontend download button on `ComponentComments` triage panel (visible to author+ only)
- [ ] Button passes through the active triage_status filter
- [ ] No vocabulary leaks (DISA terms in cells, friendly English in column headers only where it doesn't conflict with DISA naming)
- [ ] All specs green
- [ ] Manual smoke test passes — verify each role tier (viewer rejected, author no-email, admin can opt-in to email)

## Out of scope (deferred)

### OSCAL output for the disposition matrix — there's no canonical model

OSCAL (NIST's family of XML/JSON schemas for federal security
automation) has seven main models: Catalog, Profile, Component
Definition, SSP, SAP, SAR, POA&M. **None of them natively model
"public-comment review disposition."**

The closest fit is **SAR** (Assessment Results), specifically its
`<observation>` and `<finding>` elements. You could attempt:

- Each top-level comment → `<observation>` with `description`,
  `subjects`, `collected-at`, `relevant-evidence`
- Adjudication → `<finding>` or `<risk>` with status / disposition
- Commenter identity, triage decisions, reply threads → custom
  `<prop name="..." ns="urn:disa:public-comment-review:...">` extensions

**Why we're not doing that here:**

1. SAR was designed for **assessment outcomes against controls** ("did
   this control pass / fail / partial") — not for **commentary on a
   draft document's wording**. The semantic stretch is large.
2. Custom `<prop>` extensions in a non-standard namespace mean **no
   downstream tool consumes them meaningfully** without DISA-specific
   code. The OSCAL value proposition (interoperability) is lost.
3. DISA today consumes the disposition matrix as **CSV / Excel** —
   that's the working federal-compliance format for this artifact.
4. The OSCAL community has not published a draft-review-disposition
   pattern. Inventing one privately would create maintenance debt
   without payoff.

**If a structured machine-readable disposition output is needed
later**, the right move is one of:

- A **published JSON schema** under a Vulcan / SAF namespace —
  documents the disposition matrix's shape independent of OSCAL
- A **DISA-supplied OSCAL profile or schema** if and when DISA
  formalizes one — Vulcan would adopt that schema once it exists,
  rather than guess

Future engineer reading this: if you find yourself mapping disposition
data into SAR's `<observation>` model, **stop and ask**. That mapping
is a known dead-end.

### Other deferrals

- **OSCAL outputs Vulcan generally COULD produce** (separate from this
  task and from disposition matrices specifically):
  - OSCAL Profile — Vulcan's SRG/STIG as an overlay over a NIST 800-53
    catalog. Maps cleanly. Worth doing as its own workstream.
  - OSCAL Component Definition — what each Component implements.
    Pairs with the Profile.
  - XCCDF → OSCAL Profile bridge — the existing XCCDF export already
    encodes most of this; conversion is mostly schema translation.
  These are bigger workstreams, valuable for downstream federal
  automation, but **separate from the comment-review use case**.
- **Bulk re-export of historical windows** — assume the current window
  is what's exported; multi-window history is a future phase concern.
- **PDF / formatted reports** — CSV satisfies DISA's needs; PDF is a
  presentation layer that can be generated downstream from the CSV.
