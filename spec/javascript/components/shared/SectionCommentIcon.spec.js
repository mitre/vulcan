import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import SectionCommentIcon from "@/components/shared/SectionCommentIcon.vue";

/**
 * SectionCommentIcon renders inline next to the lock + info icons in
 * RuleFormGroup's label. Shows a count badge + small outlined [Add] and
 * [View] buttons for section-scoped comment actions.
 *
 * UX contract:
 *   - [Add] button always visible (disabled when commentsClosed)
 *   - [View] button only visible when openCount > 0
 *   - Count badge shows open comment count
 *   - Both buttons are small outlined for visual consistency
 */
describe("SectionCommentIcon", () => {
  const findAddBtn = (w) => w.find("[data-test=add-comment-btn]");
  const findViewBtn = (w) => w.find("[data-test=view-comments-link]");
  const findBadge = (w) => w.find("[data-test=count-badge]");

  // ─── No separate count badge ───────────────────────────────
  it("does NOT render a separate count badge (count is on View button)", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "fixtext", openCount: 3 },
    });
    expect(findBadge(w).exists()).toBe(false);
  });

  // ─── Add button ───────────────────────────────────────────
  it("renders an Add button with aria-label", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "check_content", openCount: 0 },
    });
    const btn = findAddBtn(w);
    expect(btn.exists()).toBe(true);
    expect(btn.text()).toMatch(/add comment/i);
  });

  it("emits 'open-composer' with the section when Add is clicked", async () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "check_content", openCount: 0 },
    });
    await findAddBtn(w).trigger("click");
    expect(w.emitted("open-composer")).toEqual([["check_content"]]);
  });

  it("emits 'open-composer' when Add is clicked while locked (comments allowed)", async () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "check_content", openCount: 0, locked: true },
    });
    await findAddBtn(w).trigger("click");
    expect(w.emitted("open-composer")).toHaveLength(1);
  });

  it("disables Add button when commentsClosed", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", openCount: 0, commentsClosed: true },
    });
    expect(findAddBtn(w).attributes("disabled")).toBeDefined();
  });

  it("does NOT emit 'open-composer' when Add is clicked while commentsClosed", async () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "check_content", openCount: 0, commentsClosed: true },
    });
    await findAddBtn(w).trigger("click");
    expect(w.emitted("open-composer")).toBeUndefined();
  });

  // ─── View button ──────────────────────────────────────────
  it("renders a View button with count when openCount > 0", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "check_content", openCount: 12 },
    });
    const btn = findViewBtn(w);
    expect(btn.exists()).toBe(true);
    expect(btn.text()).toMatch(/view 12 comments/i);
  });

  it("uses singular 'Comment' when openCount is 1", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "check_content", openCount: 1 },
    });
    expect(findViewBtn(w).text()).toMatch(/view 1 comment\b/i);
  });

  it("does NOT render View button when openCount is 0", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "check_content", openCount: 0 },
    });
    expect(findViewBtn(w).exists()).toBe(false);
  });

  it("emits 'view-comments' with the section when View is clicked", async () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "check_content", openCount: 5 },
    });
    await findViewBtn(w).trigger("click");
    expect(w.emitted("view-comments")).toEqual([["check_content"]]);
  });

  it("does NOT emit 'open-composer' when the View button is clicked", async () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "check_content", openCount: 5 },
    });
    await findViewBtn(w).trigger("click");
    expect(w.emitted("open-composer")).toBeUndefined();
  });

  it("renders the View button even when commentsClosed (viewing is always allowed)", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "fixtext", openCount: 3, commentsClosed: true },
    });
    expect(findViewBtn(w).exists()).toBe(true);
  });

  it("emits 'view-comments' even when commentsClosed", async () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "fixtext", openCount: 3, commentsClosed: true },
    });
    await findViewBtn(w).trigger("click");
    expect(w.emitted("view-comments")).toEqual([["fixtext"]]);
  });

  // ─── Tooltips ─────────────────────────────────────────────
  it("uses a 'lock' tooltip when locked", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", openCount: 0, locked: true },
    });
    expect(w.vm.closedTooltip).toMatch(/lock/i);
  });

  it("uses a 'not enabled' tooltip when commentsClosed without a reason", () => {
    const w = mount(SectionCommentIcon, {
      localVue,
      propsData: { section: "title", openCount: 0, commentsClosed: true },
    });
    expect(w.vm.closedTooltip).toMatch(/not enabled/i);
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
    expect(adj.vm.closedTooltip).toMatch(/adjudicat/i);

    const fin = mount(SectionCommentIcon, {
      localVue,
      propsData: {
        section: "title",
        openCount: 0,
        commentsClosed: true,
        closedReason: "finalized",
      },
    });
    expect(fin.vm.closedTooltip).toMatch(/finaliz/i);
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
    expect(w.vm.closedTooltip).toMatch(/lock/i);
  });
});
