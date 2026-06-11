import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ControlsCommandBar from "@/components/shared/ControlsCommandBar.vue";
import { PANEL_LABELS } from "@/constants/terminology";

/**
 * ControlsCommandBar - Unified Command Bar for VIEW and EDIT pages
 *
 * REQUIREMENTS:
 *
 * 1. MODE BEHAVIOR (controlled by readOnly prop):
 *    - VIEW mode (readOnly=true): Shows "Edit" button linking to /edit
 *    - EDIT mode (readOnly=false): Shows "View" button linking to /view
 *
 * 2. ACTIONS (left side):
 *    - Edit/View button: toggles based on mode, requires author+ permission
 *    - Release button: admin only, disabled when not releasable
 *    - Members button: always visible, opens members modal
 *    - Advanced Fields toggle: MOVED to RuleEditor (per-component DB setting)
 *
 * 3. COMPONENT PANELS (right side):
 *    - Details, Metadata, Questions, Comp History, Comp Reviews
 *    - Always enabled (component-level info doesn't depend on rule)
 *    - Toggle on click, emit 'toggle-panel' event
 *
 * 4. RULE PANELS: Moved to RuleActionsToolbar (rule-level, not component-level)
 *
 * 5. RULE CONTEXT BAR (shown when rule selected):
 *    - Displays rule ID with prefix, version
 *    - Status icons: lock, review, changes requested
 *    - Last editor info
 *    - NOTE: Related button moved to RuleActionsToolbar
 *
 * 6. VISUAL FEEDBACK:
 *    - Active panel button: 'secondary' variant
 *    - Inactive panel button: 'outline-secondary' variant
 */
describe("ControlsCommandBar", () => {
  let wrapper;

  const defaultComponent = {
    id: 41,
    name: "Test Component",
    prefix: "TEST",
    released: false,
    releasable: true,
    advanced_fields: false,
  };

  const defaultRule = {
    id: 1,
    rule_id: "00001",
    version: "SV-12345r1",
    component_id: 41,
    status: "Not Yet Determined",
    locked: false,
    review_requestor_id: null,
    changes_requested: false,
    histories: [{ name: "John Doe", created_at: "2024-01-15" }],
    updated_at: "2024-01-15T10:00:00Z",
  };

  const createWrapper = (props = {}, permissions = "admin") => {
    return mount(ControlsCommandBar, {
      localVue,
      provide: { effectivePermissions: permissions },
      propsData: {
        component: defaultComponent,
        selectedRule: null,
        activePanel: null,
        readOnly: true,
        ...props,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  describe("rendering", () => {
    it("renders the command bar container", () => {
      wrapper = createWrapper();
      expect(wrapper.find(".command-bar").exists()).toBe(true);
    });

    it("renders with bg-light background", () => {
      wrapper = createWrapper();
      expect(wrapper.find(".command-bar").classes()).toContain("bg-light");
    });
  });

  // ==========================================
  // TOOLBAR LAYOUT — 3 zones + overflow menu
  // Left: primary actions + overflow
  // Center: status indicator (comment chip)
  // Right: view toggle (filters)
  // Below toolbar: panel toggles row
  // ==========================================
  describe("toolbar layout", () => {
    it("left zone contains Edit and Comment as visible actions", () => {
      wrapper = createWrapper();
      const leftZone = wrapper.find("[data-testid='toolbar-actions']");
      expect(leftZone.exists()).toBe(true);
      expect(leftZone.text()).toContain("Edit");
      expect(leftZone.text()).toContain("Comment");
    });

    it("overflow menu is in the panel toggles row after Settings", () => {
      wrapper = createWrapper();
      const panelRow = wrapper.find("[data-testid='panel-toggles']");
      expect(panelRow.find("[data-testid='toolbar-overflow']").exists()).toBe(true);
    });

    it("center zone contains CommentStatusChip", () => {
      const futureDate = new Date(Date.now() + 7 * 86400000).toISOString();
      wrapper = createWrapper({
        component: {
          ...defaultComponent,
          comment_phase: "open",
          comment_period_ends_at: futureDate,
          pending_comment_count: 5,
        },
      });
      const centerZone = wrapper.find("[data-testid='toolbar-status']");
      expect(centerZone.exists()).toBe(true);
      expect(centerZone.findComponent({ name: "CommentStatusChip" }).exists()).toBe(true);
    });

    it("filter toggle is in the panel toggles row (right-aligned)", () => {
      wrapper = createWrapper({ showFilterToggle: true });
      const panelRow = wrapper.find("[data-testid='panel-toggles']");
      expect(panelRow.find("[data-testid='filter-toggle-btn']").exists()).toBe(true);
    });

    it("panel toggles are in a separate row below the toolbar", () => {
      wrapper = createWrapper();
      const panelGroup = wrapper.find("[data-testid='panel-toggles']");
      expect(panelGroup.exists()).toBe(true);
      expect(panelGroup.text()).toContain("Details");
      expect(panelGroup.text()).toContain("Metadata");
    });

    it("overflow dropdown contains Download", async () => {
      wrapper = createWrapper();
      const overflowBtn = wrapper.find("[data-testid='toolbar-overflow']");
      expect(overflowBtn.exists()).toBe(true);
      const dropdown = wrapper.findComponent({ name: "BDropdown" });
      expect(dropdown.exists()).toBe(true);
      expect(dropdown.text()).toContain("Download");
    });

    it("overflow dropdown contains Release for admin", () => {
      wrapper = createWrapper({}, "admin");
      const dropdown = wrapper.findComponent({ name: "BDropdown" });
      expect(dropdown.text()).toContain("Release");
    });

    it("overflow dropdown hides Release for non-admin", () => {
      wrapper = createWrapper({}, "viewer");
      const dropdown = wrapper.findComponent({ name: "BDropdown" });
      expect(dropdown.text()).not.toContain("Release");
    });

    it("shows Clear Filters button when activeFilterCount > 0", () => {
      wrapper = createWrapper({ showFilterToggle: true, activeFilterCount: 3 });
      const clearBtn = wrapper.find("[data-testid='clear-filters-btn']");
      expect(clearBtn.exists()).toBe(true);
      expect(clearBtn.text()).toContain("Clear Filters");
    });

    it("hides Clear Filters button when activeFilterCount is 0", () => {
      wrapper = createWrapper({ showFilterToggle: true, activeFilterCount: 0 });
      const clearBtn = wrapper.find("[data-testid='clear-filters-btn']");
      expect(clearBtn.exists()).toBe(false);
    });

    it("emits clear-filters when Clear Filters clicked", async () => {
      wrapper = createWrapper({ showFilterToggle: true, activeFilterCount: 2 });
      await wrapper.find("[data-testid='clear-filters-btn']").trigger("click");
      expect(wrapper.emitted("clear-filters")).toBeTruthy();
    });

    it("overflow button has a tooltip listing its contents", () => {
      wrapper = createWrapper();
      const dropdown = wrapper.find("[data-testid='toolbar-overflow']");
      expect(dropdown.attributes("title")).toBe("Download, Upload, Release");
    });
  });

  // ==========================================
  // TOOLTIPS — discoverability for all buttons
  // ==========================================
  describe("tooltips", () => {
    it("Edit button has tooltip", () => {
      wrapper = createWrapper({ readOnly: true });
      const btn = wrapper.find('a[href="/components/41/edit"]');
      expect(btn.attributes("title")).toBe("Switch to edit mode");
    });

    it("View button has tooltip", () => {
      wrapper = createWrapper({ readOnly: false });
      const btn = wrapper.find('a[href="/components/41"]');
      expect(btn.attributes("title")).toBe("Switch to view mode");
    });

    it("Comment button has tooltip", () => {
      wrapper = createWrapper();
      const btn = wrapper.find("[data-testid='comment-on-component-btn']");
      expect(btn.attributes("title")).toBe("Post a comment on this component");
    });

    it("Filters toggle has tooltip", () => {
      wrapper = createWrapper({ showFilterToggle: true });
      const btn = wrapper.find("[data-testid='filter-toggle-btn']");
      expect(btn.attributes("title")).toBe("Show or hide the filter bar");
    });

    it("Details button has tooltip", () => {
      wrapper = createWrapper();
      const btn = wrapper.findAll("button").wrappers.find((b) => b.text().includes("Details"));
      expect(btn.attributes("title")).toBe("Component details panel");
    });

    it("Metadata button has tooltip", () => {
      wrapper = createWrapper();
      const btn = wrapper.findAll("button").wrappers.find((b) => b.text().includes("Metadata"));
      expect(btn.attributes("title")).toBe("Component metadata panel");
    });

    it("Questions button has tooltip", () => {
      wrapper = createWrapper();
      const btn = wrapper.findAll("button").wrappers.find((b) => b.text().includes("Questions"));
      expect(btn.attributes("title")).toBe("Additional questions panel");
    });

    it("Activity button has tooltip", () => {
      wrapper = createWrapper();
      const btn = wrapper.findAll("button").wrappers.find((b) => b.text().includes("Activity"));
      expect(btn.attributes("title")).toBe("Component change history");
    });

    it("Triage button has tooltip", () => {
      wrapper = createWrapper();
      const btn = wrapper.find("[data-testid='triage-btn']");
      expect(btn.attributes("title")).toBe("Open comment triage page");
    });

    it("Settings button has tooltip", () => {
      wrapper = createWrapper();
      const btn = wrapper.findAll("a.btn").wrappers.find((b) => b.text().includes("Settings"));
      expect(btn.attributes("title")).toBe("Component settings");
    });

    it("Clear Filters button has tooltip", () => {
      wrapper = createWrapper({ showFilterToggle: true, activeFilterCount: 2 });
      const btn = wrapper.find("[data-testid='clear-filters-btn']");
      expect(btn.attributes("title")).toBe("Reset all active filters");
    });
  });

  // ==========================================
  // MODE BEHAVIOR (VIEW vs EDIT)
  // ==========================================
  describe("mode behavior", () => {
    describe("VIEW mode (readOnly=true)", () => {
      it("shows Edit button", () => {
        wrapper = createWrapper({ readOnly: true }, "admin");
        expect(wrapper.text()).toContain("Edit");
        expect(wrapper.text()).not.toContain("View");
      });

      it("Edit button links to edit page", () => {
        wrapper = createWrapper({ readOnly: true });
        const editLink = wrapper.find('a[href="/components/41/edit"]');
        expect(editLink.exists()).toBe(true);
      });
    });

    describe("EDIT mode (readOnly=false)", () => {
      it("shows View button", () => {
        wrapper = createWrapper({ readOnly: false }, "admin");
        expect(wrapper.text()).toContain("View");
      });

      it("View button links to view page", () => {
        wrapper = createWrapper({ readOnly: false });
        const viewLink = wrapper.find('a[href="/components/41"]');
        expect(viewLink.exists()).toBe(true);
      });
    });
  });

  // ==========================================
  // ACTIONS
  // ==========================================
  describe("Edit/View button permissions", () => {
    it("shows Edit button for admin", () => {
      wrapper = createWrapper({ readOnly: true }, "admin");
      expect(wrapper.text()).toContain("Edit");
    });

    it("shows Edit button for author", () => {
      wrapper = createWrapper({ readOnly: true }, "author");
      expect(wrapper.text()).toContain("Edit");
    });

    it("hides Edit button for viewer", () => {
      wrapper = createWrapper({ readOnly: true }, "viewer");
      const buttons = wrapper.findAll("a.btn");
      const editButton = buttons.wrappers.find((b) => b.text().includes("Edit"));
      expect(editButton).toBeUndefined();
    });
  });

  describe("Release (in overflow menu)", () => {
    it("shows Release item in overflow for admin", () => {
      wrapper = createWrapper({}, "admin");
      const dropdown = wrapper.findComponent({ name: "BDropdown" });
      expect(dropdown.text()).toContain("Release");
    });

    it("hides Release item for non-admin", () => {
      wrapper = createWrapper({}, "author");
      const dropdown = wrapper.findComponent({ name: "BDropdown" });
      expect(dropdown.text()).not.toContain("Release");
    });

    it("disables Release item when component not releasable", () => {
      wrapper = createWrapper({
        component: { ...defaultComponent, releasable: false },
      });
      const releaseItem = wrapper
        .findAllComponents({ name: "BDropdownItem" })
        .wrappers.find((w) => w.text().includes("Release"));
      expect(releaseItem.props("disabled")).toBe(true);
    });

    it("disables Release item when component already released", () => {
      wrapper = createWrapper({
        component: { ...defaultComponent, released: true },
      });
      const releaseItem = wrapper
        .findAllComponents({ name: "BDropdownItem" })
        .wrappers.find((w) => w.text().includes("Release"));
      expect(releaseItem.props("disabled")).toBe(true);
    });

    it("emits release event when clicked", async () => {
      wrapper = createWrapper();
      const releaseItem = wrapper
        .findAllComponents({ name: "BDropdownItem" })
        .wrappers.find((w) => w.text().includes("Release"));
      await releaseItem.vm.$emit("click");
      expect(wrapper.emitted("release")).toBeTruthy();
    });
  });

  // Advanced Fields toggle moved to RuleEditor (per-component setting)

  // Release button tests consolidated into "Release (in overflow menu)" above

  describe("Download (in overflow menu)", () => {
    it("renders Download in the overflow dropdown", () => {
      wrapper = createWrapper();
      const dropdown = wrapper.findComponent({ name: "BDropdown" });
      expect(dropdown.text()).toContain("Download");
    });

    it("emits download event when Download item clicked", async () => {
      wrapper = createWrapper();
      const downloadItem = wrapper
        .findAllComponents({ name: "BDropdownItem" })
        .wrappers.find((w) => w.text().includes("Download"));
      await downloadItem.vm.$emit("click");
      expect(wrapper.emitted("download")).toBeTruthy();
    });

    it("Download is available in BOTH view and edit modes", () => {
      wrapper = createWrapper({ readOnly: true });
      let dropdown = wrapper.findComponent({ name: "BDropdown" });
      expect(dropdown.text()).toContain("Download");
      wrapper.destroy();

      wrapper = createWrapper({ readOnly: false });
      dropdown = wrapper.findComponent({ name: "BDropdown" });
      expect(dropdown.text()).toContain("Download");
    });
  });

  // ==========================================
  // COMPONENT PANELS
  // ==========================================
  describe("component panel buttons", () => {
    it("renders the 4 component panel buttons + Triage link from terminology", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain(PANEL_LABELS.details);
      expect(wrapper.text()).toContain(PANEL_LABELS.metadata);
      expect(wrapper.text()).toContain(PANEL_LABELS.questions);
      expect(wrapper.text()).toContain(PANEL_LABELS.compHistory);
      // compReviews retired in PR #717 — replaced by a Triage link to
      // the full-page /components/:id/triage route.
      expect(wrapper.text()).toContain("Triage");
    });

    it("component panel buttons are NOT disabled when no rule selected", () => {
      wrapper = createWrapper({ selectedRule: null });
      const allButtons = wrapper.findAll("button");

      const detailsBtn = allButtons.wrappers.find((b) => b.text().includes("Details"));
      const metadataBtn = allButtons.wrappers.find((b) => b.text().includes("Metadata"));
      const questionsBtn = allButtons.wrappers.find((b) => b.text().includes("Questions"));

      expect(detailsBtn).toBeDefined();
      expect(metadataBtn).toBeDefined();
      expect(questionsBtn).toBeDefined();

      expect(detailsBtn.attributes("disabled")).toBeUndefined();
      expect(metadataBtn.attributes("disabled")).toBeUndefined();
      expect(questionsBtn.attributes("disabled")).toBeUndefined();
    });

    it("clicking Details button emits toggle-panel with details", async () => {
      wrapper = createWrapper();
      const detailsBtn = wrapper
        .findAll("button")
        .wrappers.find((b) => b.text().includes("Details"));
      await detailsBtn.trigger("click");
      expect(wrapper.emitted("toggle-panel")).toBeTruthy();
      expect(wrapper.emitted("toggle-panel").some((e) => e[0] === "details")).toBe(true);
    });

    it("clicking Metadata button emits toggle-panel with metadata", async () => {
      wrapper = createWrapper();
      const metadataBtn = wrapper
        .findAll("button")
        .wrappers.find((b) => b.text().includes("Metadata"));
      await metadataBtn.trigger("click");
      expect(wrapper.emitted("toggle-panel")).toBeTruthy();
      expect(wrapper.emitted("toggle-panel").some((e) => e[0] === "metadata")).toBe(true);
    });

    it("clicking Questions button emits toggle-panel with questions", async () => {
      wrapper = createWrapper();
      const questionsBtn = wrapper
        .findAll("button")
        .wrappers.find((b) => b.text().includes("Questions"));
      await questionsBtn.trigger("click");
      expect(wrapper.emitted("toggle-panel")).toBeTruthy();
      expect(wrapper.emitted("toggle-panel").some((e) => e[0] === "questions")).toBe(true);
    });
  });

  // ==========================================
  // RULE PANELS - Moved to RuleActionsToolbar
  // ==========================================
  // Rule-level panels (Satisfies, History, Reviews) are now in RuleActionsToolbar
  // because they operate on the selected rule, not the component.
  // See spec/javascript/components/rules/RuleActionsToolbar.spec.js

  // ==========================================
  // RULE CONTEXT BAR
  // ==========================================
  describe("rule context bar", () => {
    describe("when no rule selected", () => {
      it("does not render rule context bar", () => {
        wrapper = createWrapper({ selectedRule: null });
        expect(wrapper.find(".rule-context-bar").exists()).toBe(false);
      });
    });

    describe("when rule is selected", () => {
      it("renders rule context bar", () => {
        wrapper = createWrapper({ selectedRule: defaultRule });
        expect(wrapper.find(".rule-context-bar").exists()).toBe(true);
      });

      it("displays rule ID with component prefix", () => {
        wrapper = createWrapper({ selectedRule: defaultRule });
        expect(wrapper.text()).toContain("TEST-00001");
      });

      it("displays rule version", () => {
        wrapper = createWrapper({ selectedRule: defaultRule });
        expect(wrapper.text()).toContain("SV-12345r1");
      });

      it("shows lock icon when rule is locked", () => {
        wrapper = createWrapper({
          selectedRule: { ...defaultRule, locked: true },
        });
        // Lock icon has text-warning class in the rule context bar
        const ruleContextBar = wrapper.find(".rule-context-bar");
        expect(ruleContextBar.find(".text-warning").exists()).toBe(true);
      });

      it("shows review icon when rule is under review", () => {
        wrapper = createWrapper({
          selectedRule: { ...defaultRule, review_requestor_id: 123 },
        });
        // Review icon has text-info class in the rule context bar
        const ruleContextBar = wrapper.find(".rule-context-bar");
        expect(ruleContextBar.find(".text-info").exists()).toBe(true);
      });

      it("shows warning icon when changes are requested", () => {
        wrapper = createWrapper({
          selectedRule: { ...defaultRule, changes_requested: true },
        });
        // Warning icon has text-danger class in the rule context bar
        const ruleContextBar = wrapper.find(".rule-context-bar");
        expect(ruleContextBar.find(".text-danger").exists()).toBe(true);
      });

      it("shows last editor name", () => {
        wrapper = createWrapper({ selectedRule: defaultRule });
        expect(wrapper.text()).toContain("John Doe");
      });

      // NOTE: Related button moved to RuleActionsToolbar as a per-rule action
    });
  });

  // ==========================================
  // VISUAL FEEDBACK
  // ==========================================
  describe("active panel visual feedback", () => {
    it("active panel button has secondary variant", () => {
      wrapper = createWrapper({ activePanel: "details" });
      const detailsButton = wrapper
        .findAll("button")
        .wrappers.find((b) => b.text().includes("Details"));
      expect(detailsButton.classes()).toContain("btn-secondary");
    });

    it("inactive panel button has outline-secondary variant", () => {
      wrapper = createWrapper({ activePanel: "metadata" });
      const detailsButton = wrapper
        .findAll("button")
        .wrappers.find((b) => b.text().includes("Details"));
      expect(detailsButton.classes()).toContain("btn-outline-secondary");
    });
  });

  // ==========================================
  // FILTER TOGGLE BUTTON
  // ==========================================
  describe("filter toggle button", () => {
    it("renders filter toggle button when showFilterToggle is true", () => {
      wrapper = createWrapper({ showFilterToggle: true });
      const btn = wrapper.find("[data-testid='filter-toggle-btn']");
      expect(btn.exists()).toBe(true);
    });

    it("does not render filter toggle button when showFilterToggle is false (default)", () => {
      wrapper = createWrapper();
      const btn = wrapper.find("[data-testid='filter-toggle-btn']");
      expect(btn.exists()).toBe(false);
    });

    it("shows active filter count badge when activeFilterCount > 0", () => {
      wrapper = createWrapper({ showFilterToggle: true, activeFilterCount: 3 });
      const badge = wrapper.find("[data-testid='filter-toggle-btn'] .badge");
      expect(badge.exists()).toBe(true);
      expect(badge.text()).toBe("3");
    });

    it("hides badge when activeFilterCount is 0", () => {
      wrapper = createWrapper({ showFilterToggle: true, activeFilterCount: 0 });
      const badge = wrapper.find("[data-testid='filter-toggle-btn'] .badge");
      expect(badge.exists()).toBe(false);
    });

    it("emits toggle-filter-bar when clicked", async () => {
      wrapper = createWrapper({ showFilterToggle: true });
      await wrapper.find("[data-testid='filter-toggle-btn']").trigger("click");
      expect(wrapper.emitted("toggle-filter-bar")).toBeTruthy();
    });

    it("uses secondary variant when filterBarVisible is true", () => {
      wrapper = createWrapper({ showFilterToggle: true, filterBarVisible: true });
      const btn = wrapper.find("[data-testid='filter-toggle-btn']");
      expect(btn.classes()).toContain("btn-secondary");
    });

    it("uses outline-secondary variant when filterBarVisible is false", () => {
      wrapper = createWrapper({ showFilterToggle: true, filterBarVisible: false });
      const btn = wrapper.find("[data-testid='filter-toggle-btn']");
      expect(btn.classes()).toContain("btn-outline-secondary");
    });
  });

  // ==========================================
  // BREADCRUMBS
  // ==========================================
  describe("breadcrumbs", () => {
    it("renders breadcrumb items when provided", () => {
      const items = [
        { text: "Projects", href: "/projects" },
        { text: "My Project", href: "/projects/1" },
        { text: "Component V1R1", active: true },
      ];
      wrapper = createWrapper({ breadcrumbs: items });
      expect(wrapper.find("[data-testid='command-bar-breadcrumbs']").exists()).toBe(true);
      expect(wrapper.text()).toContain("Projects");
      expect(wrapper.text()).toContain("My Project");
      expect(wrapper.text()).toContain("Component V1R1");
    });

    it("does not render breadcrumbs when not provided", () => {
      wrapper = createWrapper();
      expect(wrapper.find("[data-testid='command-bar-breadcrumbs']").exists()).toBe(false);
    });

    it("renders breadcrumbs with links", () => {
      const items = [
        { text: "Projects", href: "/projects" },
        { text: "Component", active: true },
      ];
      wrapper = createWrapper({ breadcrumbs: items });
      const link = wrapper.find("[data-testid='command-bar-breadcrumbs'] a");
      expect(link.exists()).toBe(true);
      expect(link.attributes("href")).toBe("/projects");
    });
  });

  // ==========================================
  // COMMENT STATUS CHIP
  // ==========================================
  describe("comment status chip", () => {
    it("renders CommentStatusChip when component has comment phase data", () => {
      const futureDate = new Date(Date.now() + 7 * 86400000).toISOString();
      wrapper = createWrapper({
        component: {
          ...defaultComponent,
          comment_phase: "open",
          comment_period_ends_at: futureDate,
          pending_comment_count: 5,
        },
      });
      expect(wrapper.findComponent({ name: "CommentStatusChip" }).exists()).toBe(true);
    });

    it("forwards open-comments-panel event from chip", async () => {
      const futureDate = new Date(Date.now() + 7 * 86400000).toISOString();
      wrapper = createWrapper({
        component: {
          ...defaultComponent,
          comment_phase: "open",
          comment_period_ends_at: futureDate,
          pending_comment_count: 5,
        },
      });
      const chip = wrapper.findComponent({ name: "CommentStatusChip" });
      chip.vm.$emit("open-comments-panel");
      expect(wrapper.emitted("open-comments-panel")).toBeTruthy();
    });
  });
});
