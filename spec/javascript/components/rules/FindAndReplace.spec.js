import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import FindAndReplace from "@/components/rules/FindAndReplace.vue";

/**
 * FindAndReplace requirements:
 *
 * 1. Results section (hr + buttons) visible when find_results has entries
 * 2. Results section hidden when find_results is empty
 * 3. fr.fields initializes to the controlFields array (not undefined)
 * 4. Operator precedence: conditionals use Object.keys().length > 0
 */
describe("FindAndReplace", () => {
  let wrapper;

  const defaultProps = {
    componentId: 1,
    projectPrefix: "TEST",
    rules: [],
    readOnly: false,
  };

  const createWrapper = (props = {}, dataOverrides = {}) => {
    return shallowMount(FindAndReplace, {
      localVue,
      propsData: { ...defaultProps, ...props },
      data() {
        return dataOverrides;
      },
      stubs: {
        BButton: true,
        BModal: { template: "<div><slot /><slot name='modal-footer' /></div>" },
        BFormGroup: { template: "<div><slot /><slot name='label' /><slot name='default' /></div>" },
        BFormInput: true,
        BFormCheckbox: true,
        BCard: { template: "<div><slot /></div>", props: ["title"] },
        BCardText: { template: "<div><slot /></div>" },
        CommentModal: true,
        FindAndReplaceResult: true,
      },
      mocks: {
        $root: { $emit: () => {} },
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("results section visibility", () => {
    it("shows hr and button section when find_results has entries", () => {
      wrapper = createWrapper({}, {
        find_results: { "1": { rule_id: "000010", results: [] } },
      });
      const hrs = wrapper.findAll("hr");
      expect(hrs.length).toBeGreaterThanOrEqual(2);
    });

    it("hides hr and button section when find_results is empty", () => {
      wrapper = createWrapper({}, { find_results: {} });
      const hrs = wrapper.findAll("hr");
      expect(hrs.length).toBe(0);
    });
  });

  describe("fr.fields initialization", () => {
    it("initializes fr.fields to the controlFields array", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.fr.fields).toEqual(wrapper.vm.controlFields);
      expect(wrapper.vm.fr.fields).not.toBeUndefined();
      expect(wrapper.vm.fr.fields.length).toBe(8);
    });
  });
});
