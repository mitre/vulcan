import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import FilterBar from "@/components/shared/FilterBar.vue";
import { getDefaultFilters } from "@/composables/useRuleFilters";
import { groupEntries } from "@/constants/ruleFilterRegistry";

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

  const STIG_STATUSES = [
    "Not Yet Determined",
    "Applicable - Configurable",
    "Applicable - Inherently Meets",
    "Applicable - Does Not Meet",
    "Not Applicable",
  ];

  const SRG_STATUSES = ["Not Yet Determined", "Applicable", "Not Applicable"];

  const defaultFilters = {
    statusFilters: {
      "Not Yet Determined": true,
      "Applicable - Configurable": true,
      "Applicable - Inherently Meets": true,
      "Applicable - Does Not Meet": false,
      "Not Applicable": true,
    },
    nurFilterChecked: true,
    urFilterChecked: true,
    lckFilterChecked: true,
    nestSatisfiedRulesChecked: true,
    showSRGIdChecked: false,
    sortBySRGIdChecked: true,
    openCommentsOnly: false,
  };

  const defaultCounts = {
    statusCounts: {
      "Not Yet Determined": 0,
      "Applicable - Configurable": 264,
      "Applicable - Inherently Meets": 0,
      "Applicable - Does Not Meet": 0,
      "Not Applicable": 0,
    },
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
  describe("statusItems computed (vocabulary-derived)", () => {
    it("returns items keyed by status value in vocabulary order (NYD first)", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.statusItems;
      expect(items).toHaveLength(5);
      expect(items.map((i) => i.key)).toEqual(STIG_STATUSES);
    });

    it("status item labels are the status values", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.statusItems;
      expect(items.map((i) => i.label)).toEqual(STIG_STATUSES);
    });

    it("each status item carries dot=status so the toggle wears the status color", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.statusItems;
      // dot drives the .status-dot[data-status] palette in FilterGroup — it must
      // equal the status value so the toggle matches the sidebar dot / badge.
      expect(items.map((i) => i.dot)).toEqual(STIG_STATUSES);
    });

    it("status items include counts from statusCounts", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.statusItems;
      expect(items[0].count).toBe(0); // Not Yet Determined
      expect(items[1].count).toBe(264); // Applicable - Configurable
    });

    it("status items reflect checked state from the statusFilters map", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.statusItems;
      expect(items[0].checked).toBe(true); // Not Yet Determined
      expect(items[3].checked).toBe(false); // Applicable - Does Not Meet
    });

    it("passes status items to Status group", () => {
      wrapper = createWrapper();
      const statusGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(0);
      expect(statusGroup.props("items")).toHaveLength(5);
    });

    it("SRG vocabulary yields exactly three items — no STIG-only labels (leak regression)", () => {
      wrapper = createWrapper({
        filters: {
          ...defaultFilters,
          statusFilters: {
            "Not Yet Determined": false,
            Applicable: false,
            "Not Applicable": false,
          },
        },
        counts: {
          statusCounts: { "Not Yet Determined": 1, Applicable: 2, "Not Applicable": 0 },
          nur: 3,
          ur: 0,
          lck: 0,
        },
      });
      const items = wrapper.vm.statusItems;
      expect(items.map((i) => i.key)).toEqual(SRG_STATUSES);
      items.forEach((item) => {
        expect(item.label).not.toContain("Applicable - ");
      });
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
    it("returns 4 display items with correct keys", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.displayItems;
      expect(items).toHaveLength(4);
      expect(items.map((i) => i.key)).toEqual([
        "nestSatisfiedRulesChecked",
        "showSRGIdChecked",
        "sortBySRGIdChecked",
        "openCommentsOnly",
      ]);
    });

    it("display items have correct labels", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.displayItems;
      expect(items[0].label).toBe("Nest Satisfied");
      expect(items[1].label).toBe("SRG ID");
      expect(items[2].label).toBe("Sort SRG");
      expect(items[3].label).toBe("Open Comments Only");
    });

    it("display items do not have count property", () => {
      wrapper = createWrapper();
      const items = wrapper.vm.displayItems;
      items.forEach((item) => {
        expect(item.count).toBeUndefined();
      });
    });

    it("renders exactly the registry's display entries, in registry order", () => {
      // The component must not restate the toggle list. If a toggle is added
      // to the registry and this component keeps its own array, they drift —
      // which is the defect this card removes.
      wrapper = createWrapper();
      const fromRegistry = groupEntries("display");
      expect(wrapper.vm.displayItems.map((i) => i.key)).toEqual(fromRegistry.map((e) => e.key));
      expect(wrapper.vm.displayItems.map((i) => i.label)).toEqual(fromRegistry.map((e) => e.label));
    });

    it("disables a toggle that cannot act on this document kind, and says why", () => {
      // Authored SRG requirements carry no satisfaction keys, so nesting has
      // nothing to act on. It must present as unavailable with a reason,
      // never as a functional control that silently does nothing.
      wrapper = createWrapper({ documentType: "srg" });
      const nest = wrapper.vm.displayItems.find((i) => i.key === "nestSatisfiedRulesChecked");
      expect(nest.disabled).toBe(true);
      expect(typeof nest.disabledReason).toBe("string");
      expect(nest.disabledReason.length).toBeGreaterThan(0);

      // Kind-agnostic toggles stay usable on the same page.
      const srgId = wrapper.vm.displayItems.find((i) => i.key === "showSRGIdChecked");
      expect(srgId.disabled).toBe(false);
      expect(srgId.disabledReason).toBeUndefined();
    });

    it("shows an inapplicable toggle as off, because its effective value is off", () => {
      // The stored value may be true (it is the default), but on this kind the
      // pipeline cannot act on it, so rendering it ON would claim nesting is
      // happening when it provably is not. Show the effective state.
      wrapper = createWrapper({ documentType: "srg" });
      const nest = wrapper.vm.displayItems.find((i) => i.key === "nestSatisfiedRulesChecked");
      expect(defaultFilters.nestSatisfiedRulesChecked).toBe(true); // stored value
      expect(nest.checked).toBe(false); // effective value
    });

    it("never writes back a value for a control the user cannot operate", () => {
      // FilterGroup re-emits its WHOLE item array on any single toggle, and
      // items render the EFFECTIVE value for kind-inapplicable entries. Left
      // unguarded, toggling any other Display switch on an SRG page would
      // persist nestSatisfiedRulesChecked: false — a value the user never
      // touched, silently overwriting their stored default.
      wrapper = createWrapper({ documentType: "srg" });
      const items = wrapper.vm.displayItems.map((i) =>
        i.key === "showSRGIdChecked" ? { ...i, checked: true } : i,
      );

      wrapper.vm.onGroupUpdate(items);

      const emitted = wrapper.emitted("update:filters");
      expect(emitted).toBeTruthy();
      const payload = emitted[emitted.length - 1][0];
      expect(payload.showSRGIdChecked).toBe(true);
      // The stored value for the inapplicable entry must survive untouched.
      expect(payload.nestSatisfiedRulesChecked).toBe(defaultFilters.nestSatisfiedRulesChecked);
    });

    it("leaves every display toggle enabled on a stig component", () => {
      wrapper = createWrapper({ documentType: "stig" });
      wrapper.vm.displayItems.forEach((item) => {
        expect(item.disabled).toBe(false);
      });
    });
  });

  // ==========================================
  // EVENTS - UPDATE
  // ==========================================
  describe("update events", () => {
    it("emits update:filters when status group updates (status keys land in statusFilters)", async () => {
      wrapper = createWrapper();
      const statusGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(0);

      await statusGroup.vm.$emit("update:items", [
        { key: "Applicable - Configurable", checked: false },
      ]);

      expect(wrapper.emitted("update:filters")).toBeTruthy();
      const emitted = wrapper.emitted("update:filters")[0][0];
      expect(emitted.statusFilters["Applicable - Configurable"]).toBe(false);
      // Other filters should be preserved
      expect(emitted.statusFilters["Applicable - Inherently Meets"]).toBe(true);
    });

    it("emits update:filters when display group updates", async () => {
      wrapper = createWrapper();
      const displayGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(1);

      await displayGroup.vm.$emit("update:items", [{ key: "showSRGIdChecked", checked: true }]);

      expect(wrapper.emitted("update:filters")).toBeTruthy();
      const emitted = wrapper.emitted("update:filters")[0][0];
      expect(emitted.showSRGIdChecked).toBe(true);
    });

    it("emits update:filters when review group updates", async () => {
      wrapper = createWrapper();
      const reviewGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(2);

      await reviewGroup.vm.$emit("update:items", [{ key: "lckFilterChecked", checked: false }]);

      expect(wrapper.emitted("update:filters")).toBeTruthy();
      const emitted = wrapper.emitted("update:filters")[0][0];
      expect(emitted.lckFilterChecked).toBe(false);
    });

    it("merges multiple item updates into single filter emission", async () => {
      wrapper = createWrapper();
      const statusGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(0);

      await statusGroup.vm.$emit("update:items", [
        { key: "Applicable - Configurable", checked: false },
        { key: "Not Applicable", checked: false },
      ]);

      const emitted = wrapper.emitted("update:filters")[0][0];
      expect(emitted.statusFilters["Applicable - Configurable"]).toBe(false);
      expect(emitted.statusFilters["Not Applicable"]).toBe(false);
      // Others remain from original filters
      expect(emitted.statusFilters["Applicable - Inherently Meets"]).toBe(true);
    });
  });

  // ==========================================
  // EVENTS - RESET
  // ==========================================
  describe("reset events", () => {
    it("resets status filters (all unchecked) when status group emits reset", async () => {
      wrapper = createWrapper();
      const statusGroup = wrapper.findAllComponents({ name: "FilterGroup" }).at(0);
      await statusGroup.vm.$emit("reset");

      const emitted = wrapper.emitted("update:filters")[0][0];
      STIG_STATUSES.forEach((status) => {
        expect(emitted.statusFilters[status]).toBe(false);
      });
      // Review/display untouched by a status reset
      expect(emitted.nurFilterChecked).toBe(true);
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
      const defaults = getDefaultFilters(STIG_STATUSES);
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
      const defaults = getDefaultFilters(STIG_STATUSES);
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
