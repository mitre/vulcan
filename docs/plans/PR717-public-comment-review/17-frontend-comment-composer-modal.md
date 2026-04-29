# Task 17: CommentComposerModal.vue + dedup banner

**Depends on:** 13, 11
**Estimate:** 45 min Claude-pace
**File touches:**
- `app/javascript/components/components/CommentComposerModal.vue` (new)
- `app/javascript/components/components/CommentDedupBanner.vue` (new helper)
- `spec/javascript/components/components/CommentComposerModal.spec.js` (new)

The composer that opens when a viewer clicks `SectionCommentIcon` (Task 16) or replies to a comment in the thread (Task 18). Section pre-tagged + dedup banner showing existing comments on the same rule + section. Mockups: design §2.6.2, §2.4.

---

## Step 1: Failing spec (concise)

`spec/javascript/components/components/CommentComposerModal.spec.js`:

```javascript
import { describe, it, expect, vi } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import axios from "axios";
import CommentComposerModal from "@/components/components/CommentComposerModal.vue";

vi.mock("axios");

describe("CommentComposerModal", () => {
  const baseProps = { ruleId: 7, componentId: 42, ruleDisplayedName: "CRI-O-000050", initialSection: "check_content" };

  it("renders the section selector with the initial value", () => {
    const w = mount(CommentComposerModal, { propsData: baseProps, stubs: ["b-modal"] });
    expect(w.vm.section).toBe("check_content");
  });

  it("shows a dedup banner with existing comments on the same rule + section", async () => {
    axios.get.mockResolvedValue({
      data: { rows: [
        { id: 99, comment: "Sarah K - existing concern", author_name: "Sarah K", section: "check_content", triage_status: "pending" },
      ], pagination: { total: 1 } },
    });
    const w = mount(CommentComposerModal, { propsData: baseProps });
    await flushPromises();
    expect(w.text()).toContain("1 existing");
  });

  it("re-fetches dedup when section changes", async () => {
    axios.get.mockResolvedValue({ data: { rows: [], pagination: { total: 0 } } });
    const w = mount(CommentComposerModal, { propsData: baseProps });
    await flushPromises();
    axios.get.mockClear();
    w.vm.section = "fixtext";
    await flushPromises();
    expect(axios.get).toHaveBeenCalledWith(
      "/components/42/comments",
      expect.objectContaining({ params: expect.objectContaining({ rule_id: 7, section: "fixtext", triage_status: "all" }) }),
    );
  });

  it("posts to /rules/:id/reviews on submit", async () => {
    axios.post.mockResolvedValue({ data: { toast: "ok" } });
    const w = mount(CommentComposerModal, { propsData: baseProps, mocks: { $bvModal: { hide: vi.fn() } } });
    w.vm.commentText = "my new comment";
    await w.vm.submit();
    expect(axios.post).toHaveBeenCalledWith(
      "/rules/7/reviews",
      expect.objectContaining({
        review: expect.objectContaining({
          action: "comment",
          comment: "my new comment",
          section: "check_content",
          component_id: 42,
        }),
      }),
    );
    expect(w.emitted("posted")).toBeTruthy();
  });

  it("posts with responding_to_review_id when in reply mode", async () => {
    axios.post.mockResolvedValue({ data: { toast: "ok" } });
    const w = mount(CommentComposerModal, {
      propsData: { ...baseProps, replyToReviewId: 99 },
      mocks: { $bvModal: { hide: vi.fn() } },
    });
    w.vm.commentText = "thanks for raising this";
    await w.vm.submit();
    expect(axios.post.mock.calls[0][1].review.responding_to_review_id).toBe(99);
  });
});
```

## Step 2: Run, FAIL

## Step 3: Create `CommentComposerModal.vue`

```vue
<template>
  <b-modal
    id="comment-composer-modal"
    :title="modalTitle"
    size="lg"
    @hidden="onHidden"
    no-close-on-backdrop
  >
    <p class="mb-2">
      <strong>{{ ruleDisplayedName }}</strong>
      <template v-if="!replyToReviewId">
        ·
        <b-form-select
          v-model="section"
          :options="sectionOptions"
          size="sm"
          class="d-inline-block ml-1"
          style="width: auto"
          aria-label="Section to comment on"
        />
      </template>
      <template v-else>
        · Replying to comment #{{ replyToReviewId }}
      </template>
    </p>

    <CommentDedupBanner
      v-if="!replyToReviewId"
      :component-id="componentId"
      :rule-id="ruleId"
      :section="section"
    />

    <b-form-group :description="charCount" class="mb-0">
      <b-form-textarea
        v-model="commentText"
        rows="4"
        :placeholder="placeholder"
        :state="textState"
        aria-label="Comment text"
      />
      <b-form-invalid-feedback v-if="textState === false" role="alert">
        Comment cannot be empty.
      </b-form-invalid-feedback>
    </b-form-group>

    <template #modal-footer="{ cancel }">
      <b-button variant="secondary" @click="cancel()">Cancel</b-button>
      <b-button variant="primary" :disabled="!canSubmit" @click="submit">Submit</b-button>
    </template>
  </b-modal>
</template>

<script>
import axios from "axios";
import AlertMixin from "../../mixins/AlertMixin.vue";
import { SECTION_LABELS } from "../../constants/triageVocabulary";
import CommentDedupBanner from "./CommentDedupBanner.vue";

const COMMENT_MAX = 4000;

export default {
  name: "CommentComposerModal",
  components: { CommentDedupBanner },
  mixins: [AlertMixin],
  props: {
    componentId: { type: [Number, String], required: true },
    ruleId: { type: [Number, String], required: true },
    ruleDisplayedName: { type: String, default: "" },
    initialSection: { type: String, default: null },
    replyToReviewId: { type: [Number, String], default: null },
  },
  data() {
    return {
      section: this.initialSection,
      commentText: "",
    };
  },
  computed: {
    sectionOptions() {
      return [
        { value: null, text: "(general)" },
        ...Object.entries(SECTION_LABELS).map(([value, text]) => ({ value, text })),
      ];
    },
    modalTitle() {
      return this.replyToReviewId ? "Reply to comment" : "New comment";
    },
    placeholder() {
      return this.replyToReviewId
        ? "Reply to this comment..."
        : "Type your comment...";
    },
    textState() {
      if (!this.commentText) return null;
      return this.commentText.trim().length === 0 ? false : null;
    },
    charCount() {
      return `${this.commentText.length} / ${COMMENT_MAX} characters`;
    },
    canSubmit() {
      return this.commentText.trim().length > 0 && this.commentText.length <= COMMENT_MAX;
    },
  },
  methods: {
    async submit() {
      const payload = {
        review: {
          action: "comment",
          comment: this.commentText.trim(),
          component_id: this.componentId,
        },
      };
      if (this.section) payload.review.section = this.section;
      if (this.replyToReviewId) payload.review.responding_to_review_id = this.replyToReviewId;

      try {
        await axios.post(`/rules/${this.ruleId}/reviews`, payload);
        this.$emit("posted");
        this.$bvModal.hide("comment-composer-modal");
        this.commentText = "";
      } catch (error) {
        this.alertOrNotifyResponse(error);
      }
    },
    onHidden() {
      this.commentText = "";
      this.$emit("hidden");
    },
  },
};
</script>
```

## Step 4: Create `CommentDedupBanner.vue`

```vue
<template>
  <div v-if="total > 0" class="mb-3">
    <b-alert show variant="info" class="mb-1">
      <button
        type="button"
        :aria-expanded="String(expanded)"
        :aria-controls="`dedup-list-${componentId}-${ruleId}`"
        class="btn btn-link p-0"
        @click="expanded = !expanded"
      >
        ⓘ {{ total }} existing {{ sectionDisplay }} comment{{ total === 1 ? "" : "s" }} on this rule.
        <span>{{ expanded ? "Hide ▴" : "Read first ▾" }}</span>
      </button>
    </b-alert>
    <ul
      v-show="expanded"
      :id="`dedup-list-${componentId}-${ruleId}`"
      class="list-unstyled mb-0 pl-3"
    >
      <li v-for="row in rows" :key="row.id" class="mb-1">
        <strong>{{ row.author_name }}</strong>
        ({{ relativeTime(row.created_at) }})
        — "{{ truncate(row.comment, 100) }}"
        <a href="#" @click.prevent="$emit('reply', row.id)">[Reply]</a>
      </li>
    </ul>
  </div>
</template>

<script>
import axios from "axios";
import { sectionLabel } from "../../constants/triageVocabulary";

export default {
  name: "CommentDedupBanner",
  props: {
    componentId: { type: [Number, String], required: true },
    ruleId: { type: [Number, String], required: true },
    section: { type: String, default: null },
  },
  data() {
    return { rows: [], total: 0, expanded: false };
  },
  computed: {
    sectionDisplay() {
      return this.section ? sectionLabel(this.section) : "";
    },
  },
  watch: {
    section: { immediate: true, handler: "fetch" },
    ruleId: "fetch",
  },
  methods: {
    truncate(s, n) { return s && s.length > n ? `${s.slice(0, n)}…` : s; },
    relativeTime(iso) { return iso ? new Date(iso).toLocaleDateString() : ""; },
    async fetch() {
      try {
        const params = { rule_id: this.ruleId, triage_status: "all" };
        if (this.section) params.section = this.section;
        const { data } = await axios.get(`/components/${this.componentId}/comments`, { params });
        this.rows = data.rows.slice(0, 5);
        this.total = data.pagination.total;
      } catch {
        this.rows = []; this.total = 0;
      }
    },
  },
};
</script>
```

## Step 5: Run specs + lint

```bash
pnpm vitest run spec/javascript/components/components/CommentComposerModal.spec.js
pnpm vitest run
yarn lint
```

## Step 6: Commit

```bash
cat > /tmp/msg-17.md <<'EOF'
feat: CommentComposerModal + CommentDedupBanner

The composer is the single Vue component used for: (a) viewer posting a
new comment from a SectionCommentIcon, (b) replying to a comment from
the thread, (c) general (un-sectioned) comment.

Section pre-tagged from the trigger; user can change before submit.
Dedup banner shows up to 5 existing comments on the same rule + section
with [Reply] links — the cheap dedup mechanism per design §2.4.

Strong-params-aligned payload: action=comment + section (XCCDF key) +
responding_to_review_id when in reply mode.

Aria semantics on the disclosure expand (aria-expanded + aria-controls)
per WCAG 4.1.2.

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add app/javascript/components/components/CommentComposerModal.vue \
        app/javascript/components/components/CommentDedupBanner.vue \
        spec/javascript/components/components/CommentComposerModal.spec.js
git commit -F /tmp/msg-17.md
rm /tmp/msg-17.md
git mv docs/plans/PR717-public-comment-review/17-frontend-comment-composer-modal.md \
       docs/plans/PR717-public-comment-review/17-frontend-comment-composer-modal-DONE.md
git commit -m "chore: mark plan task 17 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```
