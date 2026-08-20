import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import PanelLayout from "@/components/shared/PanelLayout.vue";

/**
 * REQUIREMENTS:
 * PanelLayout is a shared multi-panel layout component using named slots.
 * Encodes the proper Bootstrap 4 pattern: b-row no-gutters + panels
 * owning their own padding + flex-column + overflow-auto. Borrows from
 * Bootstrap 5.3's three-tier bg hierarchy.
 *
 * It MUST:
 *   - Use b-row with no-gutters so panels own ALL their padding
 *   - Support 2 or 3 panel layouts via named slots
 *   - Map bgTier to correct --vulcan-*-bg CSS variable per panel
 *   - Auto-place borders between adjacent panels
 *   - Support header/footer slots per panel with consistent padding
 *   - Make panel bodies scrollable (overflow-auto + min-height-0)
 */
describe("PanelLayout", () => {
  const defaultPanels = [
    { name: "left", size: "sidebar", bgTier: "secondary" },
    { name: "center", size: "fill", bgTier: "body" },
    { name: "right", size: "fill", bgTier: "tertiary" },
  ];

  const mountWith = (props = {}, slots = {}) =>
    mount(PanelLayout, {
      localVue,
      propsData: { panels: defaultPanels, ...props },
      slots: {
        left: '<div data-testid="left-content">Left</div>',
        center: '<div data-testid="center-content">Center</div>',
        right: '<div data-testid="right-content">Right</div>',
        ...slots,
      },
    });

  it("renders all three panels with slot content", () => {
    const wrapper = mountWith();
    expect(wrapper.find('[data-testid="left-content"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="center-content"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="right-content"]').exists()).toBe(true);
  });

  it("uses no-gutters on the row to prevent grid padding conflicts", () => {
    const wrapper = mountWith();
    const row = wrapper.find(".row");
    expect(row.exists()).toBe(true);
    expect(row.classes()).toContain("no-gutters");
  });

  it("applies correct bgTier CSS variable per panel", () => {
    const wrapper = mountWith();
    const panels = wrapper.findAll(".panel-layout__panel");
    expect(panels.length).toBe(3);

    expect(panels.at(0).element.style.backgroundColor).toBe("var(--vulcan-secondary-bg)");
    expect(panels.at(1).element.style.backgroundColor).toBe("var(--vulcan-body-bg)");
    expect(panels.at(2).element.style.backgroundColor).toBe("var(--vulcan-tertiary-bg)");
  });

  it("places borders between adjacent panels only", () => {
    const wrapper = mountWith();
    const panels = wrapper.findAll(".panel-layout__panel");

    expect(panels.at(0).classes()).toContain("panel-layout__panel--border-right");
    expect(panels.at(1).classes()).toContain("panel-layout__panel--border-right");
    expect(panels.at(2).classes()).not.toContain("panel-layout__panel--border-right");
  });

  // REQUIREMENT: an application shell is not a content grid. A sidebar
  // holds fixed-size content, so its width is a bounded design token; the
  // remaining panels share what is left. Sizing it as a fraction of the
  // viewport gives ~133px of content at the lg breakpoint, which is what
  // wrapped requirement identifiers onto two lines.
  it("sizes panels by role, never by a grid fraction", () => {
    const wrapper = mountWith();
    const panels = wrapper.findAll(".panel-layout__panel");
    expect(panels.at(0).classes()).toContain("panel-layout__panel--sidebar");
    expect(panels.at(1).classes()).toContain("panel-layout__panel--fill");
    expect(panels.at(2).classes()).toContain("panel-layout__panel--fill");

    panels.wrappers.forEach((panel) => {
      const fractional = panel.classes().filter((c) => /^col-(lg-)?\d+$/.test(c) && c !== "col-12");
      expect(fractional).toEqual([]);
    });
  });

  it("keeps the stacked full-width behavior below the lg breakpoint", () => {
    // col-12 is what stacks the panels on narrow viewports; the bounded
    // sidebar only takes effect at lg and up.
    const wrapper = mountWith();
    wrapper.findAll(".panel-layout__panel").wrappers.forEach((panel) => {
      expect(panel.classes()).toContain("col-12");
    });
  });

  it("rejects a panel whose size role is not one the layout knows", () => {
    const validator = PanelLayout.props.panels.validator;
    expect(validator([{ name: "left", size: "sidebar", bgTier: "secondary" }])).toBe(true);
    expect(validator([{ name: "left", size: "fill", bgTier: "body" }])).toBe(true);
    expect(validator([{ name: "left", size: "wide", bgTier: "body" }])).toBe(false);
    expect(validator([{ name: "left", bgTier: "body" }])).toBe(false);
  });

  it("renders header slot when provided", () => {
    const wrapper = mountWith(
      {},
      {
        "left-header": '<h6 data-testid="left-hdr">Nav</h6>',
      },
    );
    const hdr = wrapper.find('[data-testid="left-hdr"]');
    expect(hdr.exists()).toBe(true);
    expect(hdr.text()).toBe("Nav");
  });

  it("does not render header container when header slot is empty", () => {
    const wrapper = mountWith();
    const headers = wrapper.findAll(".panel-layout__header");
    expect(headers.length).toBe(0);
  });

  it("renders footer slot when provided", () => {
    const wrapper = mountWith(
      {},
      {
        "left-footer": '<div data-testid="left-ftr">Footer</div>',
      },
    );
    expect(wrapper.find('[data-testid="left-ftr"]').exists()).toBe(true);
  });

  it("supports 2-panel layout by omitting right panel", () => {
    const twoPanels = [
      { name: "left", size: "sidebar", bgTier: "secondary" },
      { name: "center", size: "fill", bgTier: "body" },
    ];
    const wrapper = mountWith(
      { panels: twoPanels },
      {
        left: "<div>Left</div>",
        center: "<div>Center</div>",
      },
    );
    const panels = wrapper.findAll(".panel-layout__panel");
    expect(panels.length).toBe(2);
  });

  it("panel body has overflow-auto and p-3 padding for independent scroll", () => {
    const wrapper = mountWith();
    const bodies = wrapper.findAll(".panel-layout__body");
    expect(bodies.length).toBe(3);
    bodies.wrappers.forEach((body) => {
      expect(body.classes()).toContain("overflow-auto");
      expect(body.classes()).toContain("p-3");
    });
  });

  it("each panel is d-flex flex-column for header/body/footer stacking", () => {
    const wrapper = mountWith();
    const panels = wrapper.findAll(".panel-layout__panel");
    panels.wrappers.forEach((panel) => {
      expect(panel.classes()).toContain("d-flex");
      expect(panel.classes()).toContain("flex-column");
    });
  });
});
