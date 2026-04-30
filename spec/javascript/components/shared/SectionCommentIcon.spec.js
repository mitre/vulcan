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

  it("renders the button as disabled when locked=true (don't hide features — show + grey)", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", pendingCount: 0, locked: true },
    });
    const btn = w.find("button");
    expect(btn.exists()).toBe(true);
    expect(btn.attributes("disabled")).toBeDefined();
    // tooltip explains why
    expect(btn.attributes("title")).toMatch(/lock/i);
  });

  it("applies the inactive CSS class when locked=true (grey, not colored)", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", pendingCount: 0, locked: true },
    });
    const btn = w.find("button");
    expect(btn.classes()).toContain("section-comment-icon--inactive");
  });

  it("does NOT apply the inactive class when active (default state)", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", pendingCount: 0 },
    });
    const btn = w.find("button");
    expect(btn.classes()).not.toContain("section-comment-icon--inactive");
  });

  it("renders as a native button with type='button' for keyboard accessibility", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", pendingCount: 0 },
    });
    expect(w.find("button[type='button']").exists()).toBe(true);
  });

  it("decorative glyph is aria-hidden so screen readers don't announce it", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", pendingCount: 0 },
    });
    const decorative = w.find("[data-test=icon-glyph]");
    expect(decorative.exists()).toBe(true);
    expect(decorative.attributes("aria-hidden")).toBe("true");
  });

  /**
   * REQUIREMENT (Aaron 2026-04-29): adding a comment to a rule element
   * follows the same activation rules as field editing — the rule must
   * have a real status set. Locked is HIDE (rule is frozen). Disabled is
   * SHOW-BUT-INACTIVE with explanatory tooltip — discoverable for the
   * commenter even when they can't act yet.
   */
  describe("disabled state (Not Yet Determined / not-ready rules)", () => {
    it("renders the button but with disabled attribute when disabled=true", () => {
      const w = mount(SectionCommentIcon, {
        localVue,
        propsData: { section: "check_content", pendingCount: 0, disabled: true },
      });
      const btn = w.find("button");
      expect(btn.exists()).toBe(true);
      expect(btn.attributes("disabled")).toBeDefined();
    });

    it("does NOT emit 'open-composer' when clicked while disabled", async () => {
      const w = mount(SectionCommentIcon, {
        localVue,
        propsData: { section: "check_content", pendingCount: 0, disabled: true },
      });
      await w.find("button").trigger("click");
      expect(w.emitted("open-composer")).toBeUndefined();
    });

    it("uses an explanatory tooltip when disabled (vs. the active 'Comment on X' tooltip)", () => {
      const w = mount(SectionCommentIcon, {
        localVue,
        propsData: { section: "check_content", pendingCount: 0, disabled: true },
      });
      const btn = w.find("button");
      expect(btn.attributes("title")).toMatch(/status|ready|not yet/i);
    });

    it("locked tooltip wins over NYD-disabled tooltip (locked is the more specific reason)", () => {
      const w = mount(SectionCommentIcon, {
        localVue,
        propsData: { section: "title", pendingCount: 0, locked: true, disabled: true },
      });
      const btn = w.find("button");
      expect(btn.exists()).toBe(true);
      expect(btn.attributes("title")).toMatch(/lock/i);
    });
  });
});
