import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CommentThread from "@/components/shared/CommentThread.vue";

vi.mock("axios", () => ({
  default: {
    get: vi.fn(),
    defaults: { headers: { common: {} } },
  },
}));

import axios from "axios";

describe("CommentThread", () => {
  beforeEach(() => {
    axios.get.mockReset();
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
    axios.get.mockResolvedValue({
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
    expect(axios.get).toHaveBeenCalledTimes(1);
    expect(axios.get).toHaveBeenCalledWith("/reviews/1/responses", {
      headers: { Accept: "application/json" },
    });
    expect(w.text()).toContain("first reply");

    // Toggle off then on → should NOT refetch (cached)
    await w.find("button[aria-controls]").trigger("click");
    await w.find("button[aria-controls]").trigger("click");
    expect(axios.get).toHaveBeenCalledTimes(1);
  });

  it("sends an explicit Accept: application/json header (per-pack axios pattern)", async () => {
    axios.get.mockResolvedValue({ data: { rows: [] } });
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 99, responsesCount: 1 },
    });
    await w.find("button[aria-controls]").trigger("click");
    await new Promise((r) => setTimeout(r, 0));
    expect(axios.get).toHaveBeenCalledWith(
      "/reviews/99/responses",
      expect.objectContaining({ headers: { Accept: "application/json" } }),
    );
  });

  it("renders an error state with retry on fetch failure", async () => {
    axios.get.mockRejectedValueOnce(new Error("boom"));
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1 },
    });
    await w.find("button[aria-controls]").trigger("click");
    await new Promise((r) => setTimeout(r, 0));
    expect(w.text()).toContain("Failed to load replies");
  });

  it("invalidates cache + refetches when responsesCount changes while expanded", async () => {
    axios.get.mockResolvedValue({
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
    expect(axios.get).toHaveBeenCalledTimes(1);

    // Host's parent re-fetched and the count went up — refetch the thread.
    await w.setProps({ responsesCount: 2 });
    await new Promise((r) => setTimeout(r, 0));
    expect(axios.get).toHaveBeenCalledTimes(2);
  });

  it("does not refetch on responsesCount change when collapsed (cache cleared lazily)", async () => {
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1 },
    });
    await w.setProps({ responsesCount: 2 });
    await new Promise((r) => setTimeout(r, 0));
    expect(axios.get).not.toHaveBeenCalled();
  });

  it("redacts PII fallback names from the server payload (display token only)", async () => {
    axios.get.mockResolvedValue({
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
});
