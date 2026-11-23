/**
 * Triage-with-response flow: the reply must be counted once and must be
 * visible in the thread it was posted to.
 *
 * REQUIREMENTS (user-visible, not implementation):
 *
 * R1 — A triage decision that carries a response_comment creates exactly ONE
 *      reply, so the parent comment's reply count must end at the number of
 *      replies the server actually holds (1), never 2. The count a user reads
 *      is the promise "expand me and you will find this many replies".
 *
 * R2 — Expanding the thread of the comment that was just adjudicated must show
 *      the reply that the adjudication created. The thread shown must belong to
 *      the comment currently being triaged — whichever comment in the queue
 *      that is, including after navigating the queue.
 *
 * Both are driven through the real sequence the UI performs: CommentTriageForm
 * emits `save` → TriageSplitView.doSave PATCHes /reviews/:id/triage → emits
 * `triaged` and then `response-posted` → ComponentComments updates the row →
 * CommentThread reacts to the new count.
 *
 * The server contract these specs encode (pinned by
 * spec/requests/reviews_triage_spec.rb, "reports responses_count including the
 * reply it just created"): the `review` payload of PATCH /reviews/:id/triage
 * ALREADY counts the response it created in responses_count, and
 * GET /reviews/:id/responses returns that reply for the parent it was filed
 * under.
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { setActivePinia, createPinia } from "pinia";
import { localVue, flushPromises } from "@test/testHelper";
import ComponentComments from "@/components/components/ComponentComments.vue";
import { getComments } from "@/api/componentsApi";
import { triageReview, getReviewResponses } from "@/api/reviewsApi";

vi.mock("@/api/baseApi", async () =>
  (await import("@test/support/apiMocks")).baseApi({ resolveWith: {} }),
);

vi.mock("@/api/componentsApi", () => ({
  getComments: vi.fn(() => Promise.resolve({ data: { rows: [], pagination: { total: 0 } } })),
}));

vi.mock("@/api/projectsApi", () => ({
  getProjectComments: vi.fn(() =>
    Promise.resolve({ data: { rows: [], pagination: { total: 0 } } }),
  ),
}));

vi.mock("@/api/reviewsApi", () => ({
  getReviewResponses: vi.fn(() => Promise.resolve({ data: { rows: [] } })),
  triageReview: vi.fn(() => Promise.resolve({ data: {} })),
  adjudicateReview: vi.fn(() => Promise.resolve({ data: {} })),
  bulkTriageReviews: vi.fn(() => Promise.resolve({ data: {} })),
  mergeReviews: vi.fn(() => Promise.resolve({ data: {} })),
  reopenReview: vi.fn(() => Promise.resolve({ data: {} })),
  createRuleReview: vi.fn(() => Promise.resolve({ data: {} })),
  createComponentReview: vi.fn(() => Promise.resolve({ data: {} })),
  adminDestroyReview: vi.fn(() => Promise.resolve({ data: {} })),
  moveReviewToRule: vi.fn(() => Promise.resolve({ data: {} })),
  adminWithdrawReview: vi.fn(() => Promise.resolve({ data: {} })),
  adminRestoreReview: vi.fn(() => Promise.resolve({ data: {} })),
  toggleReaction: vi.fn(() => Promise.resolve({ data: {} })),
}));

const RULE_CONTENT = {
  rule_displayed_name: "CNTR-01-000001",
  title: "The container platform must limit privileges",
  rule_severity: "CAT II",
  status: "Applicable - Configurable",
  fixtext: "Configure the container platform to restrict access",
  check_content: "Verify that the container runtime enforces privilege restrictions",
  vuln_discussion: "Without proper privilege restriction, containers could escalate",
  vendor_comments: null,
};

// Two pending comments on the same rule — the queue the triager walks.
const QUEUE_ROWS = [
  {
    id: 101,
    rule_id: 10,
    rule_displayed_name: "CNTR-01-000001",
    commentable_type: "Rule",
    section: "check_content",
    author_name: "Demo Viewer",
    comment: "The check text mentions runc 1.0",
    triage_status: "pending",
    created_at: "2026-05-01T00:00:00Z",
    updated_at: "2026-05-01T00:00:00Z",
    adjudicated_at: null,
    responses_count: 0,
    rule_content: RULE_CONTENT,
    reactions: { up: 0, down: 0, mine: null },
  },
  {
    id: 202,
    rule_id: 10,
    rule_displayed_name: "CNTR-01-000001",
    commentable_type: "Rule",
    section: "fixtext",
    author_name: "Demo Reviewer",
    comment: "The fix text could include the seccomp profile path",
    triage_status: "pending",
    created_at: "2026-05-01T01:00:00Z",
    updated_at: "2026-05-01T01:00:00Z",
    adjudicated_at: null,
    responses_count: 0,
    rule_content: RULE_CONTENT,
    reactions: { up: 0, down: 0, mine: null },
  },
];

const ADJUDICATION_TEXT = "Adjudication note: adopting the seccomp path";

// Server shape: the triaged parent is re-rendered AFTER the child reply is
// created in the same transaction, so responses_count already includes it.
function triageResponseFor(parentId) {
  return {
    data: {
      review: {
        id: parentId,
        rule_id: 10,
        section: parentId === 101 ? "check_content" : "fixtext",
        triage_status: "concur_with_comment",
        triage_set_at: "2026-05-02T00:00:00Z",
        adjudicated_at: null,
        responses_count: 1,
        responding_to_review_id: null,
        comment: QUEUE_ROWS.find((r) => r.id === parentId).comment,
        author_name: "Demo Triager",
        created_at: QUEUE_ROWS.find((r) => r.id === parentId).created_at,
        reactions: { up: 0, down: 0, mine: null },
      },
      response_review: {
        id: 900 + parentId,
        comment: ADJUDICATION_TEXT,
        responding_to_review_id: parentId,
        action: "comment",
        section: parentId === 101 ? "check_content" : "fixtext",
        created_at: "2026-05-02T00:00:00Z",
        commenter_display_name: "Demo Triager",
        commenter_imported: false,
        reactions: { up: 0, down: 0, mine: null },
      },
    },
  };
}

// GET /reviews/:id/responses — only the parent the reply was filed under
// has it. Keyed by parent id, exactly like the server's foreign key.
function stubResponsesEndpoint(parentIdWithReply) {
  getReviewResponses.mockImplementation((reviewId) =>
    Promise.resolve({
      data: {
        rows:
          reviewId === parentIdWithReply
            ? [
                {
                  id: 900 + parentIdWithReply,
                  comment: ADJUDICATION_TEXT,
                  responding_to_review_id: parentIdWithReply,
                  commenter_display_name: "Demo Triager",
                  commenter_imported: false,
                  created_at: "2026-05-02T00:00:00Z",
                  reactions: { up: 0, down: 0, mine: null },
                },
              ]
            : [],
      },
    }),
  );
}

describe("ComponentComments — triage response thread", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    getComments.mockResolvedValue({
      data: {
        rows: QUEUE_ROWS,
        pagination: { page: 1, per_page: 100, total: QUEUE_ROWS.length },
        status_counts: { pending: 2 },
      },
    });
    getReviewResponses.mockResolvedValue({ data: { rows: [] } });
  });

  // Mount the real page component and enter split (triage) mode on `openOnId`,
  // the way the "Triage" button does.
  async function mountTriageOn(openOnId) {
    const wrapper = mount(ComponentComments, {
      localVue,
      propsData: { componentId: 42 },
      provide: { effectivePermissions: "author" },
      stubs: ["b-table", "b-pagination"],
    });
    await flushPromises(wrapper);
    wrapper.vm.openTriageFor(QUEUE_ROWS.find((r) => r.id === openOnId));
    await flushPromises(wrapper);
    return wrapper;
  }

  // Submit a triage decision carrying a response comment through the form.
  async function adjudicateWithComment(wrapper) {
    const form = wrapper.findComponent({ name: "CommentTriageForm" });
    expect(form.exists()).toBe(true);
    form.vm.$emit("save", {
      triage_status: "concur_with_comment",
      response_comment: ADJUDICATION_TEXT,
    });
    await flushPromises(wrapper);
    await flushPromises(wrapper);
  }

  function splitThread(wrapper) {
    const split = wrapper.findComponent({ name: "TriageSplitView" });
    return split.findComponent({ name: "CommentThread" });
  }

  async function expandThread(wrapper) {
    await splitThread(wrapper).find("button[aria-controls]").trigger("click");
    await flushPromises(wrapper);
  }

  describe("when the adjudicated comment is the one the panel opened on", () => {
    // Control case for R2: no queue navigation. If this passes while the
    // navigated case fails, the cause is the navigation, not the fetch itself.
    it("shows the new reply when the thread is expanded", async () => {
      triageReview.mockResolvedValue(triageResponseFor(101));
      stubResponsesEndpoint(101);

      const wrapper = await mountTriageOn(101);
      await adjudicateWithComment(wrapper);
      await expandThread(wrapper);

      expect(getReviewResponses).toHaveBeenCalledWith(101);
      expect(splitThread(wrapper).text()).toContain(ADJUDICATION_TEXT);
    });
  });

  describe("after navigating the queue to another comment", () => {
    // R2: the thread under the comment being triaged must be THAT comment's
    // thread. A triager walks the queue; the panel is not remounted per
    // comment, so the thread has to follow the active comment.
    it("fetches and shows the replies of the comment that was adjudicated", async () => {
      triageReview.mockResolvedValue(triageResponseFor(202));
      stubResponsesEndpoint(202);

      const wrapper = await mountTriageOn(101);
      // Walk to the second comment in the queue (TriageQueueNav @select).
      wrapper.findComponent({ name: "TriageSplitView" }).vm.onQueueSelect(202);
      await flushPromises(wrapper);
      expect(wrapper.findComponent({ name: "TriageSplitView" }).vm.activeComment.id).toBe(202);

      await adjudicateWithComment(wrapper);
      await expandThread(wrapper);

      // The thread rendered under comment 202 must be comment 202's thread.
      expect(splitThread(wrapper).props("parentReviewId")).toBe(202);
      expect(getReviewResponses).toHaveBeenCalledWith(202);
      expect(getReviewResponses).not.toHaveBeenCalledWith(101);
      expect(splitThread(wrapper).text()).toContain(ADJUDICATION_TEXT);
    });
  });

  describe("reply count after a triage decision with a response comment", () => {
    // R1: one reply was created, so the count must read 1. Any number the
    // user cannot find replies for is a lie about the thread's contents.
    it("counts the reply exactly once on the triaged row", async () => {
      triageReview.mockResolvedValue(triageResponseFor(101));
      stubResponsesEndpoint(101);

      const wrapper = await mountTriageOn(101);
      await adjudicateWithComment(wrapper);

      const row = wrapper.vm.rows.find((r) => r.id === 101);
      expect(row.responses_count).toBe(1);
      expect(splitThread(wrapper).props("responsesCount")).toBe(1);
    });

    // R1, from the user's side: the label must match what expanding reveals.
    it("labels the toggle with the number of replies the thread actually has", async () => {
      triageReview.mockResolvedValue(triageResponseFor(101));
      stubResponsesEndpoint(101);

      const wrapper = await mountTriageOn(101);
      await adjudicateWithComment(wrapper);
      await expandThread(wrapper);

      const thread = splitThread(wrapper);
      expect(thread.vm.replies).toHaveLength(1);
      expect(thread.text()).toContain("1 reply");
    });
  });
});
