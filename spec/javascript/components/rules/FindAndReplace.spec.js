import { describe, it, expect, afterEach, vi, beforeEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue, flushPromises } from "@test/testHelper";
import FindAndReplace from "@/components/rules/FindAndReplace.vue";

vi.mock("@/composables/useFindAndReplace", { spy: true });
import { useFindAndReplace } from "@/composables/useFindAndReplace";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: {} })),
    put: vi.fn(() => Promise.resolve({ data: {} })),
    post: vi.fn(() => Promise.resolve({ data: {} })),
    patch: vi.fn(() => Promise.resolve({ data: {} })),
    delete: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } },
  },
}));

vi.mock("@/api/rulesApi", () => ({
  updateRule: vi.fn(() => Promise.resolve({ data: {} })),
  findInComponent: vi.fn(() => Promise.resolve({ data: {} })),
}));

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
      wrapper = createWrapper(
        {},
        {
          find_results: { 1: { rule_id: "000010", results: [] } },
        },
      );
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

  describe("API calls use domain modules", () => {
    beforeEach(() => vi.resetAllMocks());

    it("find() calls findInComponent with componentId and search text", async () => {
      const { findInComponent } = await import("@/api/rulesApi");
      findInComponent.mockResolvedValueOnce({ data: [] });

      wrapper = createWrapper();
      wrapper.vm.fr.find = "test search";
      wrapper.vm.find();

      expect(findInComponent).toHaveBeenCalledWith(1, "test search");
    });

    it("replace_one() calls updateRule with rule id and payload", async () => {
      const { updateRule, findInComponent } = await import("@/api/rulesApi");
      updateRule.mockResolvedValueOnce({
        data: { toast: { title: "ok", message: [], variant: "success" } },
      });
      findInComponent.mockResolvedValueOnce({ data: [] });

      const mockRule = {
        id: 42,
        rule_id: "001",
        status: "Not Yet Determined",
      };
      wrapper = createWrapper({ rules: [mockRule] });
      const result = { field: "fixtext", segments: [{ text: "old", highlighted: true }] };
      wrapper.vm.replace_one(42, result, "audit comment");

      expect(updateRule).toHaveBeenCalledWith(
        42,
        expect.objectContaining({
          audit_comment: "audit comment",
        }),
      );
    });

    it("replace_all() calls updateRule for each rule in results", async () => {
      const { updateRule, findInComponent } = await import("@/api/rulesApi");
      updateRule.mockResolvedValue({
        data: { toast: { title: "ok", message: [], variant: "success" } },
      });
      findInComponent.mockResolvedValue({ data: [] });

      const mockRules = [
        { id: 10, rule_id: "001", status: "NYD" },
        { id: 20, rule_id: "002", status: "NYD" },
      ];
      wrapper = createWrapper(
        { rules: mockRules },
        {
          find_results: {
            10: {
              rule_id: "001",
              results: [{ field: "fixtext", segments: [{ text: "x", highlighted: true }] }],
            },
            20: {
              rule_id: "002",
              results: [{ field: "fixtext", segments: [{ text: "x", highlighted: true }] }],
            },
          },
        },
      );

      wrapper.vm.replace_all("bulk comment");

      expect(updateRule).toHaveBeenCalledTimes(2);
      expect(updateRule).toHaveBeenCalledWith(
        "10",
        expect.objectContaining({
          audit_comment: "bulk comment",
        }),
      );
      expect(updateRule).toHaveBeenCalledWith(
        "20",
        expect.objectContaining({
          audit_comment: "bulk comment",
        }),
      );
    });
  });

  // ── composable contracts ────────────────────────────────────────────
  // REQUIREMENT: the find/replace engine flows through useFindAndReplace
  // — no FindAndReplaceMixin remains (toasts come from the useToast
  // composable).
  describe("composable contracts", () => {
    it("groups find results via useFindAndReplace with highlighted segments", async () => {
      const { findInComponent } = await import("@/api/rulesApi");
      findInComponent.mockResolvedValueOnce({
        data: [{ id: 7, rule_id: "000010", title: "Ensure SSH uses FIPS ciphers" }],
      });

      wrapper = createWrapper();
      expect(useFindAndReplace).toHaveBeenCalled();

      wrapper.vm.fr.find = "ssh";
      wrapper.vm.find();
      await flushPromises(wrapper);

      // grouped by rule DB id, keyed results carry the matched field
      expect(wrapper.vm.find_results[7].rule_id).toBe("000010");
      expect(wrapper.vm.find_results[7].results[0].field).toBe("Title");
      // case-insensitive match highlights the ORIGINAL casing
      const segments = wrapper.vm.find_results[7].results[0].segments;
      expect(segments.find((s) => s.highlighted).text).toBe("SSH");
      expect(wrapper.vm.total_results_match).toBe(1);
      expect(wrapper.vm.total_results_control).toBe(1);
    });
  });
});
