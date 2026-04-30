# Task 24: Mark-as-duplicate decision in the existing triage modal

**Depends on:** 15 (CommentTriageModal scaffolded)
**Estimate:** 60 min Claude-pace
**File touches:**
- `app/javascript/components/components/CommentTriageModal.vue` (add decision option + canonical picker)
- `app/javascript/components/components/CanonicalCommentPicker.vue` (new — embedded picker)
- `app/controllers/reviews_controller.rb` (extend triage endpoint to accept `duplicate_of_review_id`)
- `app/policies/review_policy.rb` if used, or model validations (cross-rule canonical resolves to same component)
- `spec/requests/reviews_controller_spec.rb` (extend triage endpoint specs)
- `spec/javascript/components/components/CommentTriageModal.spec.js` (extend)
- `spec/javascript/components/components/CanonicalCommentPicker.spec.js` (new)

## Why this task exists

The DB schema already supports duplicate marking
(`triage_status='duplicate'` + `duplicate_of_review_id`); only the UI
is missing. Triagers regularly find the same concern raised on
multiple rules (cross-rule) or on the same rule under different
sections. Mark-as-duplicate gives explicit consolidation: pick a
canonical, link the duplicate to it, adjudication on the canonical
implicitly closes the duplicate.

This is the **single biggest cross-rule consolidation tool** for
triagers during the live Container SRG window — and the schema +
backend support are ready; only the UI is new.

## Verified facts

- `Review#triage_status` already has `'duplicate'` in
  `Review::TRIAGE_STATUSES` (Task 04 migration; verify via
  `db/migrate/*review_lifecycle*.rb`)
- `Review#duplicate_of_review_id` column exists with FK to reviews
  (verify via `db/schema.rb`)
- `TriageStatusBadge.vue` already renders `Duplicate of #X` label when
  `status === 'duplicate'` and `duplicate_of_id` is provided — no
  frontend display work needed beyond the picker
- Existing PATCH `/reviews/:id/triage` endpoint accepts `triage_status`
  + `triager_response` — needs to also accept `duplicate_of_review_id`
- The triage modal already has a decision-radios layout (per Task 15);
  add 'duplicate' as a new radio option that reveals the picker

## Design decisions

- **Picker scope**: same component only. A duplicate canonical must
  live in the same component (cross-component duplicate marking is a
  data integrity concern). Validate server-side.
- **Picker UX**: search by author name, comment text, rule
  displayed_name, or comment id (paste). Show top 5 most recent
  matching comments by default. Each row shows
  `[rule_name] author — "snippet"` + `created_at`.
- **No self-marking**: a comment cannot be its own canonical.
  Validate client-side (disable own row in picker) and server-side.
- **No transitive chains**: comment X cannot be marked as duplicate
  of comment Y if Y is itself marked as duplicate. Resolve to the
  ultimate canonical or reject. Server-side check.
- **Adjudication propagation**: when the canonical is adjudicated,
  the duplicate's effective_adjudicated_at returns the canonical's
  via a model method (no data mutation, just a derived attribute).
- **Audit comment required**: duplicate marking is a triage decision;
  the audit comment captures *why* this was marked as a duplicate.

## Step 1: Failing spec — backend

Extend `spec/requests/reviews_controller_spec.rb`:

```ruby
describe 'PATCH /reviews/:id/triage with duplicate marking' do
  let(:component) { create(:component) }
  let(:project) { component.project }
  let(:author) { create(:user) }
  before { Membership.create!(user: author, membership: project, role: 'author') }

  let(:rule_a) { create(:rule, component: component) }
  let(:rule_b) { create(:rule, component: component) }
  let(:canonical) do
    Review.create!(rule: rule_a, user: author, action: 'comment',
                   comment: 'canonical concern', triage_status: 'pending')
  end
  let(:duplicate) do
    Review.create!(rule: rule_b, user: author, action: 'comment',
                   comment: 'same concern', triage_status: 'pending')
  end

  before { sign_in author }

  it 'sets triage_status=duplicate + duplicate_of_review_id when triaged as duplicate' do
    patch "/reviews/#{duplicate.id}/triage",
          params: { triage_status: 'duplicate',
                    duplicate_of_review_id: canonical.id,
                    audit_comment: 'same as #X by Sarah' },
          as: :json
    expect(response).to have_http_status(:ok)
    duplicate.reload
    expect(duplicate.triage_status).to eq('duplicate')
    expect(duplicate.duplicate_of_review_id).to eq(canonical.id)
  end

  it 'rejects self-reference' do
    patch "/reviews/#{duplicate.id}/triage",
          params: { triage_status: 'duplicate',
                    duplicate_of_review_id: duplicate.id,
                    audit_comment: '...' },
          as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejects cross-component canonical' do
    other_component = create(:component, project: project)
    other_rule = create(:rule, component: other_component)
    other_canonical = Review.create!(rule: other_rule, user: author, action: 'comment',
                                     comment: 'x', triage_status: 'pending')
    patch "/reviews/#{duplicate.id}/triage",
          params: { triage_status: 'duplicate',
                    duplicate_of_review_id: other_canonical.id,
                    audit_comment: '...' },
          as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)['toast']['message']).to include(/same component/i)
  end

  it 'rejects chained duplicates (canonical itself is a duplicate)' do
    chained = Review.create!(rule: rule_a, user: author, action: 'comment',
                             comment: 'chained', triage_status: 'duplicate',
                             duplicate_of_review_id: canonical.id)
    patch "/reviews/#{duplicate.id}/triage",
          params: { triage_status: 'duplicate',
                    duplicate_of_review_id: chained.id,
                    audit_comment: '...' },
          as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'allows re-marking to a different canonical' do
    duplicate.update!(triage_status: 'duplicate', duplicate_of_review_id: canonical.id)
    new_canonical = Review.create!(rule: rule_a, user: author, action: 'comment',
                                   comment: 'better canonical', triage_status: 'pending')
    patch "/reviews/#{duplicate.id}/triage",
          params: { triage_status: 'duplicate',
                    duplicate_of_review_id: new_canonical.id,
                    audit_comment: 'better canonical found' },
          as: :json
    expect(response).to have_http_status(:ok)
    duplicate.reload
    expect(duplicate.duplicate_of_review_id).to eq(new_canonical.id)
  end
end
```

## Step 2: Implement — backend

In `app/controllers/reviews_controller.rb`'s `triage` action,
extend the params + validation:

```ruby
# Inside triage action
if triage_status == 'duplicate'
  canonical_id = params[:duplicate_of_review_id]
  return render_validation_error('Mark-as-duplicate requires a canonical comment') if canonical_id.blank?
  return render_validation_error('A comment cannot be its own canonical') if canonical_id.to_i == @review.id
  canonical = Review.find_by(id: canonical_id)
  return render_validation_error('Canonical comment not found') unless canonical
  return render_validation_error('Canonical must be in the same component') unless canonical.rule.component_id == @review.rule.component_id
  return render_validation_error('Canonical itself is a duplicate; pick the ultimate canonical') if canonical.triage_status == 'duplicate'
  @review.duplicate_of_review_id = canonical.id
end
```

Plus a model method on Review for derived adjudication:

```ruby
# app/models/review.rb
def effective_adjudicated_at
  return adjudicated_at if adjudicated_at.present?
  return nil unless triage_status == 'duplicate' && duplicate_of_review_id.present?
  duplicate_of&.adjudicated_at
end

belongs_to :duplicate_of, class_name: 'Review',
                          foreign_key: :duplicate_of_review_id,
                          optional: true
```

Update Component#paginated_comments / blueprints to surface
`effective_adjudicated_at` (so the triage table can show "Closed via
canonical #X" on duplicates whose canonical has been adjudicated).

## Step 3: Failing spec — frontend picker

`spec/javascript/components/components/CanonicalCommentPicker.spec.js`:

```javascript
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import axios from "axios";
import CanonicalCommentPicker from "@/components/components/CanonicalCommentPicker.vue";

vi.mock("axios");

describe("CanonicalCommentPicker", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    axios.get.mockResolvedValue({
      data: {
        rows: [
          { id: 99, rule_id: 7, rule_displayed_name: "CRI-O-000050",
            author_name: "Sarah K", comment: "TLS 1.2 EOL by 2025",
            section: "vuln_discussion", created_at: "2026-04-26T10:00:00Z" },
        ],
        pagination: { total: 1 },
      },
    });
  });

  it("fetches comments scoped to the same component", async () => {
    const w = mount(CanonicalCommentPicker, {
      localVue,
      propsData: { componentId: 8, excludeReviewId: 50 },
    });
    await w.vm.$nextTick();
    expect(axios.get).toHaveBeenCalledWith(
      "/components/8/comments",
      expect.objectContaining({ params: expect.objectContaining({ triage_status: "all" }) }),
    );
  });

  it("excludes the review being marked from the candidate list", async () => {
    axios.get.mockResolvedValueOnce({
      data: {
        rows: [
          { id: 50, rule_id: 7, rule_displayed_name: "CRI-O-000050",
            author_name: "Self", comment: "This is the duplicate itself",
            section: null, created_at: "2026-04-25T10:00:00Z" },
          { id: 99, rule_id: 7, rule_displayed_name: "CRI-O-000050",
            author_name: "Sarah K", comment: "TLS 1.2 EOL",
            section: "vuln_discussion", created_at: "2026-04-26T10:00:00Z" },
        ],
        pagination: { total: 2 },
      },
    });
    const w = mount(CanonicalCommentPicker, {
      localVue,
      propsData: { componentId: 8, excludeReviewId: 50 },
    });
    await w.vm.$nextTick();
    expect(w.text()).not.toContain("This is the duplicate itself");
    expect(w.text()).toContain("TLS 1.2 EOL");
  });

  it("emits 'selected' with the review id when a candidate is clicked", async () => {
    const w = mount(CanonicalCommentPicker, {
      localVue,
      propsData: { componentId: 8, excludeReviewId: 50 },
    });
    await w.vm.$nextTick();
    await w.find('[data-test="canonical-candidate-99"]').trigger("click");
    expect(w.emitted("selected")[0]).toEqual([99]);
  });

  it("filters by free-text search via the q param", async () => {
    const w = mount(CanonicalCommentPicker, {
      localVue,
      propsData: { componentId: 8, excludeReviewId: 50 },
    });
    await w.setData({ query: "TLS" });
    await w.vm.$nextTick();
    // Debounced — wait
    await new Promise((r) => setTimeout(r, 350));
    expect(axios.get).toHaveBeenLastCalledWith(
      "/components/8/comments",
      expect.objectContaining({ params: expect.objectContaining({ q: "TLS" }) }),
    );
  });

  it("excludes reviews that are themselves duplicates (no chained)", async () => {
    axios.get.mockResolvedValueOnce({
      data: {
        rows: [
          { id: 99, triage_status: "duplicate", duplicate_of_review_id: 50,
            comment: "already a dup", rule_displayed_name: "X", author_name: "A",
            created_at: "2026-04-26T10:00:00Z" },
          { id: 100, triage_status: "pending", comment: "fresh canonical",
            rule_displayed_name: "Y", author_name: "B", created_at: "2026-04-27T10:00:00Z" },
        ],
        pagination: { total: 2 },
      },
    });
    const w = mount(CanonicalCommentPicker, {
      localVue,
      propsData: { componentId: 8, excludeReviewId: 50 },
    });
    await w.vm.$nextTick();
    expect(w.text()).not.toContain("already a dup");
    expect(w.text()).toContain("fresh canonical");
  });
});
```

## Step 4: Implement — picker

`app/javascript/components/components/CanonicalCommentPicker.vue`:

```vue
<template>
  <div>
    <b-form-input
      v-model="query"
      placeholder="Search by author, rule, or comment text..."
      debounce="300"
      aria-label="Search canonical candidates"
      size="sm"
      class="mb-2"
    />
    <div v-if="loading" class="text-muted small"><b-spinner small /> Loading…</div>
    <ul v-else class="list-unstyled mb-0" style="max-height: 280px; overflow-y: auto">
      <li v-if="filteredRows.length === 0" class="text-muted small">
        No matching canonical candidates.
      </li>
      <li
        v-for="row in filteredRows"
        :key="row.id"
        :data-test="`canonical-candidate-${row.id}`"
        class="border rounded p-2 mb-1 clickable"
        @click="$emit('selected', row.id)"
      >
        <div>
          <strong>{{ row.rule_displayed_name }}</strong>
          <SectionLabel v-if="row.section" :section="row.section" class="badge badge-light ml-1" />
          <small class="text-muted ml-2">— {{ row.author_name }}</small>
        </div>
        <div class="small">{{ truncate(row.comment, 120) }}</div>
        <small class="text-muted">{{ friendlyDateTime(row.created_at) }}</small>
      </li>
    </ul>
  </div>
</template>

<script>
import axios from "axios";
import DateFormatMixin from "../../mixins/DateFormatMixin.vue";
import SectionLabel from "../shared/SectionLabel.vue";

export default {
  name: "CanonicalCommentPicker",
  components: { SectionLabel },
  mixins: [DateFormatMixin],
  props: {
    componentId: { type: [Number, String], required: true },
    excludeReviewId: { type: [Number, String], required: true },
  },
  data() {
    return { rows: [], loading: false, query: "" };
  },
  computed: {
    filteredRows() {
      // Drop self + chained duplicates (defense in depth — server also rejects)
      return this.rows.filter(
        (r) =>
          r.id !== Number(this.excludeReviewId) &&
          r.triage_status !== "duplicate",
      );
    },
  },
  watch: {
    query() {
      this.fetch();
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    truncate(s, n) {
      return s && s.length > n ? `${s.slice(0, n)}…` : s;
    },
    async fetch() {
      this.loading = true;
      try {
        const params = { triage_status: "all", per_page: 25 };
        if (this.query) params.q = this.query;
        const { data } = await axios.get(`/components/${this.componentId}/comments`, { params });
        this.rows = data.rows;
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>
```

## Step 5: Wire into CommentTriageModal

Add 'duplicate' radio + reveal picker. On submit, send
`duplicate_of_review_id` along with `triage_status='duplicate'`.

## Step 6: Run all impacted specs, lint, vocabulary check, commit + DONE rename

```bash
pnpm vitest run spec/javascript/components/components/
bundle exec rspec spec/requests/reviews_controller_spec.rb
yarn lint
bundle exec rubocop --autocorrect-all app/controllers/reviews_controller.rb app/models/review.rb
grep -nE "concur|adjudicat" app/javascript/components/components/CanonicalCommentPicker.vue \
  | grep -v -i "triage-status\|adjudicated_at"
```

Commit message + DONE rename per the standard pattern.

## Acceptance criteria

- [ ] PATCH /reviews/:id/triage accepts `duplicate_of_review_id` when `triage_status='duplicate'`
- [ ] Server rejects: missing canonical, self-reference, cross-component, chained duplicates
- [ ] Server allows re-marking to a different canonical (idempotent)
- [ ] CommentTriageModal exposes 'duplicate' decision option
- [ ] CanonicalCommentPicker fetches scoped to same component
- [ ] Picker excludes the review being marked + already-duplicate rows
- [ ] Picker supports text search via the q param (debounced)
- [ ] Review#effective_adjudicated_at derives from canonical when self.adjudicated_at is nil
- [ ] Triage table shows "Closed via canonical #X" on duplicates whose canonical has been adjudicated
- [ ] Audit comment is captured on the duplicate-marking action
- [ ] No vocabulary leaks (DISA terms only in storage/API; friendly UI labels)
- [ ] All specs green
