import { describe, it, expect, afterEach, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import LockControlsModal from "@/components/components/LockControlsModal.vue";

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
  lockComponent: vi.fn(() => Promise.resolve({ data: {} })),
  lockSections: vi.fn(() => Promise.resolve({ data: {} })),
}));

// Spy-wrap (real implementation preserved) so tests can pin that the hidden
// form token flows through the useAuthToken composable — one source of truth.
vi.mock("@/composables/useAuthToken", { spy: true });
import { useAuthToken } from "@/composables/useAuthToken";

/**
 * LockControlsModal - Component-level lock controls
 *
 * REQUIREMENTS:
 * C6: Export lock labels - two lock modes with clear labels
 * 1. "Lock all rule fields" - locks all fields on all unlocked rules (existing behavior)
 * 2. "Lock selection of fields" - lock specific sections across all rules
 *
 * These labels appear as radio button labels in the modal form,
 * helping users choose the appropriate locking strategy for their component.
 */
describe("LockControlsModal", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return mount(LockControlsModal, {
      localVue,
      propsData: {
        component_id: 1,
        ...props,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // ==========================================
  // COMPONENT SETUP
  // ==========================================
  describe("component setup", () => {
    it("renders without error", () => {
      wrapper = createWrapper();
      expect(wrapper.exists()).toBe(true);
    });

    it("initializes with correct default values", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.lockMode).toBe("full");
      expect(wrapper.vm.comment).toBe("");
      expect(wrapper.vm.selectedSections).toEqual([]);
      expect(wrapper.vm.loading).toBe(false);
    });

    it("has component_id prop", () => {
      wrapper = createWrapper({ component_id: 42 });
      expect(wrapper.props("component_id")).toBe(42);
    });
  });

  // ==========================================
  // LOCK MODE DATA
  // ==========================================
  describe("lock mode functionality (C6)", () => {
    // C6: Export lock labels - radio button labels must be exact
    // REQUIREMENT: Component supports two distinct lock modes with clear distinction

    it("has two lock mode options: 'full' and 'sections'", () => {
      wrapper = createWrapper();
      // The component initializes with 'full' lock mode
      expect(wrapper.vm.lockMode).toBe("full");

      // Can switch to 'sections' mode
      wrapper.vm.lockMode = "sections";
      expect(wrapper.vm.lockMode).toBe("sections");
    });

    it("resets lock mode to 'full' when modal opens", () => {
      wrapper = createWrapper();
      // Set to sections mode
      wrapper.vm.lockMode = "sections";

      // Call showModal to reset state
      wrapper.vm.showModal();

      // Should be back to 'full'
      expect(wrapper.vm.lockMode).toBe("full");
    });

    it("section selection is cleared when modal opens", () => {
      wrapper = createWrapper();
      wrapper.vm.selectedSections = ["Rule Title", "Rationale"];

      wrapper.vm.showModal();

      expect(wrapper.vm.selectedSections.length).toBe(0);
    });

    it("comment is cleared when modal opens", () => {
      wrapper = createWrapper();
      wrapper.vm.comment = "test comment";

      wrapper.vm.showModal();

      expect(wrapper.vm.comment).toBe("");
    });

    it("has sectionOptions available from ruleFieldConfig", () => {
      wrapper = createWrapper();
      expect(Array.isArray(wrapper.vm.sectionOptions)).toBe(true);
      expect(wrapper.vm.sectionOptions.length).toBeGreaterThan(0);
    });
  });

  // ==========================================
  // HIDDEN AUTHENTICITY TOKEN (useAuthToken)
  // REQUIREMENT: the in-modal form carries the CSRF token as a hidden
  // input so a non-ajax submit would authenticate. The value must come
  // from the useAuthToken composable (single source of truth), not a
  // per-component computed.
  // ==========================================
  describe("hidden authenticity_token field", () => {
    // b-modal renders content lazily/in a portal — stub it to render
    // its default slot inline so the form is findable in jsdom.
    const ModalStub = { template: "<div><slot /></div>" };

    const createMountedWrapper = (props = {}) => {
      return mount(LockControlsModal, {
        localVue,
        propsData: { component_id: 1, ...props },
        stubs: { "b-modal": ModalStub },
      });
    };

    beforeEach(() => vi.clearAllMocks());

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
  });

  describe("API calls use domain modules", () => {
    beforeEach(() => vi.resetAllMocks());

    it("lockControls calls lockComponent with component_id and payload", async () => {
      const { lockComponent } = await import("@/api/componentsApi");
      lockComponent.mockResolvedValueOnce({ data: {} });

      wrapper = createWrapper();
      wrapper.vm.comment = "Locking all";
      wrapper.vm.lockControls();

      expect(lockComponent).toHaveBeenCalledWith(1, {
        action: "lock_control", comment: "Locking all",
      });
    });

    it("lockSections calls lockSections with component_id and payload", async () => {
      const { lockSections } = await import("@/api/componentsApi");
      lockSections.mockResolvedValueOnce({ data: {} });

      wrapper = createWrapper();
      wrapper.vm.comment = "Locking sections";
      wrapper.vm.selectedSections = ["check_content", "fixtext"];
      wrapper.vm.lockSections();

      expect(lockSections).toHaveBeenCalledWith(1, {
        sections: ["check_content", "fixtext"],
        locked: true,
        comment: "Locking sections",
      });
    });
  });
});
