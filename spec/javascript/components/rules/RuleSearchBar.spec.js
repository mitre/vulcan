import { describe, it, expect, vi, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleSearchBar from "@/components/rules/RuleSearchBar.vue";

/**
 * RuleSearchBar requirements:
 *
 * 1. Renders a text input for filtering by rule ID
 * 2. Debounces input and emits 'search-updated' with the search text
 * 3. Renders a search icon that opens ComponentSearchModal via $bvModal
 * 4. Renders a "reset" link that emits 'clear-filters'
 * 5. Renders FindAndReplace component with correct props
 * 6. Renders an "Open comments only" toggle that emits 'update:open-comments-only'
 * 7. Emits 'search-result-selected' when ComponentSearchModal selects a result
 */
describe("RuleSearchBar", () => {
  let wrapper;

  const defaultProps = {
    componentId: 41,
    projectPrefix: "TEST",
    rules: [],
    readOnly: false,
    openCommentsOnly: false,
    searchValue: "",
  };

  const createWrapper = (props = {}) => {
    return shallowMount(RuleSearchBar, {
      localVue,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        BIcon: true,
        BFormCheckbox: true,
        FindAndReplace: true,
        ComponentSearchModal: true,
      },
      mocks: {
        $bvModal: { show: vi.fn() },
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  describe("rendering", () => {
    it("renders a text input for filtering rules", () => {
      wrapper = createWrapper();
      const input = wrapper.find("#ruleSearch");
      expect(input.exists()).toBe(true);
      expect(input.attributes("placeholder")).toContain("Filter");
    });

    it("renders FindAndReplace with component props", () => {
      wrapper = createWrapper();
      const far = wrapper.findComponent({ name: "FindAndReplace" });
      expect(far.exists()).toBe(true);
      expect(far.props("componentId")).toBe(41);
      expect(far.props("projectPrefix")).toBe("TEST");
    });

    it("renders ComponentSearchModal with correct props", () => {
      wrapper = createWrapper();
      const modal = wrapper.findComponent({ name: "ComponentSearchModal" });
      expect(modal.exists()).toBe(true);
      expect(modal.props("componentId")).toBe(41);
      expect(modal.props("projectPrefix")).toBe("TEST");
      expect(modal.props("searchType")).toBe("rules");
    });

    it("renders a clear link", () => {
      wrapper = createWrapper();
      const clear = wrapper.find('[data-test="clear-filters"]');
      expect(clear.exists()).toBe(true);
      expect(clear.text()).toContain("clear");
    });
  });

  describe("events", () => {
    it("emits clear-filters when reset is clicked", () => {
      wrapper = createWrapper();
      const reset = wrapper.find('[data-test="clear-filters"]');
      reset.trigger("click");
      expect(wrapper.emitted("clear-filters")).toBeTruthy();
    });

    it("emits search-result-selected when ComponentSearchModal selects a result", () => {
      wrapper = createWrapper();
      const modal = wrapper.findComponent({ name: "ComponentSearchModal" });
      const result = { id: 2, rule_id: "000002" };
      modal.vm.$emit("selected", result);
      expect(wrapper.emitted("search-result-selected")).toBeTruthy();
      expect(wrapper.emitted("search-result-selected")[0][0]).toEqual(result);
    });

    it("does not render open-comments-only toggle (moved to FilterBar Display section)", () => {
      wrapper = createWrapper();
      const toggle = wrapper.find('[data-test="filter-open-comments-only"]');
      expect(toggle.exists()).toBe(false);
    });
  });
});
