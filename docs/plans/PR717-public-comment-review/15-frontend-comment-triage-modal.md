# Task 15: CommentTriageModal.vue

**Depends on:** 10, 11, 13
**Estimate:** 60 min Claude-pace
**File touches:**
- `app/javascript/components/components/CommentTriageModal.vue` (new)
- `spec/javascript/components/components/CommentTriageModal.spec.js` (new)

The modal a triager uses to make a decision. Mockup in design §2.3. Pedagogical: this is the **one place** that shows DISA terms in parens after the friendly label.

---

## Step 1: Failing spec

`spec/javascript/components/components/CommentTriageModal.spec.js`:

```javascript
import { describe, it, expect, vi } from "vitest";
import { mount } from "@vue/test-utils";
import axios from "axios";
import CommentTriageModal from "@/components/components/CommentTriageModal.vue";

vi.mock("axios");

const sampleReview = {
  id: 142, rule_id: 7, rule_displayed_name: "CRI-O-000050", section: "check_content",
  author_name: "John Doe", author_email: "john@redhat.com",
  comment: "Check text mentions runc 1.0...",
  created_at: "2026-04-27T10:00:00Z",
  triage_status: "pending", adjudicated_at: null,
};

describe("CommentTriageModal", () => {
  it("renders the comment + section context", () => {
    const w = mount(CommentTriageModal, { propsData: { review: sampleReview }, stubs: ["b-modal", "b-button", "b-form-group", "b-form-radio", "b-form-textarea"] });
    expect(w.text()).toContain("CRI-O-000050");
    expect(w.text()).toContain("Check"); // friendly section label
    expect(w.text()).toContain("John Doe");
  });

  it("shows decision radios with friendly label + DISA term in parens", () => {
    const w = mount(CommentTriageModal, { propsData: { review: sampleReview }, stubs: ["b-modal"] });
    const html = w.html();
    expect(html).toMatch(/Accept[^<]*Concur\)/);
    expect(html).toMatch(/Decline[^<]*Non-concur\)/);
  });

  it("requires response_comment when triage_status=non_concur (client-side)", async () => {
    const w = mount(CommentTriageModal, { propsData: { review: sampleReview } });
    w.vm.triageStatus = "non_concur";
    w.vm.responseComment = "";
    expect(w.vm.canSave).toBe(false);
    w.vm.responseComment = "we already addressed differently";
    expect(w.vm.canSave).toBe(true);
  });

  it("posts to /reviews/:id/triage on save", async () => {
    axios.patch.mockResolvedValue({ data: { review: { ...sampleReview, triage_status: "concur" } } });
    const w = mount(CommentTriageModal, { propsData: { review: sampleReview }, mocks: { $bvModal: { hide: vi.fn() } } });
    w.vm.triageStatus = "concur";
    w.vm.responseComment = "thanks";
    await w.vm.saveTriage(false);
    expect(axios.patch).toHaveBeenCalledWith(
      "/reviews/142/triage",
      expect.objectContaining({ triage_status: "concur", response_comment: "thanks" }),
    );
    expect(w.emitted("triaged")).toBeTruthy();
  });

  it("'Save & close' fires triage AND adjudicate", async () => {
    axios.patch
      .mockResolvedValueOnce({ data: { review: { ...sampleReview, triage_status: "concur" } } })
      .mockResolvedValueOnce({ data: { review: { ...sampleReview, triage_status: "concur", adjudicated_at: "now" } } });
    const w = mount(CommentTriageModal, { propsData: { review: sampleReview }, mocks: { $bvModal: { hide: vi.fn() } } });
    w.vm.triageStatus = "concur";
    w.vm.responseComment = "done";
    await w.vm.saveTriage(true);
    expect(axios.patch).toHaveBeenCalledTimes(2);
    expect(axios.patch.mock.calls[1][0]).toBe("/reviews/142/adjudicate");
    expect(w.emitted("adjudicated")).toBeTruthy();
  });

  it("disables 'Save & close' for terminal-by-rule statuses (informational, duplicate, withdrawn, needs_clarification)", () => {
    const w = mount(CommentTriageModal, { propsData: { review: sampleReview } });
    ["informational", "duplicate", "needs_clarification"].forEach((status) => {
      w.vm.triageStatus = status;
      expect(w.vm.canSaveAndClose).toBe(false);
    });
    w.vm.triageStatus = "concur";
    expect(w.vm.canSaveAndClose).toBe(true);
  });
});
```

## Step 2: Run, verify FAIL

```bash
pnpm vitest run spec/javascript/components/components/CommentTriageModal.spec.js
```

## Step 3: Create `CommentTriageModal.vue`

```vue
<template>
  <b-modal
    id="comment-triage-modal"
    size="lg"
    :title="modalTitle"
    @hidden="$emit('hidden')"
    no-close-on-backdrop
  >
    <template v-if="review">
      <p class="mb-1">
        <strong>{{ review.rule_displayed_name }}</strong>
        · Section: <SectionLabel :section="review.section" />
        · <a :href="ruleEditorLink" target="_blank">Open in rule editor ↗</a>
      </p>
      <p class="mb-1 text-muted">
        <strong>{{ review.author_name }}</strong> ·
        {{ review.author_email }} ·
        posted {{ relativeTime(review.created_at) }}
      </p>
      <blockquote class="border-left pl-3 py-2 mb-3 bg-light">
        {{ review.comment }}
      </blockquote>

      <b-form-group label="Decision" :label-for="'triage-radios'" stacked>
        <b-form-radio v-model="triageStatus" name="triage" value="concur">
          Accept (Concur) — incorporate as suggested
        </b-form-radio>
        <b-form-radio v-model="triageStatus" name="triage" value="concur_with_comment">
          Accept with changes (Concur with comment) — incorporate with changes
        </b-form-radio>
        <b-form-radio v-model="triageStatus" name="triage" value="non_concur">
          Decline (Non-concur) — won't incorporate (response required)
        </b-form-radio>
        <b-form-radio v-model="triageStatus" name="triage" value="duplicate">
          Duplicate of:
          <b-form-input v-if="triageStatus === 'duplicate'" v-model.number="duplicateOfId" type="number" placeholder="comment #" size="sm" class="d-inline-block ml-2" style="width: 120px" />
        </b-form-radio>
        <b-form-radio v-model="triageStatus" name="triage" value="informational">
          Informational — note acknowledged, no action required
        </b-form-radio>
        <b-form-radio v-model="triageStatus" name="triage" value="needs_clarification">
          Needs clarification — round-trip with commenter
        </b-form-radio>
      </b-form-group>

      <b-form-group label="Response to commenter (visible in their thread + 'My Comments' page)" :description="nonConcurHint">
        <b-form-textarea v-model="responseComment" rows="3" :placeholder="responsePlaceholder" :state="responseState" />
        <b-form-invalid-feedback v-if="responseState === false" role="alert">
          Decline requires a response — explain why so the commenter understands.
        </b-form-invalid-feedback>
      </b-form-group>
    </template>

    <template #modal-footer="{ cancel }">
      <b-button variant="secondary" @click="cancel()">Cancel</b-button>
      <b-button variant="outline-primary" :disabled="!canSave" @click="saveTriage(false)">Save decision</b-button>
      <b-button variant="primary" :disabled="!canSave || !canSaveAndClose" @click="saveTriage(true)">Save & close</b-button>
    </template>
  </b-modal>
</template>

<script>
import axios from "axios";
import AlertMixin from "../../mixins/AlertMixin.vue";
import SectionLabel from "../shared/SectionLabel.vue";

const TERMINAL_BY_RULE = ["informational", "duplicate", "needs_clarification", "withdrawn"];

export default {
  name: "CommentTriageModal",
  components: { SectionLabel },
  mixins: [AlertMixin],
  props: {
    review: { type: Object, default: null },
  },
  data() {
    return {
      triageStatus: null,
      responseComment: "",
      duplicateOfId: null,
    };
  },
  computed: {
    modalTitle() {
      if (!this.review) return "Triage comment";
      return `Triage comment #${this.review.id}`;
    },
    nonConcurHint() {
      if (this.triageStatus === "non_concur") return "A response is required when declining.";
      return "";
    },
    responsePlaceholder() {
      switch (this.triageStatus) {
        case "concur": return "Thanks — we'll adopt this as suggested.";
        case "concur_with_comment": return "Thanks — we'll adopt with the following changes...";
        case "non_concur": return "Thanks for the suggestion. We won't adopt because...";
        default: return "Optional response to the commenter.";
      }
    },
    responseState() {
      if (this.triageStatus === "non_concur" && !this.responseComment.trim()) return false;
      return null;
    },
    canSave() {
      if (!this.triageStatus) return false;
      if (this.triageStatus === "non_concur" && !this.responseComment.trim()) return false;
      if (this.triageStatus === "duplicate" && !this.duplicateOfId) return false;
      return true;
    },
    canSaveAndClose() {
      return !TERMINAL_BY_RULE.includes(this.triageStatus);
    },
    ruleEditorLink() {
      if (!this.review) return "#";
      return `/components/${this.review.component_id || ""}/${this.review.rule_displayed_name}`;
    },
  },
  watch: {
    review(val) {
      if (val) {
        this.triageStatus = val.triage_status === "pending" ? null : val.triage_status;
        this.responseComment = "";
        this.duplicateOfId = val.duplicate_of_review_id || null;
      }
    },
  },
  methods: {
    relativeTime(iso) {
      if (!iso) return "";
      return new Date(iso).toLocaleString();
    },
    async saveTriage(alsoAdjudicate) {
      if (!this.review) return;
      try {
        const triageRes = await axios.patch(`/reviews/${this.review.id}/triage`, {
          triage_status: this.triageStatus,
          response_comment: this.responseComment.trim() || undefined,
          duplicate_of_review_id: this.triageStatus === "duplicate" ? this.duplicateOfId : undefined,
        });
        this.$emit("triaged", triageRes.data.review);

        if (alsoAdjudicate) {
          const adjudicateRes = await axios.patch(`/reviews/${this.review.id}/adjudicate`, {});
          this.$emit("adjudicated", adjudicateRes.data.review);
        }

        this.$bvModal.hide("comment-triage-modal");
      } catch (error) {
        this.alertOrNotifyResponse(error);
      }
    },
  },
};
</script>
```

## Step 4: Run spec, lint, vocabulary check

```bash
pnpm vitest run spec/javascript/components/components/CommentTriageModal.spec.js
yarn lint
```

The DISA-in-parens labels (e.g., "Accept (Concur)") are the **one allowed exception** in the doc's vocabulary policy — they're pedagogical and triager-facing only.

## Step 5: Commit

```bash
cat > /tmp/msg-15.md <<'EOF'
feat: CommentTriageModal.vue — DISA-aware decision UI

Modal opened from the triage table (Task 14) row action button. Renders
the comment with section context + decision radios with both friendly
label and DISA term ("Accept (Concur)", "Decline (Non-concur)") — the
one pedagogical exception to the vocabulary-layering principle.

Validations (client-side, mirroring server-side):
- Decline requires response_comment
- Duplicate requires duplicate_of_review_id
- "Save & close" disabled for terminal-by-rule statuses (informational,
  duplicate, needs_clarification, withdrawn) since those auto-set
  adjudicated_at server-side

PATCH /reviews/:id/triage on Save decision; chains an additional PATCH
/reviews/:id/adjudicate on Save & close. Errors surface via
AlertMixin#alertOrNotifyResponse (structured 403 path from PR #717
already covered).

Authored by: Aaron Lippold<lippold@gmail.com>
EOF

git add app/javascript/components/components/CommentTriageModal.vue \
        spec/javascript/components/components/CommentTriageModal.spec.js
git commit -F /tmp/msg-15.md
rm /tmp/msg-15.md
git mv docs/plans/PR717-public-comment-review/15-frontend-comment-triage-modal.md \
       docs/plans/PR717-public-comment-review/15-frontend-comment-triage-modal-DONE.md
git commit -m "chore: mark plan task 15 done

Authored by: Aaron Lippold<lippold@gmail.com>"
```
