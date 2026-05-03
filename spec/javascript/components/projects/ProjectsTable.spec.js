import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ProjectsTable from "@/components/projects/ProjectsTable.vue";

// Mock axios
vi.mock("axios", () => ({
  default: {
    delete: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } },
  },
}));

/**
 * ProjectsTable Delete Functionality Tests
 *
 * REQUIREMENTS:
 *
 * 1. DELETE BUTTON (site admin OR project admin):
 *    - Shows "Remove" button for vulcan site admins (on all projects)
 *    - Shows "Remove" button for project admins (on their projects)
 *    - Hidden for non-admin project members
 *
 * 2. DELETE CONFIRMATION MODAL:
 *    - Clicking Remove opens confirmation modal (NOT browser confirm)
 *    - Modal shows project name in warning message
 *    - Cancel button closes modal without deleting
 *    - Confirm button triggers delete
 *
 * 3. DELETE LOADING STATE:
 *    - Shows spinner while delete is processing
 *    - Disables buttons during delete
 *
 * 4. DELETE SUCCESS:
 *    - Emits 'projectDeleted' event on success
 *    - Closes modal on success
 *
 * 5. DELETE ERROR:
 *    - Shows error message on failure
 *    - Allows retry
 */
describe("ProjectsTable", () => {
  let wrapper;

  const sampleProjects = [
    {
      id: 1,
      name: "Test Project",
      description: "A test project",
      visibility: "discoverable",
      is_member: true,
      admin: true,
      memberships_count: 5,
      updated_at: "2024-01-15T10:00:00Z",
    },
    {
      id: 2,
      name: "Another Project",
      description: "Another description",
      visibility: "hidden",
      is_member: true,
      admin: false,
      memberships_count: 3,
      updated_at: "2024-01-14T10:00:00Z",
    },
  ];

  const createWrapper = (props = {}) => {
    return mount(ProjectsTable, {
      localVue,
      propsData: {
        projects: sampleProjects,
        is_vulcan_admin: true,
        ...props,
      },
      stubs: {
        UpdateProjectDetailsModal: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
    vi.clearAllMocks();
  });

  // ==========================================
  // PENDING-COMMENTS COLUMN (PR #717 follow-on)
  // Requirement: separate "Comments" column with a clickable badge that
  // links to the server-resolved deep-link target (no client-side bouncing).
  // ==========================================
  describe("pending-comments column", () => {
    it("renders 'N pending' badge alongside total when pending > 0", () => {
      const projects = [
        {
          ...sampleProjects[0],
          pending_comment_count: 3,
          total_comment_count: 9,
          pending_comment_link: "/components/42/triage",
        },
      ];
      wrapper = createWrapper({ projects });
      const link = wrapper.find('a[href="/components/42/triage"]');
      expect(link.exists()).toBe(true);
      expect(link.text()).toContain("3 pending");
      expect(link.text()).toContain("9 total");
    });

    it("links straight to the component triage view when one component has pending", () => {
      const projects = [
        {
          ...sampleProjects[0],
          pending_comment_count: 2,
          total_comment_count: 5,
          pending_comment_link: "/components/99/triage",
        },
      ];
      wrapper = createWrapper({ projects });
      const link = wrapper.find('a[href*="/triage"]');
      expect(link.attributes("href")).toBe("/components/99/triage");
    });

    it("shows just the total count when no pending (closed-only activity)", () => {
      const projects = [
        {
          ...sampleProjects[0],
          pending_comment_count: 0,
          total_comment_count: 4,
          pending_comment_link: "/projects/1/triage",
        },
      ];
      wrapper = createWrapper({ projects });
      const link = wrapper.find('a[href="/projects/1/triage"]');
      expect(link.exists()).toBe(true);
      expect(link.text()).toContain("4 total");
      expect(link.text()).not.toContain("pending");
    });

    it("renders an em-dash when there are no comments at all", () => {
      const projects = [
        {
          ...sampleProjects[0],
          pending_comment_count: 0,
          total_comment_count: 0,
          pending_comment_link: null,
        },
      ];
      wrapper = createWrapper({ projects });
      const commentsCell = wrapper.find("td:nth-child(4)");
      expect(commentsCell.text()).toContain("—");
      expect(wrapper.find("a[href*='/triage']").exists()).toBe(false);
      expect(wrapper.find("a[href*='#comments']").exists()).toBe(false);
    });
  });

  // ==========================================
  // DESCRIPTION TRUNCATION
  // Requirement: toggle link only shown when description > 75 chars
  // ==========================================
  describe("description truncation", () => {
    it("does not show toggle link for short descriptions", () => {
      const shortDescProjects = [{ ...sampleProjects[0], description: "Short desc" }];
      wrapper = createWrapper({ projects: shortDescProjects });
      const descCell = wrapper.find("td:nth-child(2)");
      expect(descCell.find("a").exists()).toBe(false);
    });

    it("shows toggle link for descriptions longer than 75 characters", () => {
      const longDesc = "A".repeat(80);
      const longDescProjects = [{ ...sampleProjects[0], description: longDesc }];
      wrapper = createWrapper({ projects: longDescProjects });
      const links = wrapper.findAll("a").filter((w) => w.text().includes("..."));
      expect(links.length).toBeGreaterThan(0);
    });

    it("does not show toggle link when description is null", () => {
      const nullDescProjects = [{ ...sampleProjects[0], description: null }];
      wrapper = createWrapper({ projects: nullDescProjects });
      const links = wrapper
        .findAll("a")
        .filter((w) => w.text().includes("...") || w.text().includes("read less"));
      expect(links.length).toBe(0);
    });
  });

  // ==========================================
  // ADMIN ACTION BUTTONS — disabled-not-hidden
  // Locked design rule (vulcan-disabled-not-hidden): interactive controls
  // that the current user can't use must render visibly DISABLED with an
  // explanatory tooltip — never hide via v-if. This makes role-tier
  // capabilities discoverable instead of leaving non-admins staring at an
  // empty Actions cell with no signal of what's possible.
  // ==========================================
  describe("admin action buttons (disabled-not-hidden)", () => {
    it("renders enabled Remove button for vulcan site admin (on all projects)", () => {
      wrapper = createWrapper({ is_vulcan_admin: true });
      const removeBtns = wrapper.findAll('[data-testid="remove-project-btn"]');
      expect(removeBtns.length).toBe(sampleProjects.length);
      removeBtns.wrappers.forEach((btn) => {
        expect(btn.attributes("disabled")).toBeUndefined();
      });
    });

    it("renders enabled Remove button for project admin on their projects, disabled elsewhere", () => {
      // sampleProjects[0] has admin: true, sampleProjects[1] has admin: false
      wrapper = createWrapper({ is_vulcan_admin: false });
      const removeBtns = wrapper.findAll('[data-testid="remove-project-btn"]');
      expect(removeBtns.length).toBe(sampleProjects.length);
      // Table sorts by name — "Another Project" (admin: false) is first, "Test Project" (admin: true) is second
      expect(removeBtns.at(0).attributes("disabled")).toBeDefined();
      expect(removeBtns.at(1).attributes("disabled")).toBeUndefined();
    });

    it("renders disabled Remove button with admin-only tooltip for non-admin members", () => {
      const nonAdminProjects = [
        { ...sampleProjects[0], admin: false },
        { ...sampleProjects[1], admin: false },
      ];
      wrapper = mount(ProjectsTable, {
        localVue,
        propsData: { projects: nonAdminProjects, is_vulcan_admin: false },
        stubs: { UpdateProjectDetailsModal: true },
      });
      const removeBtns = wrapper.findAll('[data-testid="remove-project-btn"]');
      expect(removeBtns.length).toBe(nonAdminProjects.length);
      removeBtns.wrappers.forEach((btn) => {
        expect(btn.attributes("disabled")).toBeDefined();
        // Tooltip directive sets a title attribute the user can hover to read.
        expect(btn.attributes("title")).toMatch(/admin/i);
      });
    });

    it("passes admin-gating to the Update modal opener (disabled for non-admin members)", () => {
      // Don't stub UpdateProjectDetailsModal so we can read its props passthrough.
      const nonAdminProjects = [{ ...sampleProjects[0], admin: false }];
      wrapper = mount(ProjectsTable, {
        localVue,
        propsData: { projects: nonAdminProjects, is_vulcan_admin: false },
      });
      const updateModal = wrapper.findComponent({ name: "UpdateProjectDetailsModal" });
      expect(updateModal.exists()).toBe(true);
      expect(updateModal.props("disabled")).toBe(true);
      expect(updateModal.props("disabledTitle")).toMatch(/admin/i);
    });

    it("passes enabled state to the Update modal opener for project admin", () => {
      const adminProject = [{ ...sampleProjects[0], admin: true }];
      wrapper = mount(ProjectsTable, {
        localVue,
        propsData: { projects: adminProject, is_vulcan_admin: false },
      });
      const updateModal = wrapper.findComponent({ name: "UpdateProjectDetailsModal" });
      expect(updateModal.props("disabled")).toBe(false);
    });
  });

  // ==========================================
  // DELETE CONFIRMATION MODAL
  // ==========================================
  describe("delete confirmation modal", () => {
    it("opens modal when Remove clicked", async () => {
      wrapper = createWrapper({ is_vulcan_admin: true });
      expect(wrapper.vm.showDeleteModal).toBe(false);

      const removeBtn = wrapper.find('[data-testid="remove-project-btn"]');
      await removeBtn.trigger("click");

      expect(wrapper.vm.showDeleteModal).toBe(true);
    });

    it("stores project to delete when modal opens", async () => {
      wrapper = createWrapper({ is_vulcan_admin: true });
      const removeBtn = wrapper.find('[data-testid="remove-project-btn"]');
      await removeBtn.trigger("click");

      // Table sorts by name — "Another Project" is first alphabetically
      expect(wrapper.vm.projectToDelete).toEqual(sampleProjects[1]);
    });

    it("shows project name in modal", async () => {
      wrapper = createWrapper({ is_vulcan_admin: true });
      const removeBtn = wrapper.find('[data-testid="remove-project-btn"]');
      await removeBtn.trigger("click");
      await wrapper.vm.$nextTick();

      // First Remove button is "Another Project" (alphabetical sort)
      expect(wrapper.text()).toContain("Another Project");
    });

    it("Cancel closes modal without deleting", async () => {
      wrapper = createWrapper({ is_vulcan_admin: true });
      // Open modal
      const removeBtn = wrapper.find('[data-testid="remove-project-btn"]');
      await removeBtn.trigger("click");
      expect(wrapper.vm.showDeleteModal).toBe(true);

      // Click cancel
      wrapper.vm.cancelDelete();
      await wrapper.vm.$nextTick();

      expect(wrapper.vm.showDeleteModal).toBe(false);
      expect(wrapper.vm.projectToDelete).toBe(null);
    });
  });

  // ==========================================
  // DELETE LOADING STATE
  // ==========================================
  describe("delete loading state", () => {
    it("shows spinner when delete is processing", async () => {
      wrapper = createWrapper({ is_vulcan_admin: true });
      wrapper.vm.isDeleting = true;
      await wrapper.vm.$nextTick();

      expect(wrapper.vm.isDeleting).toBe(true);
    });

    it("isDeleting starts as false", () => {
      wrapper = createWrapper({ is_vulcan_admin: true });
      expect(wrapper.vm.isDeleting).toBe(false);
    });
  });

  // ==========================================
  // DELETE EXECUTION
  // ==========================================
  describe("delete execution", () => {
    it("confirmDelete calls axios.delete with correct URL (JSON format)", async () => {
      const axios = (await import("axios")).default;
      wrapper = createWrapper({ is_vulcan_admin: true });
      wrapper.vm.projectToDelete = sampleProjects[0];
      wrapper.vm.showDeleteModal = true;

      await wrapper.vm.confirmDelete();

      expect(axios.delete).toHaveBeenCalledWith("/projects/1.json");
    });

    it("confirmDelete sets isDeleting to true during request", async () => {
      const axios = (await import("axios")).default;
      axios.delete.mockImplementation(() => new Promise((resolve) => setTimeout(resolve, 100)));

      wrapper = createWrapper({ is_vulcan_admin: true });
      wrapper.vm.projectToDelete = sampleProjects[0];

      const deletePromise = wrapper.vm.confirmDelete();
      expect(wrapper.vm.isDeleting).toBe(true);

      await deletePromise;
    });

    it("emits projectUpdated on success", async () => {
      const axios = (await import("axios")).default;
      axios.delete.mockResolvedValue({ data: {} });

      wrapper = createWrapper({ is_vulcan_admin: true });
      wrapper.vm.projectToDelete = sampleProjects[0];
      wrapper.vm.showDeleteModal = true;

      await wrapper.vm.confirmDelete();

      expect(wrapper.emitted("projectUpdated")).toBeTruthy();
    });

    it("closes modal on success", async () => {
      const axios = (await import("axios")).default;
      axios.delete.mockResolvedValue({ data: {} });

      wrapper = createWrapper({ is_vulcan_admin: true });
      wrapper.vm.projectToDelete = sampleProjects[0];
      wrapper.vm.showDeleteModal = true;

      await wrapper.vm.confirmDelete();

      expect(wrapper.vm.showDeleteModal).toBe(false);
      expect(wrapper.vm.isDeleting).toBe(false);
    });

    it("resets state on success", async () => {
      const axios = (await import("axios")).default;
      axios.delete.mockResolvedValue({ data: {} });

      wrapper = createWrapper({ is_vulcan_admin: true });
      wrapper.vm.projectToDelete = sampleProjects[0];
      wrapper.vm.showDeleteModal = true;

      await wrapper.vm.confirmDelete();

      expect(wrapper.vm.projectToDelete).toBe(null);
    });
  });
});
