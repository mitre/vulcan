import { describe, it, expect } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ProjectTriagePage from "@/components/project/ProjectTriagePage.vue";

describe("ProjectTriagePage", () => {
  const defaultProps = {
    project: {
      id: 3,
      name: "vSphere 7.0",
      effective_permissions: "admin",
    },
    currentUserId: 1,
  };

  const createWrapper = (props = {}) => {
    return shallowMount(ProjectTriagePage, {
      localVue,
      propsData: { ...defaultProps, ...props },
      stubs: {
        ComponentComments: true,
        BBreadcrumb: true,
        BButton: true,
        BIcon: true,
      },
    });
  };

  describe("permissions via provide", () => {
    it("reads effectivePermissions from project data", () => {
      const wrapper = createWrapper();
      expect(wrapper.vm.effectivePermissions).toBe("admin");
    });

    it("derives viewer permissions from project data", () => {
      const wrapper = createWrapper({
        project: { ...defaultProps.project, effective_permissions: "viewer" },
      });
      expect(wrapper.vm.effectivePermissions).toBe("viewer");
    });

    it("defaults to null when project has no permissions", () => {
      const projectWithout = { ...defaultProps.project };
      delete projectWithout.effective_permissions;
      const wrapper = createWrapper({ project: projectWithout });
      expect(wrapper.vm.effectivePermissions).toBeNull();
    });
  });

  describe("rendering", () => {
    it("renders the component", () => {
      const wrapper = createWrapper();
      expect(wrapper.exists()).toBe(true);
    });

    it("renders breadcrumbs with project name", () => {
      const wrapper = createWrapper();
      expect(wrapper.vm.breadcrumbs[1].text).toBe("vSphere 7.0");
    });

    it("provides effectivePermissions to the component tree (inject contract)", () => {
      const wrapper = createWrapper();
      // The page root is the provider — ComponentComments injects via
      // usePermissions, so no prop pass-through exists anymore.
      const comments = wrapper.findComponent({ name: "ComponentComments" });
      expect(comments.exists()).toBe(true);
      expect("effectivePermissions" in (comments.props() || {})).toBe(false);
      expect(wrapper.vm.effectivePermissions).toBe("admin");
    });
  });
});
