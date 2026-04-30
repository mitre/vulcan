# Task 18: RuleReviews.vue thread updates — section/status badges + response nesting

**Depends on:** 13
**Estimate:** 30 min Claude-pace
**File touches:**
- `app/javascript/components/rules/RuleReviews.vue` (modify — currently 78 lines, simple flat list)
- `spec/javascript/components/rules/RuleReviews.spec.js` (extend or create)

**Verified facts (read before editing):**
- `RuleReviews.vue` is **78 lines**, very simple: header with count badge, a `v-for` over `shownReviews` (sorted by created_at desc), Show older / Show fewer buttons.
- Each review row currently renders: `name` + `actionDescriptions[action]` + `friendlyDateTime(created_at)` + `comment`.
- It uses `DateFormatMixin`, `AlertMixin`, `FormMixin`. `actionDescriptions` is imported from `constants/terminology`.
- Pagination is local: `numShownReviews` data, default 2, +/- 2 via buttons.

**The patch is small and additive — preserve existing show-older pagination.** Add:
1. Section badge (`<SectionLabel>`) inline in the header row
2. Status badge (`<TriageStatusBadge>`) inline in the header row
3. Response nesting (filter by `responding_to_review_id`) — render replies indented under their parent
4. Section filter dropdown ABOVE the thread

Mockup: design §2.6.4.

---

## Step 1: Failing spec

Append to existing `spec/javascript/components/rules/RuleReviews.spec.js`:

```javascript
describe("RuleReviews — section + triage badges", () => {
  const reviewsWithLifecycle = [
    {
      id: 142, action: "comment", comment: "Check text issue", section: "check_content",
      user_name: "John Doe", created_at: "2026-04-27T10:00:00Z",
      triage_status: "pending", responding_to_review_id: null, adjudicated_at: null,
    },
    {
      id: 143, action: "comment", comment: "Will adopt the spirit", section: "check_content",
      user_name: "Aaron Lippold", created_at: "2026-04-28T10:00:00Z",
      triage_status: "pending", responding_to_review_id: 142, adjudicated_at: null,
    },
    {
      id: 144, action: "comment", comment: "Severity too low", section: "severity",
      user_name: "Sarah K", created_at: "2026-04-26T10:00:00Z",
      triage_status: "non_concur", responding_to_review_id: null, adjudicated_at: null,
    },
  ];

  it("renders section badges on top-level comments", () => {
    const w = mount(RuleReviews, { propsData: { rule: { reviews: reviewsWithLifecycle } } });
    expect(w.text()).toContain("Check");
    expect(w.text()).toContain("Severity");
  });

  it("renders TriageStatusBadge for each top-level comment", () => {
    const w = mount(RuleReviews, { propsData: { rule: { reviews: reviewsWithLifecycle } } });
    const badges = w.findAllComponents({ name: "TriageStatusBadge" });
    expect(badges.length).toBe(2); // top-level only
  });

  it("nests responses under their parent (responding_to_review_id)", () => {
    const w = mount(RuleReviews, { propsData: { rule: { reviews: reviewsWithLifecycle } } });
    const html = w.html();
    // Response should be visually associated with its parent — exact selector
    // depends on existing component structure; verify via text proximity
    const johnIdx = html.indexOf("John Doe");
    const aaronIdx = html.indexOf("Aaron Lippold");
    const sarahIdx = html.indexOf("Sarah K");
    // Aaron's reply (responds to John #142) should appear after John's comment
    // and before Sarah's unrelated comment (assuming chronological top-level + nested replies)
    expect(johnIdx).toBeLessThan(aaronIdx);
  });

  it("filters thread by section via dropdown", async () => {
    const w = mount(RuleReviews, { propsData: { rule: { reviews: reviewsWithLifecycle } } });
    w.vm.sectionFilter = "severity";
    await w.vm.$nextTick();
    expect(w.text()).not.toContain("Check text issue");
    expect(w.text()).toContain("Severity too low");
  });
});
```

## Step 2: Run, FAIL

## Step 3: Update `RuleReviews.vue` — additive patch

The existing component is short (78 lines). Preserve:
- The `<strong>Reviews & Comments</strong>` header + count badge
- The `numShownReviews` pagination + "Show older" / "Show fewer" buttons
- The existing imports (DateFormatMixin, AlertMixin, FormMixin) and `actionDescriptions`

Add four things:
1. `<SectionCommentIcon>` and `<TriageStatusBadge>` imports + components registration
2. A `sectionFilter` data field + `<b-form-select>` ABOVE the v-for, with options from `SECTION_LABELS`
3. Modify the v-for so it iterates only TOP-LEVEL comments (`responding_to_review_id == null`) and is filtered by section
4. Inside each top-level review's render, nest responses found via `responsesFor(parent.id)` (indented)

Below is the **target structure** — the diff against the actual file should be additive, not a rewrite. Read the current 78-line file and integrate.

```vue
<template>
  <div>
    <div class="mb-2 d-flex align-items-center">
      <strong>Reviews &amp; Comments</strong>
      <b-badge pill variant="info" class="ml-1">{{ rule.reviews.length }}</b-badge>
      <b-form-select
        v-model="sectionFilter"
        :options="sectionFilterOptions"
        size="sm"
        class="ml-auto"
        style="max-width: 180px"
        aria-label="Filter by section"
      />
    </div>

    <div v-for="parent in topLevelFiltered" :key="parent.id" class="mb-3">
      <p class="mb-0 d-flex align-items-center">
        <strong>{{ parent.name }}</strong>
        <small class="text-muted ml-2">{{ actionDescriptions[parent.action] }}</small>
        <SectionLabel v-if="parent.section" :section="parent.section" class="badge badge-light ml-2" />
        <TriageStatusBadge
          v-if="parent.triage_status"
          :status="parent.triage_status"
          :adjudicated-at="parent.adjudicated_at"
          :duplicate-of-id="parent.duplicate_of_review_id"
          class="ml-2"
        />
      </p>
      <p class="mb-1">
        <small class="text-muted">{{ friendlyDateTime(parent.created_at) }}</small>
      </p>
      <p class="mb-0 white-space-pre-wrap">{{ parent.comment }}</p>

      <!-- Nested responses -->
      <div
        v-for="response in responsesFor(parent.id)"
        :key="response.id"
        class="ml-4 mt-2 pl-3 border-left border-info"
      >
        <p class="mb-0">
          <strong>{{ response.name }}</strong>
          <small class="text-muted ml-2">responding to ↑</small>
        </p>
        <p class="mb-1">
          <small class="text-muted">{{ friendlyDateTime(response.created_at) }}</small>
        </p>
        <p class="mb-0 white-space-pre-wrap">{{ response.comment }}</p>
      </div>
    </div>

    <p v-if="rule.reviews.length === 0" class="text-muted small">No reviews or comments yet.</p>
    <p v-else-if="topLevelFiltered.length === 0" class="text-muted small">No comments match this filter.</p>

    <!-- existing Show older / Show fewer buttons go here, but pagination now on topLevelFiltered length -->
  </div>
</template>

<script>
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";
import { ACTION_DESCRIPTIONS } from "../../constants/terminology";
import { SECTION_LABELS } from "../../constants/triageVocabulary";
import SectionLabel from "../shared/SectionLabel.vue";
import TriageStatusBadge from "../shared/TriageStatusBadge.vue";

export default {
  name: "RuleReviews",
  components: { SectionLabel, TriageStatusBadge },
  mixins: [DateFormatMixinVue, AlertMixinVue, FormMixinVue],
  props: {
    effectivePermissions: { type: String, required: false },
    currentUserId: { type: Number, required: false },
    rule: { type: Object, required: true },
  },
  data: function () {
    return {
      numShownReviews: 2,
      actionDescriptions: ACTION_DESCRIPTIONS,
      sectionFilter: "all",
    };
  },
  computed: {
    sectionFilterOptions() {
      return [
        { value: "all", text: "All sections" },
        { value: "(general)", text: "(general)" },
        ...Object.entries(SECTION_LABELS).map(([value, text]) => ({ value, text })),
      ];
    },
    topLevelComments() {
      return [...this.rule.reviews]
        .filter((r) => r.action === "comment" && r.responding_to_review_id == null)
        .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    },
    topLevelFiltered() {
      const list = this.topLevelComments;
      let filtered = list;
      if (this.sectionFilter === "(general)") {
        filtered = list.filter((r) => r.section == null);
      } else if (this.sectionFilter !== "all") {
        filtered = list.filter((r) => r.section === this.sectionFilter);
      }
      return filtered.slice(0, this.numShownReviews);
    },
  },
  methods: {
    responsesFor(parentId) {
      return (this.rule.reviews || []).filter((r) => r.responding_to_review_id === parentId);
    },
  },
};
</script>
```

The Show older / Show fewer buttons (existing lines 21-33 in current file) keep their existing form — they increment/decrement `numShownReviews`, which now slices `topLevelFiltered` instead of the original `shownReviews`.

## Step 4: Run, lint, vocabulary check

```bash
pnpm vitest run spec/javascript/components/rules/RuleReviews.spec.js
yarn lint
grep -nE "concur|adjudicat" app/javascript/components/rules/RuleReviews.vue | grep -v triage-status
```

## Step 5: Commit

```bash
cat > /tmp/msg-18.md <<'EOF'
feat: section + status badges + response nesting in RuleReviews thread

The per-rule review thread now reflects the public-comment-review
lifecycle:
- SectionLabel badge next to each top-level comment showing its section
- TriageStatusBadge showing pending/concur/decline/etc. status (friendly
  labels via triageVocabulary.js)
- Responses (Reviews with responding_to_review_id) nested under their
  parent with visual indentation
- Section filter dropdown at the top — viewers and triagers can isolate
  Check-only / Fix-only conversation when needed

No new endpoints — the existing rule.reviews payload from
ComponentBlueprint already includes the new lifecycle columns once Tasks
03 and 05 land.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add app/javascript/components/rules/RuleReviews.vue \
        spec/javascript/components/rules/RuleReviews.spec.js
git commit -F /tmp/msg-18.md
rm /tmp/msg-18.md
git mv docs/plans/PR717-public-comment-review/18-frontend-rule-reviews-thread-badges.md \
       docs/plans/PR717-public-comment-review/18-frontend-rule-reviews-thread-badges-DONE.md
git commit -m "chore: mark plan task 18 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```
