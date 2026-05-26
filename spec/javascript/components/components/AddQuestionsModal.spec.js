import { describe, it, expect, afterEach, vi, beforeEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import AddQuestionsModal from "@/components/components/AddQuestionsModal.vue";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: {} })),
    post: vi.fn(() => Promise.resolve({ data: {} })),
    put: vi.fn(() => Promise.resolve({ data: {} })),
    patch: vi.fn(() => Promise.resolve({ data: {} })),
    delete: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } },
  },
}));

vi.mock("@/api/componentsApi", () => ({
  updateComponent: vi.fn(() => Promise.resolve({ data: {} })),
}));

describe("AddQuestionsModal", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return shallowMount(AddQuestionsModal, {
      localVue,
      propsData: {
        component: { id: 5, additional_questions: [] },
        ...props,
      },
      stubs: {
        BModal: { template: "<div><slot /></div>", methods: { hide: vi.fn(), show: vi.fn() } },
        BFormGroup: true,
        BFormInput: true,
        BFormSelect: true,
        BButton: true,
      },
    });
  };

  beforeEach(() => vi.resetAllMocks());
  afterEach(() => { if (wrapper) wrapper.destroy(); });

  it("updateQuestions calls updateComponent with component id and payload", async () => {
    const { updateComponent } = await import("@/api/componentsApi");
    updateComponent.mockResolvedValueOnce({ data: {} });

    wrapper = createWrapper();
    wrapper.vm.updateQuestions();

    expect(updateComponent).toHaveBeenCalledWith(5, {
      component: { additional_questions_attributes: [] },
    });
  });
});
