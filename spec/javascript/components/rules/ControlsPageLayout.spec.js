import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ControlsPageLayout from "@/components/rules/ControlsPageLayout.vue";

/**
 * ControlsPageLayout Requirements:
 *
 * 1. Layout Structure:
 *    - Command bar (optional, controlled by showCommandBar prop)
 *    - Filter bar (optional, controlled by showFilterBar prop)
 *    - Two-column layout: left sidebar + main content
 *
 * 2. Conditional Rendering:
 *    - Main content shows when hasSelectedRule=true, empty state otherwise
 *    - Command bar and filter bar are independent of rule selection
 *    - Modals and right-panels ALWAYS render (they contain slideovers that
 *      may show component-level info even without a rule selected)
 *
 * 3. Responsive:
 *    - Mobile: full width columns
 *    - Desktop: configurable sidebar width
 */
describe("ControlsPageLayout", () => {
  let wrapper;

  const createWrapper = (props = {}, slots = {}) => {
    return mount(ControlsPageLayout, {
      localVue,
      propsData: {
        hasSelectedRule: false,
        ...props,
      },
      slots: {
        "left-sidebar": '<div class="test-left-sidebar">Left Sidebar</div>',
        "main-content": '<div class="test-main-content">Main Content</div>',
        modals: '<div class="test-modals">Modals</div>',
        "right-panels": '<div class="test-right-panels">Right Panels</div>',
        ...slots,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  describe("layout structure", () => {
    it("renders the layout container", () => {
      wrapper = createWrapper();
      expect(wrapper.find(".controls-page-layout").exists()).toBe(true);
    });

    it("root element has vulcan-editor-layout class for flex chain continuity", () => {
      wrapper = createWrapper();
      expect(wrapper.classes()).toContain("vulcan-editor-layout");
    });

    it("renders the two-column row", () => {
      wrapper = createWrapper();
      expect(wrapper.find(".row").exists()).toBe(true);
    });

    it("always renders left sidebar slot", () => {
      wrapper = createWrapper();
      expect(wrapper.find(".test-left-sidebar").exists()).toBe(true);
    });
  });

  describe("main content area", () => {
    it("shows main content when rule is selected", () => {
      wrapper = createWrapper({ hasSelectedRule: true });
      expect(wrapper.find(".test-main-content").exists()).toBe(true);
      expect(wrapper.text()).not.toContain("No control currently selected");
    });

    it("shows empty state when no rule is selected", () => {
      wrapper = createWrapper({ hasSelectedRule: false });
      expect(wrapper.find(".test-main-content").exists()).toBe(false);
      expect(wrapper.text()).toContain("No control currently selected");
    });

    it("uses custom emptyStateMessage when provided", () => {
      wrapper = createWrapper({
        hasSelectedRule: false,
        emptyStateMessage: "Please select a rule",
      });
      expect(wrapper.text()).toContain("Please select a rule");
    });
  });

  describe("command bar slot", () => {
    it("does not render command-bar when showCommandBar is false (default)", () => {
      wrapper = createWrapper(
        {},
        {
          "command-bar": '<div class="test-command-bar">Command Bar</div>',
        },
      );
      expect(wrapper.find(".test-command-bar").exists()).toBe(false);
    });

    it("renders command-bar when showCommandBar is true", () => {
      wrapper = createWrapper(
        { showCommandBar: true },
        { "command-bar": '<div class="test-command-bar">Command Bar</div>' },
      );
      expect(wrapper.find(".test-command-bar").exists()).toBe(true);
    });

    it("renders command-bar regardless of rule selection (for component-level actions)", () => {
      // IMPORTANT: Command bar should show even without a selected rule
      // because it contains component-level actions like Edit, Release, Members
      wrapper = createWrapper(
        { showCommandBar: true, hasSelectedRule: false },
        { "command-bar": '<div class="test-command-bar">Command Bar</div>' },
      );
      expect(wrapper.find(".test-command-bar").exists()).toBe(true);
    });
  });

  describe("filter bar slot", () => {
    it("does not render filter-bar when showFilterBar is false (default)", () => {
      wrapper = createWrapper(
        {},
        {
          "filter-bar": '<div class="test-filter-bar">Filter Bar</div>',
        },
      );
      expect(wrapper.find(".test-filter-bar").exists()).toBe(false);
    });

    it("renders filter-bar when showFilterBar is true", () => {
      wrapper = createWrapper(
        { showFilterBar: true },
        { "filter-bar": '<div class="test-filter-bar">Filter Bar</div>' },
      );
      expect(wrapper.find(".test-filter-bar").exists()).toBe(true);
    });
  });

  describe("modals slot", () => {
    // CRITICAL: Modals must ALWAYS render regardless of rule selection
    // They contain component-level modals (Members, etc.) that work without a rule

    it("always renders modals slot regardless of rule selection", () => {
      wrapper = createWrapper({ hasSelectedRule: false });
      expect(wrapper.find(".test-modals").exists()).toBe(true);
    });

    it("renders modals slot when rule is selected", () => {
      wrapper = createWrapper({ hasSelectedRule: true });
      expect(wrapper.find(".test-modals").exists()).toBe(true);
    });
  });

  describe("right-panels slot (slideovers)", () => {
    // CRITICAL: Right panels (slideovers) must ALWAYS render regardless of rule selection
    // They contain:
    // - Component-level panels (Details, Metadata, Questions, History, Reviews)
    // - Rule-level panels (Satisfies, Reviews, History) - disabled when no rule selected
    //
    // If they don't render, clicking panel buttons does nothing (the bug we fixed)

    it("always renders right-panels slot regardless of rule selection", () => {
      wrapper = createWrapper({ hasSelectedRule: false });
      expect(wrapper.find(".test-right-panels").exists()).toBe(true);
    });

    it("renders right-panels slot when rule is selected", () => {
      wrapper = createWrapper({ hasSelectedRule: true });
      expect(wrapper.find(".test-right-panels").exists()).toBe(true);
    });
  });

  describe("panel sizing via PanelLayout", () => {
    // REQUIREMENT: the editor shell's sidebar holds fixed-size content —
    // a requirement identifier of known maximum width, a status dot, an
    // icon strip. Its width requirement is intrinsic, so it is sized by a
    // bounded design token; the main panel takes what is left. A viewport
    // FRACTION is the wrong model and is what wrapped identifiers at lg.
    it("declares a bounded sidebar and a filling main panel", () => {
      wrapper = createWrapper({ hasSelectedRule: true });
      const panelLayout = wrapper.findComponent({ name: "PanelLayout" });
      expect(panelLayout.exists()).toBe(true);

      const panels = panelLayout.props("panels");
      expect(panels[0].name).toBe("left");
      expect(panels[0].size).toBe("sidebar");
      expect(panels[1].name).toBe("center");
      expect(panels[1].size).toBe("fill");
    });

    it("carries no column count — width is the layout's concern, not the page's", () => {
      wrapper = createWrapper({ hasSelectedRule: true });
      const panels = wrapper.findComponent({ name: "PanelLayout" }).props("panels");
      panels.forEach((panel) => {
        expect(panel.cols).toBeUndefined();
      });
      expect(ControlsPageLayout.props.sidebarWidth).toBeUndefined();
    });
  });
});
