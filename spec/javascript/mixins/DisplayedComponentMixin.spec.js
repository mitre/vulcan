import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import DisplayedComponentMixin from "@/mixins/DisplayedComponentMixin.vue";

/**
 * DisplayedComponentMixin Tests
 *
 * REQUIREMENTS:
 *
 * addDisplayNameToComponents(components):
 * - Adds a `displayed` property to each component in the array
 * - Format when both version and release: "Name (Version X, Release Y)"
 * - Format when only version: "Name (Version X)"
 * - Format when only release: "Name (Release Y)"
 * - Format when neither: "Name"
 * - Mutates and returns the input array
 */

const HostComponent = {
  mixins: [DisplayedComponentMixin],
  template: "<div></div>",
};

function createWrapper() {
  return mount(HostComponent, { localVue });
}

describe("DisplayedComponentMixin", () => {
  describe("addDisplayNameToComponents", () => {
    // ==========================================
    // BOTH VERSION AND RELEASE
    // ==========================================
    it('formats "Name (Version X, Release Y)" when both present', () => {
      const wrapper = createWrapper();
      const components = [{ name: "RHEL 9 STIG", version: "1", release: "2" }];

      const result = wrapper.vm.addDisplayNameToComponents(components);

      expect(result[0].displayed).toBe("RHEL 9 STIG (Version 1, Release 2)");
    });

    // ==========================================
    // ONLY VERSION
    // ==========================================
    it('formats "Name (Version X)" when only version present — no comma artifact', () => {
      const wrapper = createWrapper();
      const components = [{ name: "RHEL 9 STIG", version: "3", release: null }];

      const result = wrapper.vm.addDisplayNameToComponents(components);

      expect(result[0].displayed).toBe("RHEL 9 STIG (Version 3)");
    });

    // ==========================================
    // ONLY RELEASE
    // ==========================================
    it('formats "Name (Release Y)" when only release present — no comma artifact', () => {
      const wrapper = createWrapper();
      const components = [{ name: "RHEL 9 STIG", version: null, release: "5" }];

      const result = wrapper.vm.addDisplayNameToComponents(components);

      expect(result[0].displayed).toBe("RHEL 9 STIG (Release 5)");
    });

    // ==========================================
    // NEITHER VERSION NOR RELEASE
    // ==========================================
    it("shows the bare name when neither version nor release — no trailing space", () => {
      const wrapper = createWrapper();
      const components = [{ name: "Custom Component", version: null, release: null }];

      const result = wrapper.vm.addDisplayNameToComponents(components);

      expect(result[0].displayed).toBe("Custom Component");
    });

    // ==========================================
    // MUTATION AND RETURN
    // ==========================================
    it("mutates the original component objects and returns a new array", () => {
      const wrapper = createWrapper();
      const components = [{ name: "Test", version: "1", release: "1" }];

      const result = wrapper.vm.addDisplayNameToComponents(components);

      // map() returns a new array, but mutates the original objects
      expect(result).toHaveLength(1);
      expect(result[0].displayed).toBeDefined();
      // The original component object was mutated (same object reference)
      expect(components[0].displayed).toBeDefined();
      expect(components[0].displayed).toBe(result[0].displayed);
    });

    it("processes multiple components", () => {
      const wrapper = createWrapper();
      const components = [
        { name: "Component A", version: "1", release: "2" },
        { name: "Component B", version: "3", release: "4" },
        { name: "Component C", version: null, release: null },
      ];

      const result = wrapper.vm.addDisplayNameToComponents(components);

      expect(result).toHaveLength(3);
      expect(result[0].displayed).toBe("Component A (Version 1, Release 2)");
      expect(result[1].displayed).toBe("Component B (Version 3, Release 4)");
      expect(result[2].displayed).toBe("Component C");
    });

    it("handles empty array", () => {
      const wrapper = createWrapper();
      const components = [];

      const result = wrapper.vm.addDisplayNameToComponents(components);

      expect(result).toEqual([]);
    });

    it("preserves other properties on each component", () => {
      const wrapper = createWrapper();
      const components = [{ id: 42, name: "Test", version: "1", release: "1", extra: "data" }];

      wrapper.vm.addDisplayNameToComponents(components);

      expect(components[0].id).toBe(42);
      expect(components[0].extra).toBe("data");
      expect(components[0].displayed).toBeDefined();
    });

    // ==========================================
    // FALSY VERSION/RELEASE VALUES
    // ==========================================
    it("treats undefined version same as null", () => {
      const wrapper = createWrapper();
      const components = [
        { name: "Test", release: "2" },
        // version is undefined (not set)
      ];

      const result = wrapper.vm.addDisplayNameToComponents(components);

      expect(result[0].displayed).toBe("Test (Release 2)");
    });

    it("treats empty string version as falsy", () => {
      const wrapper = createWrapper();
      const components = [{ name: "Test", version: "", release: "2" }];

      const result = wrapper.vm.addDisplayNameToComponents(components);

      expect(result[0].displayed).toBe("Test (Release 2)");
    });
  });
});
