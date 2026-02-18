import { describe, it, expect, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import Projects from "@/components/projects/Projects.vue";

// Mock axios
vi.mock("axios", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: [] })),
    defaults: { headers: { common: {} } },
  },
}));

/**
 * Projects List Page Requirements
 *
 * REQUIREMENTS:
 *
 * 1. BREADCRUMB:
 *    - Shows "Projects" breadcrumb
 *
 * 2. COMMAND BAR:
 *    - Uses BaseCommandBar for consistency
 *    - LEFT: Split dropdown — main click opens New Project modal,
 *            dropdown item "From Backup" opens RestoreProjectModal
 *    - Only visible when user can create projects
 *
 * 3. NEW PROJECT MODAL:
 *    - Modal for creating projects (not a separate page)
 *    - Triggered by New Project button (split dropdown main click)
 *    - Only rendered when user can create projects
 *
 * 4. RESTORE PROJECT MODAL:
 *    - Modal for creating project from backup archive
 *    - Triggered by "From Backup" dropdown item
 *    - Only rendered when user can create projects
 *
 * 5. PROJECTS TABLE:
 *    - Renders ProjectsTable
 *    - Passes projects data
 */
describe("Projects", () => {
  let wrapper;

  const defaultProps = {
    projects: [
      { id: 1, name: "Project 1", visibility: "hidden", is_member: true, memberships_count: 5 },
      {
        id: 2,
        name: "Project 2",
        visibility: "discoverable",
        is_member: false,
        memberships_count: 3,
      },
    ],
    is_vulcan_admin: true,
    can_create_project: true,
  };

  const createWrapper = (props = {}) => {
    return shallowMount(Projects, {
      localVue,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        BBreadcrumb: true,
        BaseCommandBar: {
          template: '<div><slot name="left" /><slot name="right" /></div>',
        },
        ProjectsTable: true,
        NewProjectModal: true,
        RestoreProjectModal: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // ==========================================
  // BREADCRUMB
  // ==========================================
  describe("breadcrumb", () => {
    it("renders breadcrumb", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "BBreadcrumb" }).exists()).toBe(true);
    });

    it("breadcrumb shows Projects", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.breadcrumbs).toEqual([{ text: "Projects", active: true }]);
    });
  });

  // ==========================================
  // COMMAND BAR — Split Dropdown
  // ==========================================
  // Requirement: dropdown visible when admin OR create_permission_enabled is true
  // Backend: authorize_admin_or_create_permission_enabled
  // Frontend: can_create_project prop (set by HAML from admin || Settings.project.create_permission_enabled)
  describe("new project dropdown visibility", () => {
    it("shows dropdown when can_create_project is true", () => {
      wrapper = createWrapper({ is_vulcan_admin: false, can_create_project: true });
      const dropdown = wrapper.find('[data-testid="new-project-dropdown"]');
      expect(dropdown.exists()).toBe(true);
    });

    it("hides dropdown when can_create_project is false", () => {
      wrapper = createWrapper({ is_vulcan_admin: false, can_create_project: false });
      const dropdown = wrapper.find('[data-testid="new-project-dropdown"]');
      expect(dropdown.exists()).toBe(false);
    });

    it("shows From Backup dropdown item", () => {
      wrapper = createWrapper({ can_create_project: true });
      const item = wrapper.find('[data-testid="from-backup-item"]');
      expect(item.exists()).toBe(true);
    });
  });

  // ==========================================
  // NEW PROJECT MODAL
  // ==========================================
  describe("new project modal", () => {
    it("renders NewProjectModal when can_create_project is true", () => {
      wrapper = createWrapper({ can_create_project: true });
      expect(wrapper.findComponent({ name: "NewProjectModal" }).exists()).toBe(true);
    });

    it("does not render NewProjectModal when can_create_project is false", () => {
      wrapper = createWrapper({ is_vulcan_admin: false, can_create_project: false });
      expect(wrapper.findComponent({ name: "NewProjectModal" }).exists()).toBe(false);
    });

    it("openNewProjectModal shows the modal", () => {
      wrapper = createWrapper({ can_create_project: true });
      expect(wrapper.vm.showNewProjectModal).toBe(false);
      wrapper.vm.openNewProjectModal();
      expect(wrapper.vm.showNewProjectModal).toBe(true);
    });

    it("refreshProjects is called after project created", async () => {
      wrapper = createWrapper();
      const spy = vi.spyOn(wrapper.vm, "refreshProjects");

      wrapper.vm.onProjectCreated();

      expect(spy).toHaveBeenCalled();
    });
  });

  // ==========================================
  // RESTORE PROJECT MODAL
  // ==========================================
  describe("restore project modal", () => {
    it("renders RestoreProjectModal when can_create_project is true", () => {
      wrapper = createWrapper({ can_create_project: true });
      expect(wrapper.findComponent({ name: "RestoreProjectModal" }).exists()).toBe(true);
    });

    it("does not render RestoreProjectModal when can_create_project is false", () => {
      wrapper = createWrapper({ is_vulcan_admin: false, can_create_project: false });
      expect(wrapper.findComponent({ name: "RestoreProjectModal" }).exists()).toBe(false);
    });
  });

  // ==========================================
  // PROJECTS TABLE
  // ==========================================
  describe("projects table", () => {
    it("renders ProjectsTable", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "ProjectsTable" }).exists()).toBe(true);
    });

    it("passes projects to ProjectsTable", () => {
      wrapper = createWrapper();
      const table = wrapper.findComponent({ name: "ProjectsTable" });
      expect(table.props("projects")).toEqual(defaultProps.projects);
    });

    it("passes is_vulcan_admin to ProjectsTable", () => {
      wrapper = createWrapper({ is_vulcan_admin: true });
      const table = wrapper.findComponent({ name: "ProjectsTable" });
      expect(table.props("is_vulcan_admin")).toBe(true);
    });
  });
});
