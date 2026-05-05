import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import SectionCommentIcon from "@/components/shared/SectionCommentIcon.vue";

/**
 * SectionCommentIcon renders inline next to the lock + info icons in
 * RuleFormGroup's label. The icon is a raw <b-icon> with the
 * `v-b-tooltip.hover` directive (NOT wrapped in a <button>) so it
 * matches the lock/info sibling pattern visually and interactively.
 *
 * Activation rules:
 *   - rule.locked === true → inactive (greyed) with "rule is locked"
 *     tooltip — never hide.
 *   - component comment_phase !== 'open' (commentsClosed prop true)
 *     → inactive with "comments are closed" tooltip.
 *   - otherwise → active. Filled glyph + text-primary when open,
 *     outline glyph + text-info otherwise.
 */
describe("SectionCommentIcon", () => {
  // Helper: the icon root is a <span class="section-comment-icon"> wrapper
  // containing a <b-icon> with `data-testid="section-comment-<key>"` and
  // a `data-test="icon-glyph"` attribute (preserved across the redesign
  // for stable spec selectors).
  const findGlyph = (w) => w.find("[data-test=icon-glyph]");

  it("renders an icon with aria-label that includes the section's friendly name", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "check_content", openCount: 0 },
    });
    const glyph = findGlyph(w);
    expect(glyph.attributes("aria-label")).toMatch(/check/i);
    expect(glyph.attributes("aria-label")).toMatch(/comment/i);
  });

  it("shows a open count badge when > 0", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "fixtext", openCount: 3 },
    });
    expect(w.text()).toContain("3");
    expect(w.find("[data-test=count-badge]").exists()).toBe(true);
  });

  it("does NOT show a badge when openCount is 0", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "fixtext", openCount: 0 },
    });
    expect(w.find("[data-test=count-badge]").exists()).toBe(false);
  });

  it("includes screen-reader-only text describing the count", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "fixtext", openCount: 3 },
    });
    const sr = w.find(".sr-only");
    expect(sr.exists()).toBe(true);
    expect(sr.text()).toMatch(/3 open/i);
  });

  it("emits 'open-composer' with the XCCDF section key when clicked", async () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "check_content", openCount: 0 },
    });
    // Click the wrapper (matches the @click.stop on the root span).
    await w.find(".section-comment-icon").trigger("click");
    expect(w.emitted("open-composer")).toEqual([["check_content"]]);
  });

  it("uses chat-left-text-fill icon when there are open comments (visual cue)", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", openCount: 2 },
    });
    // b-icon renders the icon as SVG markup, not as an HTML attr — assert
    // the computed contract that drives the prop instead.
    expect(w.vm.glyphIcon).toBe("chat-left-text-fill");
  });

  it("uses chat-left-text outline when there are no open comments", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", openCount: 0 },
    });
    expect(w.vm.glyphIcon).toBe("chat-left-text");
  });

  it("applies text-primary + clickable when active with open comments", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", openCount: 2 },
    });
    const glyph = findGlyph(w);
    expect(glyph.classes()).toContain("text-primary");
    expect(glyph.classes()).toContain("clickable");
  });

  it("applies text-info + clickable when active with no open comments", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", openCount: 0 },
    });
    const glyph = findGlyph(w);
    expect(glyph.classes()).toContain("text-info");
    expect(glyph.classes()).toContain("clickable");
  });

  // Locked is inactive (greyed) with explanatory tooltip rather than
  // hidden, mirroring the unlock-icon pattern.
  it("applies text-muted + opacity-50 when locked=true (no clickable)", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", openCount: 0, locked: true },
    });
    const glyph = findGlyph(w);
    expect(glyph.classes()).toContain("text-muted");
    expect(glyph.classes()).toContain("opacity-50");
    expect(glyph.classes()).not.toContain("clickable");
  });

  it("does NOT emit 'open-composer' when clicked while locked", async () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "check_content", openCount: 0, locked: true },
    });
    await w.find(".section-comment-icon").trigger("click");
    expect(w.emitted("open-composer")).toBeUndefined();
  });

  // Tooltip-content tests assert the computed contract. BootstrapVue's
  // v-b-tooltip directive renders the tooltip in a portal at hover time,
  // so the text isn't an inert HTML attribute we can query — but the
  // computed text IS what the directive consumes.
  it("uses a 'lock' tooltip when locked", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", openCount: 0, locked: true },
    });
    expect(w.vm.tooltipText).toMatch(/lock/i);
  });

  describe("commentsClosed (phase != open)", () => {
    it("renders inactive (greyed) when commentsClosed=true", () => {
      const w = mount(SectionCommentIcon, {
        localVue,
        propsData: { section: "title", openCount: 0, commentsClosed: true },
      });
      const glyph = findGlyph(w);
      expect(glyph.classes()).toContain("text-muted");
      expect(glyph.classes()).toContain("opacity-50");
      expect(glyph.classes()).not.toContain("clickable");
    });

    it("does NOT emit 'open-composer' when clicked while commentsClosed", async () => {
      const w = mount(SectionCommentIcon, {
        localVue,
        propsData: {
          section: "check_content",
          openCount: 0,
          commentsClosed: true,
        },
      });
      await w.find(".section-comment-icon").trigger("click");
      expect(w.emitted("open-composer")).toBeUndefined();
    });

    it("uses a 'not enabled' tooltip when commentsClosed without a reason", () => {
      const w = mount(SectionCommentIcon, {
        localVue,
        propsData: { section: "title", openCount: 0, commentsClosed: true },
      });
      expect(w.vm.tooltipText).toMatch(/not enabled/i);
    });

    it("varies the tooltip by closedReason", () => {
      const adj = mount(SectionCommentIcon, {
        localVue,
        propsData: {
          section: "title",
          openCount: 0,
          commentsClosed: true,
          closedReason: "adjudicating",
        },
      });
      expect(adj.vm.tooltipText).toMatch(/adjudicat/i);

      const fin = mount(SectionCommentIcon, {
        localVue,
        propsData: {
          section: "title",
          openCount: 0,
          commentsClosed: true,
          closedReason: "finalized",
        },
      });
      expect(fin.vm.tooltipText).toMatch(/finaliz/i);
    });

    it("locked takes precedence over commentsClosed (more specific)", () => {
      const w = mount(SectionCommentIcon, {
        localVue,
        propsData: {
          section: "title",
          openCount: 0,
          locked: true,
          commentsClosed: true,
        },
      });
      // Locked is rule-scope, commentsClosed is component-scope; the
      // narrower / more-specific signal wins for the user message.
      expect(w.vm.tooltipText).toMatch(/lock/i);
    });
  });

  it("uses 'X open comments on Section' tooltip when active with open", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "fixtext", openCount: 3 },
    });
    expect(w.vm.tooltipText).toMatch(/3 open comments on Fix/i);
  });

  it("uses 'Comment on Section' tooltip when active with no open", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", openCount: 0 },
    });
    expect(w.vm.tooltipText).toMatch(/Comment on Title/i);
  });

  // Keyboard accessibility — the glyph is role=button with tabindex=0
  // when active (matches the lock/info icon focus behavior).
  it("is keyboard-focusable when active (tabindex=0, role=button)", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", openCount: 0 },
    });
    const glyph = findGlyph(w);
    expect(glyph.attributes("role")).toBe("button");
    expect(glyph.attributes("tabindex")).toBe("0");
  });

  it("is NOT keyboard-focusable when locked (tabindex=-1)", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", openCount: 0, locked: true },
    });
    expect(findGlyph(w).attributes("tabindex")).toBe("-1");
  });

  it("emits 'open-composer' on Enter keydown when active", async () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "check_content", openCount: 0 },
    });
    await findGlyph(w).trigger("keydown.enter");
    expect(w.emitted("open-composer")).toEqual([["check_content"]]);
  });
});
