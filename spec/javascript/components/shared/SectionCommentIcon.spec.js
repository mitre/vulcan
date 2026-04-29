import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import SectionCommentIcon from "@/components/shared/SectionCommentIcon.vue";

describe("SectionCommentIcon", () => {
  it("renders a button with aria-label that includes the section's friendly name", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "check_content", pendingCount: 0 },
    });
    const btn = w.find("button");
    expect(btn.attributes("aria-label")).toMatch(/check/i);
    expect(btn.attributes("aria-label")).toMatch(/comment/i);
  });

  it("shows a pending count badge when > 0", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "fixtext", pendingCount: 3 },
    });
    expect(w.text()).toContain("3");
    expect(w.find("[data-test=count-badge]").exists()).toBe(true);
  });

  it("does NOT show a badge when pendingCount is 0", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "fixtext", pendingCount: 0 },
    });
    expect(w.find("[data-test=count-badge]").exists()).toBe(false);
  });

  it("includes screen-reader-only text describing the count", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "fixtext", pendingCount: 3 },
    });
    const sr = w.find(".sr-only");
    expect(sr.exists()).toBe(true);
    expect(sr.text()).toMatch(/3 pending/i);
  });

  it("emits 'open-composer' with the XCCDF section key on click", async () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "check_content", pendingCount: 0 },
    });
    await w.find("button").trigger("click");
    expect(w.emitted("open-composer")).toEqual([["check_content"]]);
  });

  it("hides entirely when locked=true", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", pendingCount: 0, locked: true },
    });
    expect(w.find("button").exists()).toBe(false);
  });

  it("renders as a native button with type='button' for keyboard accessibility", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", pendingCount: 0 },
    });
    expect(w.find("button[type='button']").exists()).toBe(true);
  });

  it("decorative emoji is aria-hidden so screen readers don't announce it", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", pendingCount: 0 },
    });
    const decorative = w.find("[data-test=icon-emoji]");
    expect(decorative.exists()).toBe(true);
    expect(decorative.attributes("aria-hidden")).toBe("true");
  });
});
