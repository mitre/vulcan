# Task 30: Edit comment section — retroactive section tagging

**Depends on:** 15 (CommentTriageModal scaffolded), 23 (FilterDropdown for section picker)
**Estimate:** 30 min Claude-pace
**File touches:**
- `app/controllers/reviews_controller.rb` (extend triage params to accept `section` change OR add a new `update_section` action — see Design decisions)
- `app/models/review.rb` (add `:section` to `vulcan_audited only:` list — currently it's not audited)
- `app/javascript/components/components/CommentTriageModal.vue` (add "Edit Section" picker)
- `spec/requests/reviews_controller_spec.rb` (extend)
- `spec/models/review_spec.rb` (audit-trail test)
- `spec/javascript/components/components/CommentTriageModal.spec.js` (extend)

## Why this task exists

`Review#section` is currently set only at comment creation via
`CommentComposerModal`. There's no path to change it later. This is a
gap for two scenarios:

1. **Legacy comments** — comments created before this update don't have
   a `section` value at all (NULL → "(general)" in display). Triagers
   should be able to assign the right section retroactively so the
   comment lands in the per-section thread and surfaces in dedup
   correctly.
2. **Misplaced section at creation** — a commenter clicked the wrong
   section icon (e.g. Check when they meant Fix) and the section is
   wrong. Triagers should be able to fix it as part of triage rather
   than rejecting the comment.

This is **comment-metadata editing** — different from Task 24
(mark-as-duplicate, which is about cross-rule consolidation) and
Task 26 (move-to-rule, deferred). Section editing is rule-scoped, no
cross-rule semantics, no replies-follow concern.

## Verified facts

- `Review` schema: `section` is a `t.string` column with no DB-level
  constraint on the value beyond what model validators enforce
  (db/schema.rb:259 — verify before TDD).
- `Review#vulcan_audited only:` (review.rb:38) is currently
  `%i[triage_status adjudicated_by_id duplicate_of_review_id comment]`.
  **`:section` is NOT audited today.** Add it.
- Section vocabulary lives in `app/javascript/constants/triageVocabulary.js`
  (`SECTION_LABELS`) and the matching backend `en.yml` (Task 03).
  Reuse the same options the composer uses.
- `CommentTriageModal.vue` already has the modal structure with the
  decision picker. The Edit Section action slots in as another admin/
  triager-only control alongside the existing decision UI.

## Design decisions

- **Authorization tier**: triager-tier (author+) — same as the triage
  decision itself. Section is metadata that the triager curates as
  part of the disposition record.
- **Audit comment required**: section changes are auditable. Add
  `:section` to `vulcan_audited only:` so the change is captured in
  the audit log alongside an `audit_comment` setter.
- **No cross-rule semantics** — section is rule-scoped. No need to
  validate against the rule's structure (the section vocabulary is
  rule-agnostic; "(general)" is always valid).
- **Section value validation** — must be one of the canonical XCCDF
  keys (or null for general). Reuse the existing `SECTION_LABELS`
  keys; reject anything else.
- **Endpoint shape**: extend the existing `triage` action to accept a
  `section` param OR add a dedicated `update_section` action. **Pick
  the dedicated action** — keeps `triage` focused on the disposition
  decision; section editing is a separate metadata concern that may
  happen without a triage decision.
  - Route: `PATCH /reviews/:id/section`
  - Params: `section` (XCCDF key or null), `audit_comment` (required)
- **UI placement**: "Edit Section" link/button next to the existing
  section badge in the CommentTriageModal header. Click reveals the
  FilterDropdown picker + audit comment field. Save → PATCH the
  endpoint → modal updates the section badge.
- **Idempotent**: re-saving the same section is a no-op (no audit
  record created if section didn't change).

## Step 1: Failing model spec — section auditing

```ruby
# spec/models/review_spec.rb
describe 'section auditing (PR #717 Task 30)' do
  let(:component) { create(:component) }
  let(:rule) { create(:rule, component: component) }
  let(:user) { create(:user) }

  it 'records an audit when section changes' do
    review = Review.create!(rule: rule, user: user, action: 'comment',
                            comment: 'x', triage_status: 'pending',
                            section: nil)
    expect do
      review.audit_comment = 'tagging as Check'
      review.update!(section: 'check_content')
    end.to change { review.audits.count }.by_at_least(1)

    latest = review.audits.last
    expect(latest.audited_changes['section']).to eq([nil, 'check_content'])
    expect(latest.comment).to include('tagging as Check')
  end
end
```

## Step 2: Implement — add `:section` to audit list

```ruby
# app/models/review.rb line 38
vulcan_audited only: %i[
  triage_status adjudicated_by_id duplicate_of_review_id comment section
]
```

## Step 3: Failing request spec — `PATCH /reviews/:id/section`

```ruby
describe 'PATCH /reviews/:id/section' do
  let(:component) { create(:component) }
  let(:project) { component.project }
  let(:rule) { create(:rule, component: component) }
  let(:author) { create(:user) }
  let(:viewer) { create(:user) }
  let(:commenter) { create(:user) }

  before do
    Membership.create!(user: author, membership: project, role: 'author')
    Membership.create!(user: viewer, membership: project, role: 'viewer')
    Membership.create!(user: commenter, membership: project, role: 'viewer')
  end

  let!(:review) do
    Review.create!(rule: rule, user: commenter, action: 'comment',
                   comment: 'misclassified', triage_status: 'pending',
                   section: nil)
  end

  context 'as triager (author tier — minimum allowed)' do
    before { sign_in author }

    it 'updates the section and records an audit comment' do
      patch "/reviews/#{review.id}/section",
            params: { section: 'check_content',
                      audit_comment: 'tagging as Check after triager review' },
            as: :json
      expect(response).to have_http_status(:ok)
      review.reload
      expect(review.section).to eq('check_content')
      expect(review.audits.last.comment).to include('tagging as Check')
    end

    it 'accepts null to clear the section back to general' do
      review.update!(section: 'check_content')
      patch "/reviews/#{review.id}/section",
            params: { section: nil, audit_comment: 'general after all' },
            as: :json
      expect(response).to have_http_status(:ok)
      expect(review.reload.section).to be_nil
    end

    it 'rejects an invalid section key' do
      patch "/reviews/#{review.id}/section",
            params: { section: 'bogus_key', audit_comment: 'x' },
            as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects when audit_comment is blank' do
      patch "/reviews/#{review.id}/section",
            params: { section: 'check_content', audit_comment: '' },
            as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'is idempotent when section is unchanged (no audit record)' do
      review.update!(section: 'check_content')
      expect do
        patch "/reviews/#{review.id}/section",
              params: { section: 'check_content', audit_comment: 'noop' },
              as: :json
      end.not_to(change { review.reload.audits.count })
    end
  end

  context 'as viewer (rejected)' do
    before { sign_in viewer }
    it 'returns 403' do
      patch "/reviews/#{review.id}/section",
            params: { section: 'check_content', audit_comment: 'x' },
            as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
```

## Step 4: Implement — controller action + route

```ruby
# config/routes.rb
resources :reviews, only: [] do
  member do
    patch :triage
    patch :adjudicate
    patch :withdraw
    patch :section  # NEW
  end
end

# app/controllers/reviews_controller.rb
before_action :set_review_for_section, only: %i[section]
before_action :authorize_author_for_section, only: %i[section]

VALID_SECTION_KEYS = %w[
  title severity status fixtext check_content
  vuln_discussion disa_metadata vendor_comments
  artifact_description xccdf_metadata
].freeze

def section
  audit_comment = params[:audit_comment].to_s.strip
  if audit_comment.blank?
    return render json: validation_toast('Audit comment required'),
                  status: :unprocessable_entity
  end

  new_section = params.key?(:section) ? params[:section].presence : @review.section
  unless new_section.nil? || VALID_SECTION_KEYS.include?(new_section)
    return render json: validation_toast("Invalid section key: #{new_section}"),
                  status: :unprocessable_entity
  end

  if new_section == @review.section
    # Idempotent — no-op
    return render json: { section: @review.section }, status: :ok
  end

  @review.audit_comment = "Section change: #{audit_comment}"
  @review.update!(section: new_section)
  render json: { section: @review.section }
end

private

def set_review_for_section
  @review = Review.includes(:rule).find(params[:id])
end

def authorize_author_for_section
  return if current_user.can_author_project?(@review.rule.component.project)
  head :forbidden
end
```

(Adapt the helpers to whatever toast/auth pattern the controller actually uses.)

## Step 5: Frontend — Edit Section action in CommentTriageModal

In `CommentTriageModal.vue`, near the existing `<SectionLabel>` badge,
add an inline edit affordance:

```vue
<span>
  <SectionLabel :section="review.section" class="badge badge-light" />
  <b-button
    v-if="canEditSection"
    variant="link"
    size="sm"
    class="p-0 ml-1"
    @click="sectionEditMode = true"
  >
    <b-icon icon="pencil" /> Edit
  </b-button>
</span>

<div v-if="sectionEditMode" class="mt-2 p-2 border rounded bg-light">
  <FilterDropdown
    v-model="newSection"
    :options="sectionOptions"
    aria-label="Pick a new section for this comment"
  />
  <b-form-textarea
    v-model="sectionAuditComment"
    rows="2"
    placeholder="Why are you changing the section? (audit log)"
    size="sm"
    class="mt-2"
  />
  <div class="mt-2">
    <b-button size="sm" @click="cancelSectionEdit">Cancel</b-button>
    <b-button
      size="sm"
      variant="primary"
      :disabled="!sectionAuditComment.trim()"
      @click="submitSectionChange"
    >
      Save section
    </b-button>
  </div>
</div>
```

Plus the script-side computed `canEditSection` (`role_gte_to author`),
`sectionOptions` (reuse the same shape as `CommentComposerModal`),
and the `submitSectionChange` method that PATCHes the endpoint and
emits a refresh signal to the parent.

## Step 6: Vocabulary check + lint + commit

```bash
grep -nE "concur|adjudicat" app/javascript/components/components/CommentTriageModal.vue \
  | grep -v -i "triage-status\|adjudicated_at\|adjudicatedAt\|TriageStatusBadge"
yarn lint app/javascript/components/components/CommentTriageModal.vue
bundle exec rubocop --autocorrect-all app/controllers/reviews_controller.rb app/models/review.rb
pnpm vitest run spec/javascript/components/components/CommentTriageModal.spec.js
bundle exec rspec spec/requests/reviews_controller_spec.rb spec/models/review_spec.rb
```

Standard commit + DONE rename pattern.

## Acceptance criteria

- [ ] `:section` added to `Review`'s `vulcan_audited only:` list
- [ ] PATCH `/reviews/:id/section` accepts `section` (XCCDF key or null) + `audit_comment`
- [ ] Validates section key against the canonical XCCDF list
- [ ] Rejects blank audit_comment with 422
- [ ] Idempotent on no-change (no audit record, returns 200)
- [ ] Authorization: author tier minimum (viewers rejected with 403)
- [ ] Audit log captures the section change with the audit comment
- [ ] CommentTriageModal exposes "Edit Section" affordance for author+ users
- [ ] Saves call PATCH /reviews/:id/section; modal refreshes with new section
- [ ] No vocabulary leaks
- [ ] All specs green
- [ ] Manual smoke: edit a comment's section from null → check_content; verify in audit log + per-section thread

## Why this is in scope (not deferred)

- Schema is ready — only the audit list needs `:section` added (1 line)
- Endpoint is small (~30 lines) and follows the established triage pattern
- UI extension to existing CommentTriageModal — no new component
- Live-window value: as the Container SRG window progresses, triagers
  WILL find some comments tagged in the wrong section. Without this
  task, they have to either (a) reject and ask the commenter to repost
  (rude / loses the audit trail) or (b) console-edit the section
  (out-of-band, breaks the in-app workflow). Both are worse than a
  small in-modal action.

## Out of scope (deferred)

- Bulk section editing (edit many at once) — admin escape hatch, file
  for follow-up if the live window surfaces real demand.
- Section history viewer (see all section changes for a comment over
  time) — `audits.where(audited_changes: ...)` already exposes this
  via the existing audit log; UI surfacing is a follow-up nice-to-have.
