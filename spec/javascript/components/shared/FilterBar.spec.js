import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import FilterBar from "@/components/shared/FilterBar.vue";
import { getDefaultFilters } from "@/composables/useRuleFilters";

/**
 * FilterBar Component Requirements:
 *
 * 1. LAYOUT:
 *    - Renders a flex container with filter-bar class
 *    - Contains up to 3 FilterGroup children: Status, Display, Review
 *    - Groups render in order: Status, Display, Review
 *
 * 2. VISIBILITY:
 *    - showStatus controls Status group visibility
 *    - showDisplay controls Display group visibility
 *    - showReview controls Review group visibility
 *    - All visible by default
 *
 * 3. STATUS ITEMS:
 *    - 5 items: Applicable-Configurable, Applicable-Inherently Meets,
 *      Applicable-Does Not Meet, Not Applicable, Not Yet Determined
 *    - Each item has key, label, count, checked
 *
 * 4. REVIEW ITEMS:
 *    - 3 items: Not Under Review, Under Review, Locked
 *    - Each item has key, label, count, checked
 *
 * 5. DISPLAY ITEMS:
 *    - 3 items: Nest Satisfied, SRG ID, Sort SRG
 *    - No count on display items
 *
 * 6. EVENTS:
 *    - Emits 'update:filters' with merged filter object when any group updates
 *    - Reset events emit default filter values for the specific group
 *
 * 7. DISABLED STATE:
 *    - disabledStatus, disabledReview, disabledDisplay passed to respective groups
 */
describe("FilterBar", () => {
  let wrapper;

  const defaultFilters = {
    acFilterChecked: true,
    aimFilterChecked: true,
    adnmFilterChecked: false,
    naFilterChecked: true,
    nydFilterChecked: true,
    nurFilterChecked: true,
    urFilterChecked: true,
    lckFilterChecked: true,
    nestSatisfiedRulesChecked: true,
    showSRGIdChecked: false,
    sortBySRGIdChecked: true,
  };

  const defaultCounts = {
    ac: 264,
    aim: 0,
    adnm: 0,
    na: 0,
    nyd: 0,
    nur: 264,
    ur: 0,
    lck: 0,
  };

  const createWrapper = (props = {}) => {
    return shallowMount(FilterBar, {
      localVue,
      propsData: {
        filters: defaultFilters,
        counts: defaultCounts,
        showStatus: true,
        showReview: true,
        showDisplay: true,
        ...props,
      },
      stubs: {
        FilterGroup: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // ==========================================
  // LAYOUT
  // ==========================================
  describe("layout", () => {
    it("renders the filter-bar container with flex layout", () => {
      wrapper = createWrapper();
      const container = wrapper.find(".filter-bar");
      expect(container.exists()).toBe(true);
      expect(container.classes()).toContain("d-flex");
    });

    it("renders all three FilterGroups by default", () => {
      wrapper = createWrapper();
      const groups = wrapper.findAllComponents({ name: "FilterGroup" });
      expect(groups.length).toBe(3);
    });

    it("renders groups in order: Status, Display, Review", () => {
      wrapper = createWrapper();
      const groups = wrapper.findAllComponents({ name: "FilterGroup" });
      expect(groups.at(0).props("title")).toBe("Status");
      expect(groups.at(1).props("title")).toBe("Display");
      expect(groups.at(2).props("title")).toBe("Review");
    });
  });

  // ==========================================
  // VISIBILITY
  // ==========================================
  describe("visibility", () => {
    it("hides Status group when showStatus=false", () => {
      wrapper = createWrapper({ showStatus: false });
      const groups = wrapper.findAllComponents({ name: "FilterGroup" });
      expect(groups.length).toBe(2);
      const titles = groups.wrappers.map((g) => g.props("title"));
      expect(titles).not.toContain("Status");
    });

    it("hides Review group when showReview=false", () => {
      wrapper = createWrapper({ showReview: false });
      const groups = wrapper.findAllComponents({ name: "FilterGroup" });
      expect(groups.length).toBe(2);
      const titles = groups.wrappers.map((g) => g.props("title"));
      expect(titles).not.toContain("Review");
    });

    it("hides Display group when showDisplay=false", () => {
      wrapper = createWrapper({ showDisplay: false });
      const groups = wrapper.findAllComponents({ name: "FilterGroup" });
      expect(groups.length).toBe(2);
      const titles = groups.wrappers.map((g) => g.props("title"));
      expect(titles).not.toContain("Display");
    });

    it("renders only Status group when others are hidden", () => {
      wrapper = createWrapper({
        showStatus: true,
        showReview: false,
        showDisplay: false,
      });
      const groups = wrapper.findAllComponents({ name: "FilterGroup" });
      expect(groups.length).toBe(1);
      expect(groups.at(0).props("title")).toBe("Status");
    });

    it("renders no groups when all are hidden", () => {
      wrapper = createWrapper({
        showStatus: false,
        showReview: false,
        showDisplay: false,
      });
      const groups = wrapper.findAllComponents({ name: "FilterGroup" });
      expect(groups.length).toBe(0);
    });
  });

  // ==========================================
  // STATUS ITEMS
  // ==========================================
  describe("statusItems computed", () => {
    it("returns 5 status items with correct keys", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.statusItems;
      expect(items).toHaveLength(5);
      expect(items.map((i) => i.key)).toEqual([
        "acFilterChecked",
        "aimFilterChecked",
        "adnmFilterChecked",
        "naFilterChecked",
        "nydFilterChecked",
      ]);
    });

    it("status items have correct labels", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.statusItems;
      expect(items[0].label).toBe("Applicable - Configurable");
      expect(items[1].label).toBe("Applicable - Inherently Meets");
      expect(items[2].label).toBe("Applicable - Does Not Meet");
      expect(items[3].label).toBe("Not Applicable");
      expect(items[4].label).toBe("Not Yet Determined");
    });

    it("status items include counts from props", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.statusItems;
      expect(items[0].count).toBe(264); // ac
      expect(items[1].count).toBe(0); // aim
    });

    it("status items reflect checked state from filters prop", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.statusItems;
      expect(items[0].checked).toBe(true); // acFilterChecked
      expect(items[2].checked).toBe(false); // adnmFilterChecked
    });

    it("passes status items to Status group", () => {
      wrapper = createWrapper();
      const statusGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(0);
      expect(statusGroup.props("items")).toHaveLength(5);
    });
  });

  // ==========================================
  // REVIEW ITEMS
  // ==========================================
  describe("reviewItems computed", () => {
    it("returns 3 review items with correct keys", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.reviewItems;
      expect(items).toHaveLength(3);
      expect(items.map((i) => i.key)).toEqual([
        "nurFilterChecked",
        "urFilterChecked",
        "lckFilterChecked",
      ]);
    });

    it("review items have correct labels", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.reviewItems;
      expect(items[0].label).toBe("Not Under Review");
      expect(items[1].label).toBe("Under Review");
      expect(items[2].label).toBe("Locked");
    });
  });

  // ==========================================
  // DISPLAY ITEMS
  // ==========================================
  describe("displayItems computed", () => {
    it("returns 3 display items with correct keys", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.displayItems;
      expect(items).toHaveLength(3);
      expect(items.map((i) => i.key)).toEqual([
        "nestSatisfiedRulesChecked",
        "showSRGIdChecked",
        "sortBySRGIdChecked",
      ]);
    });

    it("display items have correct labels", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.displayItems;
      expect(items[0].label).toBe("Nest Satisfied");
      expect(items[1].label).toBe("SRG ID");
      expect(items[2].label).toBe("Sort SRG");
    });

    it("display items do not have count property", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.displayItems;
      items.forEach((item) => {
        expect(item.count).toBeUndefined();
      });
    });
  });

  // ==========================================
  // EVENTS - UPDATE
  // ==========================================
  describe("update events", () => {
    it("emits update:filters when status group updates", async () => {
      wrapper = createWrapper();
      const statusGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(0);

      await statusGroup.vm.$emit("update:items", [
        { key: "acFilterChecked", checked: false },
      ]);

      expect(wrapper.emitted("update:filters")).toBeTruthy();
      const emitted = wrapper.emitted("update:filters")[0][0];
      expect(emitted.acFilterChecked).toBe(false);
      // Other filters should be preserved
      expect(emitted.aimFilterChecked).toBe(true);
    });

    it("emits update:filters when display group updates", async () => {
      wrapper = createWrapper();
      const displayGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(1);

      await displayGroup.vm.$emit("update:items", [
        { key: "showSRGIdChecked", checked: true },
      ]);

      expect(wrapper.emitted("update:filters")).toBeTruthy();
      const emitted = wrapper.emitted("update:filters")[0][0];
      expect(emitted.showSRGIdChecked).toBe(true);
    });

    it("emits update:filters when review group updates", async () => {
      wrapper = createWrapper();
      const reviewGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(2);

      await reviewGroup.vm.$emit("update:items", [
        { key: "lckFilterChecked", checked: false },
      ]);

      expect(wrapper.emitted("update:filters")).toBeTruthy();
      const emitted = wrapper.emitted("update:filters")[0][0];
      expect(emitted.lckFilterChecked).toBe(false);
    });

    it("merges multiple item updates into single filter emission", async () => {
      wrapper = createWrapper();
      const statusGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(0);

      await statusGroup.vm.$emit("update:items", [
        { key: "acFilterChecked", checked: false },
        { key: "naFilterChecked", checked: false },
      ]);

      const emitted = wrapper.emitted("update:filters")[0][0];
      expect(emitted.acFilterChecked).toBe(false);
      expect(emitted.naFilterChecked).toBe(false);
      // Others remain from original filters
      expect(emitted.aimFilterChecked).toBe(true);
    });
  });

  // ==========================================
  // EVENTS - RESET
  // ==========================================
  describe("reset events", () => {
    it("resets status filters to defaults when status group emits reset", async () => {
      wrapper = createWrapper({
        filters: {
          ...defaultFilters,
          acFilterChecked: false,
          aimFilterChecked: false,
        },
      });
      const statusGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(0);
      await statusGroup.vm.$emit("reset");

      const emitted = wrapper.emitted("update:filters")[0][0];
      const defaults = getDefaultFilters();
      expect(emitted.acFilterChecked).toBe(defaults.acFilterChecked);
      expect(emitted.aimFilterChecked).toBe(defaults.aimFilterChecked);
      expect(emitted.adnmFilterChecked).toBe(defaults.adnmFilterChecked);
      expect(emitted.naFilterChecked).toBe(defaults.naFilterChecked);
      expect(emitted.nydFilterChecked).toBe(defaults.nydFilterChecked);
    });

    it("resets review filters to defaults when review group emits reset", async () => {
      wrapper = createWrapper({
        filters: {
          ...defaultFilters,
          nurFilterChecked: false,
        },
      });
      const reviewGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(2);
      await reviewGroup.vm.$emit("reset");

      const emitted = wrapper.emitted("update:filters")[0][0];
      const defaults = getDefaultFilters();
      expect(emitted.nurFilterChecked).toBe(defaults.nurFilterChecked);
      expect(emitted.urFilterChecked).toBe(defaults.urFilterChecked);
      expect(emitted.lckFilterChecked).toBe(defaults.lckFilterChecked);
    });

    it("resets display filters to defaults when display group emits reset", async () => {
      wrapper = createWrapper({
        filters: {
          ...defaultFilters,
          showSRGIdChecked: true,
        },
      });
      const displayGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(1);
      await displayGroup.vm.$emit("reset");

      const emitted = wrapper.emitted("update:filters")[0][0];
      const defaults = getDefaultFilters();
      expect(emitted.nestSatisfiedRulesChecked).toBe(defaults.nestSatisfiedRulesChecked);
      expect(emitted.showSRGIdChecked).toBe(defaults.showSRGIdChecked);
      expect(emitted.sortBySRGIdChecked).toBe(defaults.sortBySRGIdChecked);
    });
  });

  // ==========================================
  // DISABLED STATE
  // ==========================================
  describe("disabled state", () => {
    it("passes disabledStatus to Status group", () => {
      wrapper = createWrapper({ disabledStatus: true });
      const statusGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(0);
      expect(statusGroup.props("disabled")).toBe(true);
    });

    it("passes disabledDisplay to Display group", () => {
      wrapper = createWrapper({ disabledDisplay: true });
      const displayGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(1);
      expect(displayGroup.props("disabled")).toBe(true);
    });

    it("passes disabledReview to Review group", () => {
      wrapper = createWrapper({ disabledReview: true });
      const reviewGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(2);
      expect(reviewGroup.props("disabled")).toBe(true);
    });

    it("groups are not disabled by default", () => {
      wrapper = createWrapper();
      const groups = wrapper.findAllComponents({ name: "FilterGroup" });
      groups.wrappers.forEach((group) => {
        expect(group.props("disabled")).toBe(false);
      });
    });
  });
});
