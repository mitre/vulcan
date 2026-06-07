import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { defineComponent } from "vue";
import { usePermissions } from "../../../app/javascript/composables/usePermissions";

function mountWithPermissions(effectivePermissions) {
  const TestComponent = defineComponent({
    setup() {
      return usePermissions();
    },
    template: "<div />",
  });

  return mount(TestComponent, {
    provide: { effectivePermissions },
  });
}

describe("usePermissions", () => {
  describe("effectivePermissions", () => {
    it("returns the injected value", () => {
      const wrapper = mountWithPermissions("admin");
      expect(wrapper.vm.effectivePermissions).toBe("admin");
    });

    it("defaults to null when nothing is provided", () => {
      const TestComponent = defineComponent({
        setup() {
          return usePermissions();
        },
        template: "<div />",
      });
      const wrapper = mount(TestComponent);
      expect(wrapper.vm.effectivePermissions).toBeNull();
    });
  });

  describe("canView", () => {
    it("returns true for viewer", () => {
      expect(mountWithPermissions("viewer").vm.canView).toBe(true);
    });
    it("returns true for admin", () => {
      expect(mountWithPermissions("admin").vm.canView).toBe(true);
    });
    it("returns false for null (non-member)", () => {
      expect(mountWithPermissions(null).vm.canView).toBe(false);
    });
  });

  describe("canEdit", () => {
    it("returns true for author", () => {
      expect(mountWithPermissions("author").vm.canEdit).toBe(true);
    });
    it("returns true for reviewer", () => {
      expect(mountWithPermissions("reviewer").vm.canEdit).toBe(true);
    });
    it("returns true for admin", () => {
      expect(mountWithPermissions("admin").vm.canEdit).toBe(true);
    });
    it("returns false for viewer", () => {
      expect(mountWithPermissions("viewer").vm.canEdit).toBe(false);
    });
    it("returns false for null", () => {
      expect(mountWithPermissions(null).vm.canEdit).toBe(false);
    });
  });

  describe("canReview", () => {
    it("returns true for reviewer", () => {
      expect(mountWithPermissions("reviewer").vm.canReview).toBe(true);
    });
    it("returns true for admin", () => {
      expect(mountWithPermissions("admin").vm.canReview).toBe(true);
    });
    it("returns false for author", () => {
      expect(mountWithPermissions("author").vm.canReview).toBe(false);
    });
  });

  describe("canAdmin", () => {
    it("returns true for admin", () => {
      expect(mountWithPermissions("admin").vm.canAdmin).toBe(true);
    });
    it("returns false for reviewer", () => {
      expect(mountWithPermissions("reviewer").vm.canAdmin).toBe(false);
    });
    it("returns false for author", () => {
      expect(mountWithPermissions("author").vm.canAdmin).toBe(false);
    });
    it("returns false for viewer", () => {
      expect(mountWithPermissions("viewer").vm.canAdmin).toBe(false);
    });
    it("returns false for null", () => {
      expect(mountWithPermissions(null).vm.canAdmin).toBe(false);
    });
  });

  describe("isMember", () => {
    it("returns true for any role", () => {
      expect(mountWithPermissions("viewer").vm.isMember).toBe(true);
      expect(mountWithPermissions("admin").vm.isMember).toBe(true);
    });
    it("returns false for null", () => {
      expect(mountWithPermissions(null).vm.isMember).toBe(false);
    });
  });
});
