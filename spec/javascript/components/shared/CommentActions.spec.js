import { describe, it, expect, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CommentActions from "@/components/shared/CommentActions.vue";

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

describe("CommentActions", () => {
  const baseProps = {
    reviewId: 42,
    reactions: { up: 1, down: 0, mine: null },
    responsesCount: 3,
  };

  it("renders ReactionButtons with correct props", () => {
    const w = mount(CommentActions, {
      localVue,
      propsData: baseProps,
    });
    const rb = w.findComponent({ name: "ReactionButtons" });
    expect(rb.exists()).toBe(true);
    expect(rb.props("reviewId")).toBe(42);
    expect(rb.props("reactions")).toEqual({ up: 1, down: 0, mine: null });
  });

  it("renders CommentThread with correct props", () => {
    const w = mount(CommentActions, {
      localVue,
      propsData: baseProps,
    });
    const ct = w.findComponent({ name: "CommentThread" });
    expect(ct.exists()).toBe(true);
    expect(ct.props("parentReviewId")).toBe(42);
    expect(ct.props("responsesCount")).toBe(3);
  });

  it("forwards toggle-reaction event from ReactionButtons", async () => {
    const w = mount(CommentActions, {
      localVue,
      propsData: baseProps,
    });
    const rb = w.findComponent({ name: "ReactionButtons" });
    rb.vm.$emit("toggle", "up");
    expect(w.emitted("toggle-reaction")).toBeTruthy();
    expect(w.emitted("toggle-reaction")[0]).toEqual(["up"]);
  });

  it("forwards reply event from CommentThread", () => {
    const w = mount(CommentActions, {
      localVue,
      propsData: baseProps,
    });
    const ct = w.findComponent({ name: "CommentThread" });
    ct.vm.$emit("reply", 42);
    expect(w.emitted("reply")).toBeTruthy();
    expect(w.emitted("reply")[0]).toEqual([42]);
  });

  it("passes canReply prop to CommentThread", () => {
    const w = mount(CommentActions, {
      localVue,
      propsData: { ...baseProps, canReply: false },
    });
    const ct = w.findComponent({ name: "CommentThread" });
    expect(ct.props("canReply")).toBe(false);
  });

  it("hides ReactionButtons when reactions prop is null", () => {
    const w = mount(CommentActions, {
      localVue,
      propsData: { ...baseProps, reactions: null },
    });
    const rb = w.findComponent({ name: "ReactionButtons" });
    expect(rb.exists()).toBe(false);
  });
});
