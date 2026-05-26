import { describe, it, expect, afterEach, vi, beforeEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import UpdateMetadataModal from "@/components/components/UpdateMetadataModal.vue";

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

describe("UpdateMetadataModal", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return shallowMount(UpdateMetadataModal, {
      localVue,
      propsData: {
        component: { id: 7, metadata: { env: "production" } },
        ...props,
      },
      stubs: {
        BModal: { template: "<div><slot /></div>", methods: { hide: vi.fn(), show: vi.fn() } },
        BFormGroup: true,
        BFormInput: true,
        BButton: true,
      },
    });
  };

  beforeEach(() => vi.resetAllMocks());
  afterEach(() => { if (wrapper) wrapper.destroy(); });

  it("updateMetadata calls updateComponent with component id and payload", async () => {
    const { updateComponent } = await import("@/api/componentsApi");
    updateComponent.mockResolvedValueOnce({ data: {} });

    wrapper = createWrapper();
    wrapper.vm.updateMetadata();

    expect(updateComponent).toHaveBeenCalledWith(7, expect.objectContaining({
      component_metadata_attributes: expect.objectContaining({
        data: { env: "production" },
      }),
    }));
  });
});
