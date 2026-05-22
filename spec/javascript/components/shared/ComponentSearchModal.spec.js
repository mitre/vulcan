import { describe, it, expect, afterEach, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ComponentSearchModal from "@/components/shared/ComponentSearchModal.vue";

/**
 * ComponentSearchModal requirements:
 *
 * 1. Renders search input with placeholder based on searchType
 * 2. Calls API with componentId + query after debounce (300ms, min 2 chars)
 * 3. Displays results with rule_id, snippet, field label
 * 4. Emits 'selected' with result object on click
 * 5. Keyboard nav: arrow keys move highlight, Enter selects
 * 6. Shows loading spinner during API call
 * 7. Shows "No results" when search returns empty
 * 8. Shows result count
 * 9. Esc closes modal
 * 10. Resets state on close
 */

// Mock axios at module level
vi.mock("axios", () => ({
  default: {
    get: vi.fn(),
    defaults: { headers: { common: {} } },
  },
}));

import axios from "axios";

describe("ComponentSearchModal", () => {
  let wrapper;

  const defaultProps = {
    componentId: 29,
    projectPrefix: "CNTR",
    searchType: "rules",
  };

  const mockRuleResults = {
    data: {
      rules: [
        {
          id: 101,
          rule_id: "000020",
          title: "The container platform must enforce access",
          status: "Applicable - Configurable",
          component_id: 29,
          component_prefix: "CNTR",
          snippet: "[Title] ...the container platform must enforce...",
        },
        {
          id: 102,
          rule_id: "000030",
          title: "Container runtime must limit privileges",
          status: "Applicable - Configurable",
          component_id: 29,
          component_prefix: "CNTR",
          snippet: "[Fixtext] ...configure container runtime...",
        },
      ],
    },
  };

  const createWrapper = (props = {}) => {
    return mount(ComponentSearchModal, {
      localVue,
      propsData: { ...defaultProps, ...props },
      stubs: {
        BModal: {
          template:
            '<div class="modal"><slot /><slot name="modal-footer" /></div>',
          methods: { show: vi.fn(), hide: vi.fn() },
        },
        BSpinner: true,
        BIcon: true,
        BListGroup: { template: '<div class="list-group"><slot /></div>' },
        BListGroupItem: {
          template:
            '<div class="list-group-item" @click="$emit(\'click\')"><slot /></div>',
          props: ["active"],
        },
        BFormInput: {
          template: '<input class="form-control" />',
          props: ["value", "debounce", "placeholder"],
        },
        BInputGroup: { template: "<div><slot /></div>" },
        BInputGroupPrepend: { template: "<div><slot /></div>" },
        BInputGroupText: { template: "<div><slot /></div>" },
        BBadge: { template: "<span><slot /></span>" },
      },
      mocks: {
        $bvModal: { show: vi.fn(), hide: vi.fn() },
      },
    });
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("initialization", () => {
    it("renders with search input placeholder for rules mode", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.placeholder).toBe("Search requirements...");
    });

    it("renders with search input placeholder for comments mode", () => {
      wrapper = createWrapper({ searchType: "comments" });
      expect(wrapper.vm.placeholder).toBe("Search comments...");
    });

    it("initializes with empty results and no loading", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.results).toEqual([]);
      expect(wrapper.vm.loading).toBe(false);
      expect(wrapper.vm.highlightedIndex).toBe(-1);
    });
  });

  describe("search behavior", () => {
    it("does not search when query is less than 2 characters", async () => {
      wrapper = createWrapper();
      await wrapper.vm.performSearch("a");
      expect(axios.get).not.toHaveBeenCalled();
    });

    it("calls API with component_id when query is 2+ characters", async () => {
      axios.get.mockResolvedValue(mockRuleResults);
      wrapper = createWrapper();
      await wrapper.vm.performSearch("container");
      expect(axios.get).toHaveBeenCalledWith("/api/search/global", {
        params: { q: "container", limit: 20, component_id: 29 },
      });
    });

    it("populates results from API response", async () => {
      axios.get.mockResolvedValue(mockRuleResults);
      wrapper = createWrapper();
      await wrapper.vm.performSearch("container");
      expect(wrapper.vm.results.length).toBe(2);
      expect(wrapper.vm.results[0].rule_id).toBe("000020");
      expect(wrapper.vm.results[1].rule_id).toBe("000030");
    });

    it("sets loading true during API call and false after", async () => {
      let resolvePromise;
      axios.get.mockReturnValue(
        new Promise((resolve) => {
          resolvePromise = resolve;
        }),
      );
      wrapper = createWrapper();
      const searchPromise = wrapper.vm.performSearch("container");
      expect(wrapper.vm.loading).toBe(true);
      resolvePromise(mockRuleResults);
      await searchPromise;
      expect(wrapper.vm.loading).toBe(false);
    });

    it("clears results when query becomes empty", async () => {
      axios.get.mockResolvedValue(mockRuleResults);
      wrapper = createWrapper();
      await wrapper.vm.performSearch("container");
      expect(wrapper.vm.results.length).toBe(2);
      await wrapper.vm.performSearch("");
      expect(wrapper.vm.results).toEqual([]);
    });
  });

  describe("keyboard navigation", () => {
    it("moves highlight down with ArrowDown", async () => {
      axios.get.mockResolvedValue(mockRuleResults);
      wrapper = createWrapper();
      await wrapper.vm.performSearch("container");
      // First result auto-highlighted on search
      expect(wrapper.vm.highlightedIndex).toBe(0);
      wrapper.vm.onKeyDown({ key: "ArrowDown", preventDefault: vi.fn() });
      expect(wrapper.vm.highlightedIndex).toBe(1);
    });

    it("wraps highlight to top when past last result", async () => {
      axios.get.mockResolvedValue(mockRuleResults);
      wrapper = createWrapper();
      await wrapper.vm.performSearch("container");
      wrapper.vm.highlightedIndex = 1;
      wrapper.vm.onKeyDown({ key: "ArrowDown", preventDefault: vi.fn() });
      expect(wrapper.vm.highlightedIndex).toBe(0);
    });

    it("moves highlight up with ArrowUp", async () => {
      axios.get.mockResolvedValue(mockRuleResults);
      wrapper = createWrapper();
      await wrapper.vm.performSearch("container");
      wrapper.vm.highlightedIndex = 1;
      wrapper.vm.onKeyDown({ key: "ArrowUp", preventDefault: vi.fn() });
      expect(wrapper.vm.highlightedIndex).toBe(0);
    });

    it("emits selected on Enter with highlighted result", async () => {
      axios.get.mockResolvedValue(mockRuleResults);
      wrapper = createWrapper();
      await wrapper.vm.performSearch("container");
      wrapper.vm.highlightedIndex = 0;
      wrapper.vm.onKeyDown({ key: "Enter", preventDefault: vi.fn() });
      expect(wrapper.emitted("selected")).toBeTruthy();
      expect(wrapper.emitted("selected")[0][0].rule_id).toBe("000020");
    });

    it("does not emit selected on Enter with no highlight", async () => {
      wrapper = createWrapper();
      wrapper.vm.onKeyDown({ key: "Enter", preventDefault: vi.fn() });
      expect(wrapper.emitted("selected")).toBeFalsy();
    });
  });

  describe("result display", () => {
    it("formats result label with project prefix and rule_id", async () => {
      axios.get.mockResolvedValue(mockRuleResults);
      wrapper = createWrapper();
      await wrapper.vm.performSearch("container");
      const label = wrapper.vm.formatResultLabel(wrapper.vm.results[0]);
      expect(label).toBe("CNTR-000020");
    });

    it("reports result count", async () => {
      axios.get.mockResolvedValue(mockRuleResults);
      wrapper = createWrapper();
      await wrapper.vm.performSearch("container");
      expect(wrapper.vm.resultCount).toBe("2 results");
    });

    it("reports singular result count", async () => {
      axios.get.mockResolvedValue({
        data: { rules: [mockRuleResults.data.rules[0]] },
      });
      wrapper = createWrapper();
      await wrapper.vm.performSearch("container");
      expect(wrapper.vm.resultCount).toBe("1 result");
    });
  });

  describe("reset on close", () => {
    it("clears query, results, and highlight on modal hidden", () => {
      wrapper = createWrapper();
      wrapper.vm.query = "test";
      wrapper.vm.results = [{ id: 1 }];
      wrapper.vm.highlightedIndex = 2;
      wrapper.vm.onModalHidden();
      expect(wrapper.vm.query).toBe("");
      expect(wrapper.vm.results).toEqual([]);
      expect(wrapper.vm.highlightedIndex).toBe(-1);
    });
  });
});
