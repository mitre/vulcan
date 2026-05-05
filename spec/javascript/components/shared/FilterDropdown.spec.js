import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import FilterDropdown from "@/components/shared/FilterDropdown.vue";

/**
 * REQUIREMENTS:
 * FilterDropdown is a shared, viewport-aware filter dropdown used in
 * RuleReviews, UserComments, and ComponentComments. It MUST:
 *   - Use <b-dropdown> (not native <select>) so the menu obeys
 *     boundary="viewport" and never clips off-screen.
 *   - v-model the current selection (emits "input" on change).
 *   - Mark the active option in the menu so users see what's selected.
 *   - Render the friendly label of the current selection on the trigger
 *     button (falls back to the placeholder when value has no match).
 *   - Surface aria-label for screen readers.
 *   - Accept null as a valid option value (e.g. "(general)" maps to null).
 *
 * Why this exists: <b-form-select> wraps the browser-controlled native
 * <select>, which ignores Vue boundary props and clips at viewport
 * edges in slideovers and narrow panels. Caught live on the rule
 * reviews slideover (Apr 29 2026, screenshot in PR-717 working notes).
 */
describe("FilterDropdown", () => {
  const statusOptions = [
    { value: "all", text: "All statuses" },
    { value: "pending", text: "Pending" },
    { value: "concur", text: "Accept" },
  ];

  const sectionOptions = [
    { value: "all", text: "All sections" },
    { value: null, text: "(general)" },
    { value: "check_content", text: "Check" },
  ];

  const mountWith = (props) =>
    mount(FilterDropdown, {
      localVue,
      propsData: { ariaLabel: "Filter", options: statusOptions, value: "all", ...props },
    });

  describe("rendering", () => {
    it("renders a b-dropdown (NOT a native select)", () => {
      const w = mountWith();
      expect(w.find("select").exists()).toBe(false);
      expect(w.findComponent({ name: "BDropdown" }).exists()).toBe(true);
    });

    it("shows the friendly label of the current value on the trigger", () => {
      const w = mountWith({ value: "pending" });
      expect(w.text()).toContain("Pending");
    });

    it("falls back to the placeholder when value has no matching option", () => {
      const w = mountWith({ value: "not_a_value", placeholder: "—" });
      expect(w.text()).toContain("—");
    });

    it("sets boundary='viewport' on the underlying b-dropdown", () => {
      const w = mountWith();
      const dd = w.findComponent({ name: "BDropdown" });
      expect(dd.props("boundary")).toBe("viewport");
    });

    it("sets the aria-label on the trigger button", () => {
      const w = mountWith({ ariaLabel: "Filter by status" });
      // BDropdown surfaces aria-label via the toggle-* prop or attrs; assert
      // present in HTML
      expect(w.html()).toContain('aria-label="Filter by status"');
    });
  });

  describe("v-model behavior", () => {
    it("emits 'input' with the option value when an item is clicked", async () => {
      const w = mountWith({ value: "all" });
      // BDropdownItemButton renders a <button class="dropdown-item">; click
      // the inner button (vue-test-utils trigger doesn't propagate through
      // the BootstrapVue wrapper component).
      const buttons = w.findAll("button.dropdown-item");
      await buttons.at(1).trigger("click");
      expect(w.emitted("input")).toBeTruthy();
      expect(w.emitted("input")[0]).toEqual(["pending"]);
    });

    it("marks the option matching value as active", () => {
      const w = mountWith({ value: "pending" });
      const items = w.findAllComponents({ name: "BDropdownItemButton" });
      expect(items.at(0).props("active")).toBe(false); // "all"
      expect(items.at(1).props("active")).toBe(true); // "pending"
      expect(items.at(2).props("active")).toBe(false); // "concur"
    });
  });

  describe("null-valued options (e.g. section '(general)')", () => {
    it("renders an option with value=null without crashing", () => {
      const w = mountWith({ options: sectionOptions, value: null });
      expect(w.text()).toContain("(general)");
      // null option must be flagged active when value is null
      const items = w.findAllComponents({ name: "BDropdownItemButton" });
      expect(items.at(1).props("active")).toBe(true);
    });

    it("emits null when the (general) option is clicked", async () => {
      const w = mountWith({ options: sectionOptions, value: "all" });
      const buttons = w.findAll("button.dropdown-item");
      await buttons.at(1).trigger("click");
      expect(w.emitted("input")[0]).toEqual([null]);
    });
  });
});
