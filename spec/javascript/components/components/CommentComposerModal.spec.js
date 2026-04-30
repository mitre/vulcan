import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import axios from "axios";
import CommentComposerModal from "@/components/components/CommentComposerModal.vue";

vi.mock("axios");

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
    vi.clearAllMocks();
    axios.get.mockResolvedValue({ data: { rows: [], pagination: { total: 0 } } });
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
    axios.get.mockResolvedValue({
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
    axios.get.mockClear();
    w.vm.section = "fixtext";
    await flushPromises(w);
    expect(axios.get).not.toHaveBeenCalled();
  });

  // Refetches when ruleId changes (different rule = different conversation).
  it("re-fetches dedup when ruleId changes", async () => {
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    await flushPromises(w);
    axios.get.mockClear();
    await w.setProps({ ruleId: 99 });
    await flushPromises(w);
    expect(axios.get).toHaveBeenCalledWith(
      "/components/42/comments",
      expect.objectContaining({
        params: expect.objectContaining({
          rule_id: 99,
          triage_status: "all",
        }),
      }),
    );
    // No section param — fetch is rule-scoped, not section-scoped.
    const call = axios.get.mock.calls.find(([url]) => url === "/components/42/comments");
    expect(call[1].params.section).toBeUndefined();
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
    axios.post.mockResolvedValue({ data: { toast: "ok" } });
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    w.vm.onReplyClicked(42);
    w.vm.commentText = "Replying to that";
    await w.vm.$nextTick();
    await w.vm.submit();
    expect(axios.post).toHaveBeenCalledWith(
      "/rules/7/reviews",
      expect.objectContaining({
        review: expect.objectContaining({
          comment: "Replying to that",
          responding_to_review_id: 42,
        }),
      }),
    );
  });

  it("posts to /rules/:id/reviews with section + component_id on submit", async () => {
    axios.post.mockResolvedValue({ data: { toast: "ok" } });
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

    w.vm.commentText = "my new comment";
    await w.vm.submit();
    await flushPromises(w);

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
      localVue,
      propsData: { ...baseProps, replyToReviewId: 99 },
      stubs: visibleModalStub,
    });
    vi.spyOn(w.vm.$bvModal, "hide").mockImplementation(() => {});

    w.vm.commentText = "thanks for raising this";
    await w.vm.submit();
    await flushPromises(w);

    expect(axios.post.mock.calls[0][1].review.responding_to_review_id).toBe(99);
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
    axios.post.mockRejectedValueOnce({ response: { status: 422, data: {} } });
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
});
