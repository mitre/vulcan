# Task 24: Mark-as-duplicate decision in the existing triage modal

**Depends on:** 15 (CommentTriageModal scaffolded)
**Estimate:** 45 min Claude-pace (most validators ALREADY EXIST in the model — see Verified facts; net-new work is the picker UI + chained-duplicate rejection + paginated_comments query extension)
**File touches:**
- `app/javascript/components/components/CommentTriageModal.vue` (replace numeric `duplicateOfId` input with the new picker)
- `app/javascript/components/components/CanonicalCommentPicker.vue` (new — embedded picker)
- `app/models/review.rb` (add chained-duplicate rejection validator)
- `app/models/component.rb` (extend `paginated_comments` query to also search rule displayed_name + author name when picker is open — see Step 0)
- `spec/models/review_spec.rb` (extend with chained-duplicate test)
- `spec/javascript/components/components/CommentTriageModal.spec.js` (extend — replace duplicateOfId integer input with picker integration)
- `spec/javascript/components/components/CanonicalCommentPicker.spec.js` (new)

## Verified facts (READ FIRST — much of this task is already implemented)

The 2026-04-29 review session uncovered that **most of the backend
work for this task already exists**. Don't rebuild it.

**Already implemented in `app/models/review.rb` (do NOT re-add):**
- `belongs_to :duplicate_of, class_name: 'Review', foreign_key: :duplicate_of_review_id, optional: true` (lines 13-14)
- `validate :no_self_duplicate_reference` (line 98) — forbids `id == duplicate_of_review_id`
- `validate :duplicate_status_requires_target` (line 96) — forbids `triage_status='duplicate'` without a `duplicate_of_review_id`
- `validate :duplicate_of_must_be_same_component` (line 100, body at lines 288-305) — same-component constraint
- `before_save :auto_set_adjudicated_for_terminal_statuses` (line 102, body at lines 307-313) — ALREADY auto-sets `adjudicated_at` when `triage_status` enters the `TERMINAL_AUTO_ADJUDICATE_STATUSES` set (review.rb:27), and `'duplicate'` is in that set. **No `effective_adjudicated_at` derivation needed** — `adjudicated_at` is set on the duplicate the moment it's marked.
- `Review::TRIAGE_STATUSES` contains `'duplicate'`

**Already implemented in `app/controllers/reviews_controller.rb` (do NOT re-add):**
- `triage` action accepts `duplicate_of_review_id` in `triage_params` and assigns it (line 108 + the `triage_params` permit list)
- `set_project_from_review` before_action sets `@project` (line 420)
- Validation rejection for blank target on `triage_status='duplicate'` (line 457)

**Already implemented in `app/javascript/components/shared/TriageStatusBadge.vue`:**
- `Duplicate of #X` label rendering (lines 33-34)

**What is genuinely missing (THIS IS THE TASK):**
1. Server-side rejection of **chained** duplicates: a comment marked as duplicate of a canonical that is itself a duplicate. Add a model validator for this.
2. The picker UI (`CanonicalCommentPicker.vue`) — Vue component that fetches candidates and emits a selected review id.
3. CommentTriageModal integration — replace the existing numeric `duplicateOfId` input field (Task 15) with `<CanonicalCommentPicker>` so triagers can search rather than paste.
4. `Component#paginated_comments` query: extend the `q` (search) param to ALSO match rule displayed_name + author name (currently only matches `reviews.comment ILIKE` — see component.rb:623-626). Without this, the picker's search promise (find by rule name or author) is unkept.

## Design decisions (revised)

- **Picker scope**: same component only. The model validator
  `duplicate_of_must_be_same_component` (review.rb:288-305) already
  enforces this; the picker just queries
  `/components/<componentId>/comments` directly.
- **Picker UX**: search field that POSTs `q` to the existing
  `paginated_comments` endpoint. Show recent matching comments,
  each row: `[rule_name] author — "snippet"` + `created_at`. Click
  → emit `selected(review_id)`.
- **Chained duplicates rejected**: if the picked canonical itself has
  `triage_status='duplicate'`, reject with a friendly message
  ("Pick the ultimate canonical, not another duplicate"). Implement
  as a model validator and a client-side picker filter (defense in
  depth — server is authoritative).
- **No self-marking**: client-side (disable own row in picker) and
  server-side (existing `no_self_duplicate_reference` validator at
  review.rb:98).
- **Adjudication on duplicate is automatic**: triage_status='duplicate'
  is in `Review::TERMINAL_AUTO_ADJUDICATE_STATUSES` (review.rb:27), so
  `auto_set_adjudicated_for_terminal_statuses` (lines 307-313) sets
  `adjudicated_at` on save. The triage table can show "Closed
  (Duplicate of #X)" by checking `triage_status='duplicate' &&
  duplicate_of_review_id` directly — no derived attribute needed.
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

## Step 2: Backend — minimal additions

The triage controller and Review model already do most of this. The
ONLY backend changes:

### 2a. New model validator: chained-duplicate rejection

Add to `app/models/review.rb` (alongside the existing duplicate
validators around line 96-100):

```ruby
validate :duplicate_of_must_not_be_a_duplicate

private

def duplicate_of_must_not_be_a_duplicate
  return unless triage_status == 'duplicate' && duplicate_of_review_id.present?
  canonical = duplicate_of  # uses existing belongs_to at line 13-14
  return unless canonical&.triage_status == 'duplicate'
  errors.add(:duplicate_of_review_id,
             'cannot point to another duplicate — pick the ultimate canonical')
end
```

The other failure modes (self-reference, cross-component, blank target)
are ALREADY handled by existing validators. Don't re-implement.

### 2b. Picker search — client-side filter (PRIMARY APPROACH)

**Decision (after agent review):** keep the backend `q` filter narrow
(comment text only — existing behavior at component.rb:623-626) and
have `CanonicalCommentPicker.vue` do **client-side secondary
filtering** on the loaded rows for author/rule matching.

Why client-side:

- Backend SQL extension to join `users` + concat-prefix on `base_rules.rule_id`
  is brittle (Postgres-specific `||`, fragile prefix interpolation,
  multi-table left_joins on an already-joined scope). Risk-to-reward
  is poor.
- The picker fetches `per_page: 25` rows. Filtering 25 rows in JS by
  author name + rule displayed_name is instant.
- No backend change → no risk of regressing the existing triage queue
  search behavior.

In `CanonicalCommentPicker.vue`'s `filteredRows` computed, add the
secondary filter:

```javascript
filteredRows() {
  const q = this.query.toLowerCase().trim();
  return this.rows
    .filter((r) => r.id !== Number(this.excludeReviewId))
    .filter((r) => r.triage_status !== "duplicate")
    .filter((r) => {
      if (!q) return true;
      // Backend already filtered by comment text; widen client-side
      // to also match author name + rule displayed_name.
      return (
        (r.comment || "").toLowerCase().includes(q) ||
        (r.author_name || "").toLowerCase().includes(q) ||
        (r.rule_displayed_name || "").toLowerCase().includes(q)
      );
    });
}
```

The `q` param still goes to the backend so we don't load all comments
on the component; backend narrows by comment text, frontend widens to
author/rule. If the user's search term is in the rule name but NOT in
any comment, the backend may return 0 rows — to handle that case,
ALSO call the picker's fetch with no `q` param when the user's search
term is non-empty and yields 0 backend matches (a small "didn't find
in comments — searching across all rule names" fallback). Optional
polish; not required for v1.

**Out of scope** (deferred): extending the backend `q` filter to
include author/rule. If the live window surfaces "I can't find this
comment by author name even though I know it exists," promote to a
follow-up.

### 2c. Validation error response pattern

The controller does NOT have a `render_validation_error` helper. The
project's pattern is:

```ruby
render json: { toast: { title: 'Validation Error', message: errors_array, variant: 'danger' } },
       status: :unprocessable_entity
```

When the model save fails (the new chained-duplicate validator fires),
the existing `triage` controller action already handles
`ActiveRecord::RecordInvalid` and renders the toast — no controller
changes needed.

## Step 2bis: Failing model spec for chained-duplicate

Add to `spec/models/review_spec.rb` (or create if absent):

```ruby
describe 'chained-duplicate rejection' do
  let(:component) { create(:component) }
  let(:rule) { create(:rule, component: component) }
  let(:user) { create(:user) }
  let(:canonical) do
    Review.create!(rule: rule, user: user, action: 'comment',
                   comment: 'real canon', triage_status: 'pending')
  end
  let(:already_dup) do
    Review.create!(rule: rule, user: user, action: 'comment',
                   comment: 'A', triage_status: 'duplicate',
                   duplicate_of_review_id: canonical.id)
  end

  it 'rejects marking as duplicate of a comment that is itself a duplicate' do
    chained = Review.new(rule: rule, user: user, action: 'comment',
                         comment: 'B', triage_status: 'duplicate',
                         duplicate_of_review_id: already_dup.id)
    expect(chained).not_to be_valid
    expect(chained.errors[:duplicate_of_review_id])
      .to include(/ultimate canonical/)
  end

  it 'allows marking as duplicate of a non-duplicate canonical' do
    new_dup = Review.new(rule: rule, user: user, action: 'comment',
                         comment: 'C', triage_status: 'duplicate',
                         duplicate_of_review_id: canonical.id)
    expect(new_dup).to be_valid
  end
end
```

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

- [ ] New model validator `duplicate_of_must_not_be_a_duplicate` rejects chained duplicates
- [ ] Existing validators `no_self_duplicate_reference`, `duplicate_status_requires_target`, `duplicate_of_must_be_same_component` continue to work (regression-only assertion)
- [ ] PATCH /reviews/:id/triage with triage_status=duplicate + duplicate_of_review_id succeeds (no controller changes — already supported)
- [ ] Server allows re-marking to a different canonical (idempotent)
- [ ] CanonicalCommentPicker fetches scoped to same component via existing /components/:id/comments endpoint
- [ ] Picker excludes the review being marked + already-duplicate rows (defense in depth — server is authoritative)
- [ ] Picker supports text search; backend `q` filter extended to include author name + rule displayed_name (or client-side secondary filter — pick whichever is cleaner)
- [ ] CommentTriageModal: existing numeric `duplicateOfId` input replaced by `<CanonicalCommentPicker>`
- [ ] Triage table renders "Closed (Duplicate of #X)" using existing `auto_set_adjudicated_for_terminal_statuses` callback — no derived `effective_adjudicated_at` needed
- [ ] Audit comment is captured on the duplicate-marking action
- [ ] No vocabulary leaks (DISA terms only in storage/API; friendly UI labels)
- [ ] All specs green
