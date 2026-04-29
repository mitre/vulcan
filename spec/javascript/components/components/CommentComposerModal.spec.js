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
const visibleModalStub = {
  "b-modal": {
    template: `
      <div class="modal">
        <div class="modal-body"><slot></slot></div>
        <div class="modal-footer"><slot name="modal-footer" :cancel="() => {}"></slot></div>
      </div>
    `,
    props: ["title"],
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

  it("re-fetches dedup when section changes", async () => {
    const w = mount(CommentComposerModal, {
      localVue,
      propsData: baseProps,
      stubs: visibleModalStub,
    });
    await flushPromises(w);
    axios.get.mockClear();
    w.vm.section = "fixtext";
    await flushPromises(w);
    expect(axios.get).toHaveBeenCalledWith(
      "/components/42/comments",
      expect.objectContaining({
        params: expect.objectContaining({
          rule_id: 7,
          section: "fixtext",
          triage_status: "all",
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
