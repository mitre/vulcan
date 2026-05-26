import { describe, it, expect, afterEach, vi, beforeEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import AddComponentModal from "@/components/components/AddComponentModal.vue";

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
  createComponentInProject: vi.fn(() => Promise.resolve({ data: {} })),
}));

describe("AddComponentModal", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return shallowMount(AddComponentModal, {
      localVue,
      propsData: {
        project_id: 1,
        available_components: [{ id: 10, name: "Test Component" }],
        ...props,
      },
      stubs: {
        BModal: { template: "<div><slot /></div>", methods: { hide: vi.fn() } },
        VueMultiselect: true,
        ComponentCard: true,
      },
    });
  };

  beforeEach(() => vi.resetAllMocks());
  afterEach(() => { if (wrapper) wrapper.destroy(); });

  it("addComponent calls createComponentInProject with project id and payload", async () => {
    const { createComponentInProject } = await import("@/api/componentsApi");
    createComponentInProject.mockResolvedValueOnce({ data: {} });

    wrapper = createWrapper();
    wrapper.vm.selectedComponent = { id: 10, name: "Test Component" };
    wrapper.vm.addComponent();

    expect(createComponentInProject).toHaveBeenCalledWith(1, {
      component: { component_id: 10 },
    });
  });
});
