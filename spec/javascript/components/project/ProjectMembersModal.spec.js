import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ProjectMembersModal from "@/components/project/ProjectMembersModal.vue";

/**
 * ProjectMembersModal — members management modal on the Project page.
 *
 * REQUIREMENTS:
 * 1. Membership editing (add/remove/change role) is admin-only — the
 *    MembershipsTable receives editable=true ONLY for project admins.
 * 2. Permissions arrive via the page-root provide (usePermissions inject),
 *    matching production: Project.vue provides "effectivePermissions".
 * 3. Modal title shows the member count, plus pending access requests.
 */
describe("ProjectMembersModal", () => {
  let wrapper;

  const defaultProps = {
    project: {
      id: 1,
      memberships: [],
      memberships_count: 4,
      access_requests: [],
    },
    availableRoles: ["admin", "author", "viewer"],
  };

  const createWrapper = (props = {}, permissions = "admin") => {
    return shallowMount(ProjectMembersModal, {
      localVue,
      provide: { effectivePermissions: permissions },
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        BModal: true,
        MembershipsTable: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("permissions via inject (usePermissions)", () => {
    it("canAdmin is true when admin permissions are provided", () => {
      wrapper = createWrapper({}, "admin");
      expect(wrapper.vm.canAdmin).toBe(true);
    });

    it("canAdmin is false for author permissions", () => {
      wrapper = createWrapper({}, "author");
      expect(wrapper.vm.canAdmin).toBe(false);
    });

    it("canAdmin is false for viewer permissions", () => {
      wrapper = createWrapper({}, "viewer");
      expect(wrapper.vm.canAdmin).toBe(false);
    });
  });

  describe("modal title", () => {
    it("shows the member count", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.modalTitle).toBe("Project Members (4)");
    });

    it("appends pending access request count when present", () => {
      wrapper = createWrapper({
        project: {
          ...defaultProps.project,
          access_requests: [{ id: 1 }, { id: 2 }],
        },
      });
      expect(wrapper.vm.modalTitle).toBe("Project Members (4) (2 pending)");
    });
  });
});
