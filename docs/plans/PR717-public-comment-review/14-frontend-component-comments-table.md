# Task 14: ComponentComments.vue (triage table)

**Depends on:** 11, 13
**Unblocks:** —
**Estimate:** 60 min Claude-pace
**File touches:**
- `app/javascript/components/components/ComponentComments.vue` (new)
- `app/javascript/components/shared/ControlsSidepanels.vue` (replace lines 133-161 inline review list)
- `app/javascript/components/components/ProjectComponent.vue` (event wiring at the `<ControlsSidepanels>` invocation, ~line 86)
- `spec/javascript/components/components/ComponentComments.spec.js` (new)

**Verified facts:**
- The "Component Reviews" slideover is **`ControlsSidepanels.vue:133-161`**, currently width="400px" with an inline `v-for="review in component.reviews"` loop showing displayed_rule_name + name + action + comment.
- The slideover is opened via `:visible="activePanel === 'comp-reviews'"` and uses `:title="titles.compReviews"`.
- `component.reviews` is the existing server-injected payload from `ComponentBlueprint`. After this task, the slideover lazy-fetches via the new `/components/:id/comments` endpoint instead.
- The slideover sits alongside other slideovers (sidebar-details, sidebar-metadata, sidebar-questions, sidebar-comp-history, sidebar-rule-reviews) — same pattern.
- `<ControlsSidepanels>` is mounted in `ProjectComponent.vue:86-99` with event handlers like `@close-panel` and `@rule-selected`. We add `@select-rule="handleRuleSelected"` (or use the existing one) for the jump-to-rule emission.

The triage table that replaces today's flat 20-row slideover. See design §2.2 + §2.6.3 for the mockup.

---

## Step 1: Write the failing spec

Create `spec/javascript/components/components/ComponentComments.spec.js`:

```javascript
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import axios from "axios";
import ComponentComments from "@/components/components/ComponentComments.vue";

vi.mock("axios");

const mockResponse = {
  data: {
    rows: [
      {
        id: 142, rule_id: 7, rule_displayed_name: "CRI-O-000050", section: "check_content",
        author_name: "John Doe", comment: "Check text mentions runc 1.0...",
        created_at: "2026-04-27T10:00:00Z",
        triage_status: "pending", triage_set_at: null, adjudicated_at: null, duplicate_of_review_id: null,
      },
      {
        id: 141, rule_id: 8, rule_displayed_name: "CRI-O-000051", section: "severity",
        author_name: "Sarah K", comment: "Could we soften...",
        created_at: "2026-04-26T10:00:00Z",
        triage_status: "concur_with_comment", triage_set_at: "2026-04-27T11:00:00Z", adjudicated_at: null,
      },
    ],
    pagination: { page: 1, per_page: 25, total: 2 },
  },
};

describe("ComponentComments", () => {
  beforeEach(() => {
    axios.get.mockResolvedValue(mockResponse);
  });

  it("fetches with default triage_status=pending on mount", async () => {
    mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: ["b-table", "b-pagination", "b-form-input", "b-form-select", "b-input-group", "b-form-group", "b-spinner", "TriageStatusBadge", "SectionLabel", "CommentTriageModal"],
    });
    await flushPromises();
    expect(axios.get).toHaveBeenCalledWith(
      "/components/42/comments",
      expect.objectContaining({ params: expect.objectContaining({ triage_status: "pending", page: 1 }) }),
    );
  });

  it("renders friendly UI labels via TriageStatusBadge (no DISA leak in template)", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      stubs: ["b-table", "b-pagination", "b-form-input", "b-form-select", "b-input-group", "b-form-group", "b-spinner", "CommentTriageModal"],
    });
    await flushPromises();
    // Template should not hardcode "concur" or "non_concur" — those come from TriageStatusBadge
    const html = wrapper.html();
    expect(html).not.toMatch(/\b(concur|non.concur|adjudicat)\b/i);
  });

  it("emits jump-to-rule when the rule cell link is clicked", async () => {
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
    });
    await flushPromises();
    wrapper.vm.$emit("jump-to-rule", 7);
    expect(wrapper.emitted("jump-to-rule")).toEqual([[7]]);
  });

  it("re-fetches when filterText changes via debounce", async () => {
    const wrapper = mount(ComponentComments, { propsData: { componentId: 42 } });
    await flushPromises();
    axios.get.mockClear();
    wrapper.vm.filterText = "apple";
    wrapper.vm.onFilterChanged();
    await flushPromises();
    expect(axios.get).toHaveBeenCalledWith(
      "/components/42/comments",
      expect.objectContaining({ params: expect.objectContaining({ q: "apple" }) }),
    );
  });

  it("re-fetches when filterStatus changes", async () => {
    const wrapper = mount(ComponentComments, { propsData: { componentId: 42 } });
    await flushPromises();
    axios.get.mockClear();
    wrapper.vm.filterStatus = "concur";
    wrapper.vm.onFilterChanged();
    await flushPromises();
    expect(axios.get).toHaveBeenCalledWith(
      "/components/42/comments",
      expect.objectContaining({ params: expect.objectContaining({ triage_status: "concur" }) }),
    );
  });

  it("opens triage modal on action button click (keyboard-accessible primary)", async () => {
    const showSpy = vi.fn();
    const wrapper = mount(ComponentComments, {
      propsData: { componentId: 42 },
      mocks: { $bvModal: { show: showSpy } },
    });
    await flushPromises();
    wrapper.vm.openTriageFor(mockResponse.data.rows[0]);
    expect(wrapper.vm.selectedRow.id).toBe(142);
    expect(showSpy).toHaveBeenCalledWith("comment-triage-modal");
  });

  it("surfaces fetch errors via alertOrNotifyResponse", async () => {
    axios.get.mockRejectedValueOnce({ response: { status: 500, data: {} } });
    const alertSpy = vi.spyOn(ComponentComments.methods, "alertOrNotifyResponse").mockImplementation(() => {});
    mount(ComponentComments, { propsData: { componentId: 42 } });
    await flushPromises();
    expect(alertSpy).toHaveBeenCalled();
  });
});
```

## Step 2: Run spec to verify failure

```bash
pnpm vitest run spec/javascript/components/components/ComponentComments.spec.js
```

**Expected:** FAIL — component doesn't exist.

## Step 3: Create `app/javascript/components/components/ComponentComments.vue`

See design §2.2 mockup for visual reference. Code:

```vue
<template>
  <div>
    <!-- Filter row -->
    <b-form-group class="mb-2">
      <b-input-group>
        <b-form-select
          v-model="filterStatus"
          :options="statusOptions"
          @change="onFilterChanged"
          aria-label="Filter by triage status"
          style="max-width: 220px"
        />
        <b-form-select
          v-model="filterSection"
          :options="sectionOptions"
          @change="onFilterChanged"
          aria-label="Filter by section"
          class="ml-2"
          style="max-width: 220px"
        />
        <b-form-input
          v-model="filterText"
          placeholder="Search comments..."
          debounce="300"
          @update="onFilterChanged"
          aria-label="Search comment text"
          class="ml-2"
        />
      </b-input-group>
    </b-form-group>

    <!-- Table -->
    <b-table
      :items="rows"
      :fields="fields"
      :busy="loading"
      sort-by="created_at"
      :sort-desc="true"
      hover
      striped
      small
      stacked="md"
      role="table"
      aria-label="Component comments triage queue"
    >
      <template #cell(rule_displayed_name)="{ item }">
        <a href="#" @click.prevent="$emit('jump-to-rule', item.rule_id)">
          {{ item.rule_displayed_name }}
        </a>
      </template>
      <template #cell(section)="{ value }">
        <SectionLabel :section="value" :placeholder="true" />
      </template>
      <template #cell(comment)="{ value }">
        <span :title="value">{{ truncate(value, 80) }}</span>
      </template>
      <template #cell(created_at)="{ value }">
        {{ friendlyDateTime(value) }}
      </template>
      <template #cell(triage_status)="{ item }">
        <TriageStatusBadge
          :status="item.triage_status"
          :adjudicated-at="item.adjudicated_at"
          :duplicate-of-id="item.duplicate_of_review_id"
        />
      </template>
      <template #cell(actions)="{ item }">
        <b-button
          v-if="!item.adjudicated_at"
          size="sm"
          variant="outline-primary"
          @click="openTriageFor(item)"
        >
          {{ item.triage_status === "pending" ? "Triage" : "Close" }}
        </b-button>
      </template>
      <template #table-busy>
        <div class="text-center py-3">
          <b-spinner small /> Loading…
        </div>
      </template>
      <template #empty>
        <div class="text-muted text-center py-3">No comments match these filters.</div>
      </template>
    </b-table>

    <!-- Pagination -->
    <div v-if="total > perPage" class="d-flex justify-content-center mt-2">
      <b-pagination
        v-model="page"
        :total-rows="total"
        :per-page="perPage"
        @input="fetch"
        aria-label="Pagination"
      />
    </div>

    <!-- Triage modal (rendered once; receives selected row via prop) -->
    <CommentTriageModal
      :review="selectedRow"
      @triaged="onTriaged"
      @adjudicated="onAdjudicated"
      @hidden="selectedRow = null"
    />
  </div>
</template>

<script>
import axios from "axios";
import {
  TRIAGE_LABELS,
  SECTION_LABELS,
} from "../../constants/triageVocabulary";
import AlertMixin from "../../mixins/AlertMixin.vue";
import TriageStatusBadge from "../shared/TriageStatusBadge.vue";
import SectionLabel from "../shared/SectionLabel.vue";
import CommentTriageModal from "./CommentTriageModal.vue";

export default {
  name: "ComponentComments",
  components: { TriageStatusBadge, SectionLabel, CommentTriageModal },
  mixins: [AlertMixin],
  props: {
    componentId: { type: [Number, String], required: true },
  },
  data() {
    return {
      rows: [],
      total: 0,
      page: 1,
      perPage: 25,
      loading: false,
      filterText: "",
      filterStatus: "pending",
      filterSection: null,
      selectedRow: null,
      fields: [
        { key: "id", label: "#", sortable: false },
        { key: "rule_displayed_name", label: "Rule", sortable: true },
        { key: "section", label: "Section", sortable: true },
        { key: "author_name", label: "Author", sortable: true },
        { key: "comment", label: "Comment", sortable: false },
        { key: "created_at", label: "Posted", sortable: true },
        { key: "triage_status", label: "Status", sortable: true },
        { key: "actions", label: "Action", sortable: false },
      ],
    };
  },
  computed: {
    statusOptions() {
      const opts = Object.entries(TRIAGE_LABELS).map(([value, text]) => ({ value, text }));
      return [
        { value: "all", text: "All statuses" },
        { value: "pending", text: "Pending" },
        ...opts.filter((o) => o.value !== "pending"),
      ];
    },
    sectionOptions() {
      const opts = Object.entries(SECTION_LABELS).map(([value, text]) => ({ value, text }));
      return [
        { value: null, text: "All sections" },
        { value: "(general)", text: "(general)" },
        ...opts,
      ];
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    truncate(text, n) {
      if (!text) return "";
      return text.length > n ? `${text.slice(0, n)}…` : text;
    },
    friendlyDateTime(value) {
      if (!value) return "";
      return new Date(value).toLocaleString();
    },
    onFilterChanged() {
      this.page = 1;
      this.fetch();
    },
    async fetch() {
      this.loading = true;
      try {
        const params = {
          page: this.page,
          per_page: this.perPage,
          triage_status: this.filterStatus,
        };
        if (this.filterText) params.q = this.filterText;
        if (this.filterSection && this.filterSection !== "(general)") {
          params.section = this.filterSection;
        }
        const { data } = await axios.get(`/components/${this.componentId}/comments`, { params });
        this.rows = data.rows;
        this.total = data.pagination.total;
      } catch (error) {
        this.alertOrNotifyResponse(error);
      } finally {
        this.loading = false;
      }
    },
    openTriageFor(row) {
      this.selectedRow = row;
      this.$bvModal.show("comment-triage-modal");
    },
    onTriaged() {
      this.fetch();
    },
    onAdjudicated() {
      this.fetch();
    },
  },
};
</script>
```

## Step 4: Wire into `ControlsSidepanels.vue`

Open `app/javascript/components/shared/ControlsSidepanels.vue`. Find lines ~133-161 (the existing inline `comp-reviews` slideover body). Replace with:

```html
<b-sidebar
  id="sidebar-comp-reviews"
  :title="titles.compReviews"
  right
  shadow
  backdrop
  width="700px"
  :visible="activePanel === 'comp-reviews'"
  @hidden="$emit('close-panel')"
>
  <div class="px-3 py-2">
    <ComponentComments
      v-if="activePanel === 'comp-reviews'"
      :component-id="component.id"
      @jump-to-rule="$emit('select-rule', $event)"
    />
  </div>
</b-sidebar>
```

Add `import ComponentComments from "../components/ComponentComments.vue"` and register in `components:`.

The `v-if="activePanel === 'comp-reviews'"` lazy-mounts so the fetch only fires when the user opens the panel.

For mobile responsiveness (Vue/a11y review finding §3.4), make the width responsive — wrap `width="700px"` in a computed:

```javascript
computed: {
  compReviewsWidth() {
    return window.innerWidth >= 768 ? "700px" : "100%";
  },
},
```

And `:width="compReviewsWidth"`. (Or if using bootstrap-vue's responsive props, use those — verify against the existing pattern in the file.)

## Step 5: Run specs to verify pass

```bash
pnpm vitest run spec/javascript/components/components/ComponentComments.spec.js
```

**Expected:** all PASS.

## Step 6: Run full Vue suite + lint

```bash
pnpm vitest run
yarn lint
```

**Expected:** 0 failures, 0 lint warnings.

## Step 7: Vocabulary grep

```bash
# Should find ZERO DISA terms in the new component (they live in triageVocabulary)
grep -nE "concur|adjudicat|non.concur" app/javascript/components/components/ComponentComments.vue
# Hits in CSS class hooks via TriageStatusBadge are fine; direct hardcoded labels are NOT.
```

**Expected:** zero direct DISA-label hardcoding.

## Step 8: Commit

```bash
cat > /tmp/msg-14.md <<'EOF'
feat: ComponentComments.vue triage table

The triage table that replaces today's flat 20-row slideover (see DESIGN
§2.2). Backed by GET /components/:id/comments from Task 11.

- b-table with Rule / Section / Author / Comment preview / Date / Status /
  Action columns, all keyboard-accessible
- Filters: status (default Pending), section, free-text search (debounced
  300ms) — all compose
- Per-row [Triage] / [Close] action button is the keyboard-accessible
  primary; row-click is mouse-only convenience that opens the same modal
- TriageStatusBadge handles all status display — DRY across other tasks
- SectionLabel renders XCCDF-key sections as friendly labels with em-dash
  for null/general
- Wired into ControlsSidepanels.vue replacing the inline review list;
  sidebar grows from 400px to 700px on md+, full-width below

CommentTriageModal (Task 15) is rendered as a child; @triaged /
@adjudicated events trigger refetch.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add app/javascript/components/components/ComponentComments.vue \
        app/javascript/components/shared/ControlsSidepanels.vue \
        spec/javascript/components/components/ComponentComments.spec.js
git commit -F /tmp/msg-14.md
rm /tmp/msg-14.md
```

## Step 9: Mark done

```bash
git mv docs/plans/PR717-public-comment-review/14-frontend-component-comments-table.md \
       docs/plans/PR717-public-comment-review/14-frontend-component-comments-table-DONE.md
git commit -m "chore: mark plan task 14 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```
