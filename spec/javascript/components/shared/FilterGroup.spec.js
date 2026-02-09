import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import FilterGroup from "@/components/shared/FilterGroup.vue";

/**
 * FilterGroup Component Requirements:
 *
 * 1. Renders a card with a title header
 * 2. Renders a vertical list of toggle switches
 * 3. Each toggle has: label, optional count in parentheses, checked state
 * 4. Shows a "reset" link in the header
 * 5. Emits 'update:items' when a toggle changes
 * 6. Emits 'reset' when reset link is clicked
 */
describe("FilterGroup", () => {
  let wrapper;

  const defaultItems = [
    { key: "ac", label: "Applicable - Configurable", count: 264, checked: true },
    { key: "aim", label: "Applicable - Inherently Meets", count: 0, checked: true },
    { key: "adnm", label: "Applicable - Does Not Meet", count: 0, checked: false },
  ];

  const createWrapper = (props = {}) => {
    return shallowMount(FilterGroup, {
      localVue,
      propsData: {
        title: "Status",
        items: defaultItems,
        ...props,
      },
      stubs: {
        BIcon: true,
        BFormCheckbox: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  describe("rendering", () => {
    it("renders the filter group container", () => {
      wrapper = createWrapper();
      expect(wrapper.find(".filter-group").exists()).toBe(true);
    });

    it("displays the title", () => {
      wrapper = createWrapper({ title: "Status" });
      expect(wrapper.text()).toContain("Status");
    });

    it("displays the reset link", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("reset");
    });

    it("renders all toggle items", () => {
      wrapper = createWrapper();
      const toggles = wrapper.findAll(".filter-item");
      expect(toggles.length).toBe(3);
    });

    it("displays item labels", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Applicable - Configurable");
      expect(wrapper.text()).toContain("Applicable - Inherently Meets");
      expect(wrapper.text()).toContain("Applicable - Does Not Meet");
    });

    it("displays item counts in parentheses", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("(264)");
      expect(wrapper.text()).toContain("(0)");
    });

    it("does not display count when count is undefined", () => {
      wrapper = createWrapper({
        items: [{ key: "nest", label: "Nest Satisfied", checked: true }],
      });
      // Should not have parentheses for items without count
      expect(wrapper.text()).toContain("Nest Satisfied");
      expect(wrapper.text()).not.toMatch(/Nest Satisfied.*\(/);
    });
  });

  describe("toggle state", () => {
    it("sets checkbox checked state from items prop", () => {
      wrapper = createWrapper();
      const checkboxes = wrapper.findAllComponents({ name: "BFormCheckbox" });
      // First item should be checked (checked: true)
      expect(checkboxes.at(0).props("checked")).toBe(true);
      // Third item should be unchecked (checked: false)
      expect(checkboxes.at(2).props("checked")).toBe(false);
    });
  });

  describe("events", () => {
    it("emits update:items when a toggle changes", async () => {
      wrapper = createWrapper();
      const checkbox = wrapper.findComponent({ name: "BFormCheckbox" });
      await checkbox.vm.$emit("change", false);

      expect(wrapper.emitted("update:items")).toBeTruthy();
      const emittedItems = wrapper.emitted("update:items")[0][0];
      // First item should now be unchecked
      expect(emittedItems[0].checked).toBe(false);
    });

    it("emits reset when reset link is clicked", async () => {
      wrapper = createWrapper();
      const resetLink = wrapper.find(".reset-link");
      await resetLink.trigger("click");

      expect(wrapper.emitted("reset")).toBeTruthy();
    });
  });

  describe("accessibility", () => {
    it("uses semantic structure with header and body", () => {
      wrapper = createWrapper();
      expect(wrapper.find(".filter-group").exists()).toBe(true);
      expect(wrapper.find(".filter-group-header").exists()).toBe(true);
      expect(wrapper.find(".filter-group-body").exists()).toBe(true);
    });
  });

  describe("unique IDs", () => {
    it("generates unique IDs for checkboxes to prevent ID collisions", () => {
      wrapper = createWrapper();
      const checkboxes = wrapper.findAllComponents({ name: "BFormCheckbox" });

      // Each checkbox should have a unique ID containing the component uid and item key
      const ids = [];
      checkboxes.wrappers.forEach((checkbox, index) => {
        const id = checkbox.props("id");
        expect(id).toBeDefined();
        expect(id).toContain("filter-");
        expect(id).toContain(defaultItems[index].key);
        expect(ids).not.toContain(id); // Ensure uniqueness
        ids.push(id);
      });
    });

    it("generates different IDs for different component instances", () => {
      wrapper = createWrapper();
      const wrapper2 = createWrapper();

      const id1 = wrapper.findComponent({ name: "BFormCheckbox" }).props("id");
      const id2 = wrapper2.findComponent({ name: "BFormCheckbox" }).props("id");

      // Different component instances should have different IDs
      expect(id1).not.toBe(id2);

      wrapper2.destroy();
    });
  });
});
