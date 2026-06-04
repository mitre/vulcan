import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";
import { localVue } from "@test/testHelper";
import CommentComposerModal from "@/components/components/CommentComposerModal.vue";
import { createRuleReview, createComponentReview } from "@/api/reviewsApi";
import { getComments } from "@/api/componentsApi";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: {} })),
    post: vi.fn(() => Promise.resolve({ data: {} })),
    put: vi.fn(() => Promise.resolve({ data: {} })),
    patch: vi.fn(() => Promise.resolve({ data: {} })),
    delete: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } },
  },
}));

vi.mock("@/api/reviewsApi", () => ({
  createRuleReview: vi.fn(() => Promise.resolve({ data: { toast: "ok" } })),
  createComponentReview: vi.fn(() => Promise.resolve({ data: { toast: "ok" } })),
}));

vi.mock("@/api/componentsApi", () => ({
  getComments: vi.fn(() => Promise.resolve({ data: { rows: [], pagination: { total: 0 } } })),
}));

const flushPromises = async (wrapper) => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  if (wrapper) await wrapper.vm.$nextTick();
};

// Same render-the-body-anyway b-modal stub as CommentTriageModal.spec.js.
// `centered` is exposed so we can assert vertical-centering at the
// template level (Aaron 2026-04-29).
const visibleModalStub = {
  "b-modal": {
    template: `
      <div class="modal" :data-centered="String(centered)">
        <div class="modal-body"><slot></slot></div>
        <div class="modal-footer"><slot name="modal-footer" :cancel="() => {}"></slot></div>
      </div>
    `,
    props: {
      title: String,
      centered: { type: Boolean, default: false },
    },
  },
};

const baseProps = {
  ruleId: 7,
  componentId: 42,
  ruleDisplayedName: "CRI-O-000050",
  initialSection: "check_content",
};

describe("CommentComposerModal", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    getComments.mockResolvedValue({ data: { rows: [], pagination: { total: 0 } } });
  });

  it("initializes section from the initialSection prop", () => {
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    expect(w.vm.section).toBe("check_content");
  });

  it("shows a dedup banner with existing comments on the same rule + section", async () => {
    getComments.mockResolvedValue({
      data: {
        rows: [
          {
            id: 99,
            comment: "Sarah K - existing concern",
            author_name: "Sarah K",
            section: "check_content",
            triage_status: "pending",
            created_at: "2026-04-26T10:00:00Z",
          },
        ],
        pagination: { total: 1 },
      },
    });
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    await flushPromises(w);
    expect(w.text()).toContain("1 existing");
  });

  // Section change does NOT trigger a re-fetch — DedupBanner now loads
  // ALL rule-level comments in one shot so commenters can see prior
  // conversation across sections (Aaron 2026-04-29). Section-scoped
  // count is computed client-side via the inSection computed.
  it("does NOT re-fetch dedup when section changes (rule-level fetch only)", async () => {
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    await flushPromises(w);
    getComments.mockClear();
    w.vm.section = "fixtext";
    await flushPromises(w);
    expect(getComments).not.toHaveBeenCalled();
  });

  // Refetches when ruleId changes (different rule = different conversation).
  it("re-fetches dedup when ruleId changes", async () => {
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    await flushPromises(w);
    getComments.mockClear();
    await w.setProps({ ruleId: 99 });
    await flushPromises(w);
    expect(getComments).toHaveBeenCalledWith(
      42,
      expect.objectContaining({
        rule_id: 99,
        triage_status: "all",
      }),
    );
    // No section param — fetch is rule-scoped, not section-scoped.
    const call = getComments.mock.calls.find(([id]) => id === 42);
    expect(call[1].section).toBeUndefined();
  });

  // Prop sync: when the parent updates :initial-section after the modal
  // is already mounted (e.g. user clicks a different SectionCommentIcon),
  // the local section data must update so the FilterDropdown trigger
  // reflects the new pre-selected section.
  it("syncs local section when initialSection prop changes", async () => {
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    expect(w.vm.section).toBe("check_content");
    await w.setProps({ initialSection: "title" });
    expect(w.vm.section).toBe("title");
  });

  // Same Vue 2 data()-runs-once gotcha applies to replyToReviewId — the
  // parent may send an updated reply target (e.g. clicking [Reply] from
  // the rule's review thread directly), and the modal must mirror it.
  it("syncs currentReplyToId when replyToReviewId prop changes", async () => {
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    expect(w.vm.currentReplyToId).toBe(null);
    await w.setProps({ replyToReviewId: 77 });
    expect(w.vm.currentReplyToId).toBe(77);
  });

  // Vertical centering — visual parity with the other PR-717 modals,
  // requested by Aaron 2026-04-29.
  it("sets centered=true on the b-modal so it sits in the middle of the viewport", () => {
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    expect(w.find(".modal").attributes("data-centered")).toBe("true");
  });

  // Reply mode UI: section dropdown + dedup banner are gated by
  // !currentReplyToId so a reply doesn't expose section pickers (the
  // reply inherits the parent comment's section anyway).
  it("hides the section dropdown when in reply mode", async () => {
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: { ...baseProps, replyToReviewId: 99 },
      stubs: visibleModalStub,
    });
    await flushPromises(w);
    expect(w.findComponent({ name: "FilterDropdown" }).exists()).toBe(false);
  });

  it("hides the dedup banner when in reply mode", async () => {
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: { ...baseProps, replyToReviewId: 99 },
      stubs: visibleModalStub,
    });
    await flushPromises(w);
    expect(w.findComponent({ name: "CommentDedupBanner" }).exists()).toBe(false);
  });

  it("shows the 'Replying to comment #X' header when in reply mode", async () => {
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: { ...baseProps, replyToReviewId: 142 },
      stubs: visibleModalStub,
    });
    await flushPromises(w);
    expect(w.text()).toContain("Replying to comment #142");
  });

  // Returning to new-comment mode after canceling a reply restores the
  // section dropdown so the user can switch sections again.
  it("re-shows the section dropdown after cancelReply", async () => {
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    w.vm.onReplyClicked(42);
    await w.vm.$nextTick();
    expect(w.findComponent({ name: "FilterDropdown" }).exists()).toBe(false);
    w.vm.cancelReply();
    await w.vm.$nextTick();
    expect(w.findComponent({ name: "FilterDropdown" }).exists()).toBe(true);
  });

  // Reply mode wiring: clicking [Reply] in the dedup banner switches the
  // composer into reply mode (hides section dropdown + dedup banner,
  // shows "Replying to comment #X" header). cancelReply puts it back.
  it("switches to reply mode when DedupBanner emits 'reply'", async () => {
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    expect(w.vm.currentReplyToId).toBe(null);
    w.vm.onReplyClicked(42);
    await w.vm.$nextTick();
    expect(w.vm.currentReplyToId).toBe(42);
    w.vm.cancelReply();
    expect(w.vm.currentReplyToId).toBe(null);
  });

  it("submits with responding_to_review_id when in reply mode", async () => {
    createRuleReview.mockResolvedValue({ data: { toast: "ok" } });
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    w.vm.onReplyClicked(42);
    w.vm.commentText = "Replying to that";
    await w.vm.$nextTick();
    await w.vm.submit();
    expect(createRuleReview).toHaveBeenCalledWith(
      7,
      expect.objectContaining({
        comment: "Replying to that",
        responding_to_review_id: 42,
      }),
    );
  });

  it("posts to /rules/:id/reviews with section + component_id on submit", async () => {
    createRuleReview.mockResolvedValue({ data: { toast: "ok" } });
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

    w.vm.commentText = "my new comment";
    await w.vm.submit();
    await flushPromises(w);

    expect(createRuleReview).toHaveBeenCalledWith(
      7,
      expect.objectContaining({
        action: "comment",
        comment: "my new comment",
        section: "check_content",
        component_id: 42,
      }),
    );
    expect(w.emitted("posted")).toBeTruthy();
  });

  it("shows inline success message on a successful post", async () => {
    const successResponse = {
      data: {
        toast: {
          title: "Comment posted.",
          message: ["Posted on parent control CNTR-00-000030"],
          variant: "success",
        },
      },
    };
    createRuleReview.mockResolvedValue(successResponse);
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

    w.vm.commentText = "my new comment";
    await w.vm.submit();
    await flushPromises(w);

    expect(w.vm.successMessage).toBe("Posted on parent control CNTR-00-000030");
    expect(w.emitted("posted")).toBeTruthy();
  });

  it("shows default success message when toast has no message", async () => {
    createRuleReview.mockResolvedValue({
      data: { toast: { title: "Comment posted.", message: [""], variant: "success" } },
    });
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

    w.vm.commentText = "test";
    await w.vm.submit();
    await flushPromises(w);

    expect(w.vm.successMessage).toBe("Comment posted.");
  });

  // when the composer was opened for a child rule
  // (parentRuleId set), the soft-redirect fallback message should name the
  // parent control so the user knows where their comment landed.
  it("falls back to 'posted on parent control …' when parentRuleId is set", async () => {
    createRuleReview.mockResolvedValue({
      data: { toast: { title: "Comment posted.", message: [""], variant: "success" } },
    });
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: { ...baseProps, parentRuleId: 99, parentRuleName: "CNTR-00-000030" },
      stubs: visibleModalStub,
    });
    vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

    w.vm.commentText = "test";
    await w.vm.submit();
    await flushPromises(w);

    expect(w.vm.successMessage).toBe("Comment posted on parent control CNTR-00-000030.");
  });

  it("posts with responding_to_review_id when in reply mode", async () => {
    createRuleReview.mockResolvedValue({ data: { toast: "ok" } });
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: { ...baseProps, replyToReviewId: 99 },
      stubs: visibleModalStub,
    });
    vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

    w.vm.commentText = "thanks for raising this";
    await w.vm.submit();
    await flushPromises(w);

    expect(createRuleReview.mock.calls[0][1].responding_to_review_id).toBe(99);
  });

  it("disables submit when comment text is empty", () => {
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    w.vm.commentText = "";
    expect(w.vm.canSubmit).toBe(false);
    w.vm.commentText = "   ";
    expect(w.vm.canSubmit).toBe(false);
    w.vm.commentText = "real text";
    expect(w.vm.canSubmit).toBe(true);
  });

  it("surfaces server errors via AlertMixin without crashing", async () => {
    createRuleReview.mockRejectedValueOnce({ response: { status: 422, data: {} } });
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    const alertSpy = vi.spyOn(w.vm, "alertOrNotifyResponse").mockImplementation(() => {});

    w.vm.commentText = "test";
    await w.vm.submit();
    await flushPromises(w);

    expect(alertSpy).toHaveBeenCalled();
    alertSpy.mockRestore();
  });

  describe("nested rule parent awareness", () => {
    const nestedProps = {
      ...baseProps,
      parentRuleId: 99,
      parentRuleName: "CNTR-00-000030",
    };

    it("shows InfoNotice when parentRuleId is set", () => {
      const w = mount(CommentComposerModal, {
        localVue,
        propsData: nestedProps,
        stubs: { ...visibleModalStub, CommentDedupBanner: true, FilterDropdown: true },
      });
      expect(w.find(".parent-redirect-notice").exists()).toBe(true);
      expect(w.find(".parent-redirect-notice").text()).toContain("CNTR-00-000030");
    });

    it("does NOT show InfoNotice when parentRuleId is null", () => {
      const w = mount(CommentComposerModal, {
        localVue,
        propsData: baseProps,
        stubs: { ...visibleModalStub, CommentDedupBanner: true, FilterDropdown: true },
      });
      expect(w.find(".parent-redirect-notice").exists()).toBe(false);
    });

    it("passes parentRuleId to CommentDedupBanner instead of ruleId", () => {
      const w = mount(CommentComposerModal, {
        localVue,
        propsData: nestedProps,
        stubs: { ...visibleModalStub, FilterDropdown: true },
      });
      const banner = w.findComponent({ name: "CommentDedupBanner" });
      expect(banner.props("ruleId")).toBe(99);
    });

    it("passes regular ruleId to CommentDedupBanner when not nested", () => {
      const w = mount(CommentComposerModal, {
        localVue,
        propsData: baseProps,
        stubs: { ...visibleModalStub, FilterDropdown: true },
      });
      const banner = w.findComponent({ name: "CommentDedupBanner" });
      expect(banner.props("ruleId")).toBe(7);
    });
  });

  // ── v2-6gq.4: b-alert migration ─────────────────────────────────────

  describe("success message uses b-alert", () => {
    it("renders a b-alert with variant=success (not a raw div.alert) after posting", async () => {
      createRuleReview.mockResolvedValue({
        data: {
          toast: {
            title: "Comment posted.",
            message: ["Comment posted successfully."],
            variant: "success",
          },
        },
      });
      const w = mount(CommentComposerModal, {
        localVue,
        propsData: baseProps,
        stubs: visibleModalStub,
      });
      vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

      w.vm.commentText = "test comment";
      await w.vm.submit();
      await flushPromises(w);

      const alert = w.findComponent({ name: "BAlert" });
      expect(alert.exists()).toBe(true);
      expect(alert.props("variant")).toBe("success");
      expect(alert.props("show")).toBe(true);
    });
  });
});
