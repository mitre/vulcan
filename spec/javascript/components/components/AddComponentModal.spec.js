import { describe, it, expect, afterEach, vi, beforeEach } from "vitest";
import { shallowMount, mount } from "@vue/test-utils";
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

// Spy-wrap (real implementations preserved) so tests can pin that the hidden
// form token and component display names flow through the composables.
vi.mock("@/composables/useAuthToken", { spy: true });
vi.mock("@/composables/useDisplayedComponent", { spy: true });
import { useAuthToken } from "@/composables/useAuthToken";
import { useDisplayedComponent } from "@/composables/useDisplayedComponent";

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
  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

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

  // ==========================================
  // HIDDEN AUTHENTICITY TOKEN (useAuthToken) +
  // DISPLAY NAMES (useDisplayedComponent)
  // REQUIREMENT: the in-modal form carries the CSRF token as a hidden
  // input, sourced from the useAuthToken composable (single source of
  // truth). Component search options get "Name (Version X, Release Y)"
  // display names via the useDisplayedComponent composable.
  // ==========================================
  describe("composable contracts", () => {
    // b-modal renders content lazily/in a portal — stub it to render
    // its default slot inline so the form is findable in jsdom.
    const ModalStub = { template: "<div><slot /></div>" };

    const createMountedWrapper = (props = {}) => {
      return mount(AddComponentModal, {
        localVue,
        propsData: {
          project_id: 1,
          available_components: [{ id: 10, name: "Test Component", version: "2", release: "3" }],
          ...props,
        },
        stubs: {
          "b-modal": ModalStub,
          VueMultiselect: true,
          ComponentCard: true,
        },
      });
    };

    it("renders the hidden authenticity_token input with the CSRF meta value", () => {
      wrapper = createMountedWrapper();
      const input = wrapper.find('input[name="authenticity_token"]');
      expect(input.exists()).toBe(true);
      // setup.js sets the csrf-token meta to "test-csrf-token"
      expect(input.element.value).toBe("test-csrf-token");
    });

    it("sources the token from the useAuthToken composable", () => {
      useAuthToken.mockReturnValueOnce({ authenticityToken: "composable-sentinel-token" });
      wrapper = createMountedWrapper();
      expect(useAuthToken).toHaveBeenCalledTimes(1);
      const input = wrapper.find('input[name="authenticity_token"]');
      expect(input.element.value).toBe("composable-sentinel-token");
    });

    it("builds search option display names via the useDisplayedComponent composable", () => {
      wrapper = createMountedWrapper();
      expect(useDisplayedComponent).toHaveBeenCalledTimes(1);
      // The template maps available_components through addDisplayNameToComponents
      expect(wrapper.vm.addDisplayNameToComponents([{ name: "X", version: "2" }])).toEqual([
        { name: "X", version: "2", displayed: "X (Version 2)" },
      ]);
    });
  });
});
