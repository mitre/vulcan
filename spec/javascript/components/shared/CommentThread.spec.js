import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CommentThread from "@/components/shared/CommentThread.vue";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
    defaults: { headers: { common: {} } },
  },
}));

import api from "@/api/baseApi";

describe("CommentThread", () => {
  beforeEach(() => {
    api.get.mockReset();
  });

  it("does not render the toggle when responses_count is 0", () => {
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 0 },
    });
    // The toggle has aria-controls (so screen readers know what it
    // expands); the Reply b-button does not. responses_count=0 means
    // no toggle should render at all.
    expect(w.find("button[aria-controls]").exists()).toBe(false);
  });

  it("renders a singular label for one reply", () => {
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1 },
    });
    expect(w.text()).toContain("1 reply");
  });

  it("renders a plural label for multiple replies", () => {
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 3 },
    });
    expect(w.text()).toContain("3 replies");
  });

  it("emits reply with the parentReviewId when the Reply button is clicked", async () => {
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 42, responsesCount: 0, canReply: true },
    });
    // With responses_count=0 the only button rendered is Reply.
    await w.find("button").trigger("click");
    expect(w.emitted("reply")).toBeTruthy();
    expect(w.emitted("reply")[0]).toEqual([42]);
  });

  it("hides the Reply button when canReply is false", () => {
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1, canReply: false },
    });
    // Toggle exists but no Reply button
    expect(w.text()).not.toContain("Reply");
    expect(w.text()).toContain("1 reply");
  });

  it("lazy-loads replies on first toggle and caches them", async () => {
    api.get.mockResolvedValue({
      data: {
        rows: [
          {
            id: 7,
            comment: "first reply",
            commenter_display_name: "Replier",
            commenter_imported: false,
            created_at: "2026-05-04T00:00:00Z",
          },
        ],
      },
    });

    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1 },
    });

    // First click → fetch
    await w.find("button[aria-controls]").trigger("click");
    await new Promise((r) => setTimeout(r, 0));
    expect(api.get).toHaveBeenCalledTimes(1);
    expect(api.get).toHaveBeenCalledWith("/reviews/1/responses", { params: undefined });
    expect(w.text()).toContain("first reply");

    // Toggle off then on → should NOT refetch (cached)
    await w.find("button[aria-controls]").trigger("click");
    await w.find("button[aria-controls]").trigger("click");
    expect(api.get).toHaveBeenCalledTimes(1);
  });

  it("calls the correct endpoint for responses", async () => {
    api.get.mockResolvedValue({ data: { rows: [] } });
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 99, responsesCount: 1 },
    });
    await w.find("button[aria-controls]").trigger("click");
    await new Promise((r) => setTimeout(r, 0));
    expect(api.get).toHaveBeenCalledWith("/reviews/99/responses", { params: undefined });
  });

  it("renders an error state with retry on fetch failure", async () => {
    api.get.mockRejectedValueOnce(new Error("boom"));
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1 },
    });
    await w.find("button[aria-controls]").trigger("click");
    await new Promise((r) => setTimeout(r, 0));
    expect(w.text()).toContain("Failed to load replies");
  });

  it("invalidates cache + refetches when responsesCount changes while expanded", async () => {
    api.get.mockResolvedValue({
      data: {
        rows: [
          {
            id: 7,
            comment: "first",
            commenter_display_name: "X",
            commenter_imported: false,
            created_at: "2026-05-04T00:00:00Z",
          },
        ],
      },
    });
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1 },
    });
    await w.find("button[aria-controls]").trigger("click");
    await new Promise((r) => setTimeout(r, 0));
    expect(api.get).toHaveBeenCalledTimes(1);

    // Host's parent re-fetched and the count went up — refetch the thread.
    await w.setProps({ responsesCount: 2 });
    await new Promise((r) => setTimeout(r, 0));
    expect(api.get).toHaveBeenCalledTimes(2);
  });

  it("does not refetch on responsesCount change when collapsed (cache cleared lazily)", async () => {
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1 },
    });
    await w.setProps({ responsesCount: 2 });
    await new Promise((r) => setTimeout(r, 0));
    expect(api.get).not.toHaveBeenCalled();
  });

  it("redacts PII fallback names from the server payload (display token only)", async () => {
    api.get.mockResolvedValue({
      data: {
        rows: [
          {
            id: 7,
            comment: "imported reply",
            commenter_display_name: "(imported commenter)",
            commenter_imported: true,
            created_at: "2026-05-04T00:00:00Z",
          },
        ],
      },
    });
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1 },
    });
    await w.find("button[aria-controls]").trigger("click");
    await new Promise((r) => setTimeout(r, 0));
    expect(w.text()).toContain("(imported commenter)");
    expect(w.text()).toContain("imported");
  });

  // Reply cards must visually match the parent's triage-status tint so an
  // adjudicated comment + its replies read as one unit (found during in-app
  // verification of the bulk-triage UI).
  describe("parent triage-status background", () => {
    const oneReply = {
      data: {
        rows: [
          {
            id: 7,
            comment: "a reply",
            commenter_display_name: "User",
            created_at: "2026-05-04T00:00:00Z",
          },
        ],
      },
    };

    it("applies the parent's triage-bg class to each reply when parentTriageStatus is set", async () => {
      api.get.mockResolvedValue(oneReply);
      const w = mount(CommentThread, {
        localVue,
        propsData: { parentReviewId: 1, responsesCount: 1, parentTriageStatus: "concur" },
      });
      await w.find("button[aria-controls]").trigger("click");
      await new Promise((r) => setTimeout(r, 0));
      expect(w.html()).toContain("triage-bg--concur");
    });

    it("renders no triage-bg class when the parent is pending", async () => {
      api.get.mockResolvedValue(oneReply);
      const w = mount(CommentThread, {
        localVue,
        propsData: { parentReviewId: 1, responsesCount: 1, parentTriageStatus: "pending" },
      });
      await w.find("button[aria-controls]").trigger("click");
      await new Promise((r) => setTimeout(r, 0));
      expect(w.html()).not.toMatch(/triage-bg--/);
    });

    it("renders no triage-bg class when parentTriageStatus is omitted (default null)", async () => {
      api.get.mockResolvedValue(oneReply);
      const w = mount(CommentThread, {
        localVue,
        propsData: { parentReviewId: 1, responsesCount: 1 },
      });
      await w.find("button[aria-controls]").trigger("click");
      await new Promise((r) => setTimeout(r, 0));
      expect(w.html()).not.toMatch(/triage-bg--/);
    });
  });
});
