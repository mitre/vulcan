import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CommentBody from "@/components/shared/CommentBody.vue";

describe("CommentBody", () => {
  const shortComment = "Check text is vague about TLS verification.";
  const longComment = "A".repeat(250);

  it("renders short comment text with white-space pre-wrap", () => {
    const w = mount(CommentBody, {
      localVue,
      propsData: { text: shortComment },
    });
    expect(w.text()).toContain(shortComment);
    expect(w.find(".comment-body__text").exists()).toBe(true);
  });

  it("truncates text longer than 200 chars with show more link", () => {
    const w = mount(CommentBody, {
      localVue,
      propsData: { text: longComment },
    });
    expect(w.text()).toContain("…");
    expect(w.text()).toContain("show more");
    expect(w.text()).not.toContain(longComment);
  });

  it("expands truncated text on show more click", async () => {
    const w = mount(CommentBody, {
      localVue,
      propsData: { text: longComment },
    });
    await w.find("a").trigger("click");
    expect(w.text()).toContain(longComment);
    expect(w.text()).toContain("show less");
  });

  it("renders imported badge when isImported is true", () => {
    const w = mount(CommentBody, {
      localVue,
      propsData: { text: shortComment, isImported: true },
    });
    const badge = w.find(".badge");
    expect(badge.exists()).toBe(true);
    expect(badge.text()).toBe("imported");
  });

  it("does not render imported badge when isImported is false", () => {
    const w = mount(CommentBody, {
      localVue,
      propsData: { text: shortComment, isImported: false },
    });
    expect(w.findAll(".badge").length).toBe(0);
  });

  it("renders timestamp when provided", () => {
    const w = mount(CommentBody, {
      localVue,
      propsData: { text: shortComment, createdAt: "2026-05-01T10:00:00Z" },
    });
    expect(w.text()).toMatch(/May|2026/);
  });
});
