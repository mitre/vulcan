import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ActiveFilterPills from "@/components/rules/ActiveFilterPills.vue";

/**
 * ActiveFilterPills requirements (Baymard Institute — mandatory for faceted filters):
 *
 * 1. Renders a removable pill/badge for each active filter
 * 2. Each pill shows the filter's human-readable label
 * 3. Each pill has a dismiss (×) button that emits 'remove-filter' with the filter key
 * 4. "Clear all" link emits 'clear-all' to reset all filters
 * 5. Renders nothing when no filters are active
 * 6. Handles status filters, review filters, search text, and open-comments-only
 */
describe("ActiveFilterPills", () => {
  let wrapper;

  const defaultProps = {
    filters: {
      search: "",
      acFilterChecked: false,
      aimFilterChecked: false,
      adnmFilterChecked: false,
      naFilterChecked: false,
      nydFilterChecked: false,
      nurFilterChecked: false,
      urFilterChecked: false,
      lckFilterChecked: false,
      openCommentsOnly: false,
    },
  };

  const createWrapper = (props = {}) => {
    return shallowMount(ActiveFilterPills, {
      localVue,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        BBadge: true,
        BIcon: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("when no filters are active", () => {
    it("renders nothing", () => {
      wrapper = createWrapper();
      expect(wrapper.find('[data-test="active-filter-pills"]').exists()).toBe(false);
    });
  });

  describe("when status filters are active", () => {
    it("renders a pill for each checked status filter", () => {
      wrapper = createWrapper({
        filters: {
          ...defaultProps.filters,
          acFilterChecked: true,
          naFilterChecked: true,
        },
      });
      const pills = wrapper.findAll('[data-test="filter-pill"]');
      expect(pills.length).toBe(2);
    });

    it("shows human-readable labels on pills", () => {
      wrapper = createWrapper({
        filters: { ...defaultProps.filters, acFilterChecked: true },
      });
      const pill = wrapper.find('[data-test="filter-pill"]');
      expect(pill.text()).toContain("Configurable");
    });

    it("emits remove-filter with the key when pill dismiss is clicked", () => {
      wrapper = createWrapper({
        filters: { ...defaultProps.filters, acFilterChecked: true },
      });
      wrapper.find('[data-test="pill-dismiss"]').trigger("click");
      expect(wrapper.emitted("remove-filter")).toBeTruthy();
      expect(wrapper.emitted("remove-filter")[0][0]).toBe("acFilterChecked");
    });
  });

  describe("when review filters are active", () => {
    it("renders pills for review filters", () => {
      wrapper = createWrapper({
        filters: { ...defaultProps.filters, lckFilterChecked: true },
      });
      const pill = wrapper.find('[data-test="filter-pill"]');
      expect(pill.text()).toContain("Locked");
    });
  });

  describe("when search is active", () => {
    it("renders a pill showing the search text", () => {
      wrapper = createWrapper({
        filters: { ...defaultProps.filters, search: "000001" },
      });
      const pill = wrapper.find('[data-test="filter-pill"]');
      expect(pill.text()).toContain("000001");
    });
  });

  describe("when open comments only is active", () => {
    it("renders a pill for open comments only", () => {
      wrapper = createWrapper({
        filters: { ...defaultProps.filters, openCommentsOnly: true },
      });
      const pill = wrapper.find('[data-test="filter-pill"]');
      expect(pill.text()).toContain("Open Comments");
    });
  });

  describe("clear all", () => {
    it("renders clear-all link when any filter is active", () => {
      wrapper = createWrapper({
        filters: { ...defaultProps.filters, acFilterChecked: true },
      });
      const clearAll = wrapper.find('[data-test="clear-all-filters"]');
      expect(clearAll.exists()).toBe(true);
    });

    it("emits clear-all when clicked", () => {
      wrapper = createWrapper({
        filters: { ...defaultProps.filters, acFilterChecked: true },
      });
      wrapper.find('[data-test="clear-all-filters"]').trigger("click");
      expect(wrapper.emitted("clear-all")).toBeTruthy();
    });
  });
});
