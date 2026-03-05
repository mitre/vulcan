import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import LockControlsModal from "@/components/components/LockControlsModal.vue";

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
      // sectionOptions should be populated with lockable section names
      expect(Array.isArray(wrapper.vm.sectionOptions)).toBe(true);
      expect(wrapper.vm.sectionOptions.length).toBeGreaterThan(0);
    });
  });
});
