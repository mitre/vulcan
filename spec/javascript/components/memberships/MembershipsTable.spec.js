import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import MembershipsTable from "@/components/memberships/MembershipsTable.vue";

vi.mock("axios", () => ({
  default: {
    put: vi.fn(() => Promise.resolve({ data: { toast: "Updated" } })),
    delete: vi.fn(() => Promise.resolve({ data: { toast: "Removed" } })),
    defaults: { headers: { common: {} } },
  },
}));

/**
 * MembershipsTable Component Requirements:
 *
 * 1. HEADER:
 *    - Shows header_text (default: "Members")
 *    - Shows memberships_count in a badge
 *
 * 2. SEARCH:
 *    - Search input filters members by name (case-insensitive)
 *    - Search input filters members by email (case-insensitive)
 *
 * 3. NEW MEMBER BUTTON:
 *    - Visible only when editable=true AND available_members AND available_roles provided
 *    - Hidden when not editable
 *
 * 4. ACCESS REQUESTS:
 *    - Section visible only when editable=true AND access_requests.length > 0
 *    - Shows pending access request count
 *    - Accept/Reject buttons for each request
 *
 * 5. MEMBER TABLE:
 *    - Shows name and email for each member
 *    - Remove button visible only when editable=true
 *    - Role column is editable (select) when editable=true
 *    - Role column is read-only text when editable=false
 *
 * 6. PAGINATION:
 *    - Paginates members table (10 per page)
 */
describe("MembershipsTable", () => {
  let wrapper;

  const sampleMembers = [
    { id: 1, name: "Alice Admin", email: "alice@example.com", role: "admin" },
    { id: 2, name: "Bob Author", email: "bob@example.com", role: "author" },
    { id: 3, name: "Carol Viewer", email: "carol@example.com", role: "viewer" },
  ];

  const availableRoles = ["viewer", "author", "reviewer", "admin"];

  const availableMembers = [
    { id: 10, name: "Dan Pending", email: "dan@example.com" },
    { id: 11, name: "Eve New", email: "eve@example.com" },
  ];

  const accessRequests = [
    { id: 100, user_id: 10, user: { id: 10, name: "Pending User", email: "pending@example.com" } },
  ];

  const createWrapper = (props = {}) => {
    return mount(MembershipsTable, {
      localVue,
      propsData: {
        memberships: sampleMembers,
        membership_type: "Project",
        membership_id: 1,
        memberships_count: sampleMembers.length,
        ...props,
      },
      stubs: {
        NewMembership: {
          template: '<div class="new-membership-stub" />',
          props: [
            "membership_type",
            "membership_id",
            "available_members",
            "available_roles",
            "selected_member",
            "access_request_id",
          ],
        },
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
    vi.restoreAllMocks();
  });

  // ==========================================
  // HEADER
  // ==========================================
  describe("header", () => {
    it("shows default header text 'Members'", () => {
      wrapper = createWrapper();
      const header = wrapper.find("h2");
      expect(header.text()).toContain("Members");
    });

    it("shows custom header text", () => {
      wrapper = createWrapper({ header_text: "Project Members" });
      // Find the h2 that contains the member count (not access requests h2)
      const headers = wrapper.findAll("h2");
      const memberHeader = headers.filter((h) => h.text().includes("Project Members"));
      expect(memberHeader.length).toBeGreaterThanOrEqual(1);
    });

    it("shows member count in badge", () => {
      wrapper = createWrapper({ memberships_count: 42 });
      const badge = wrapper.find(".badge");
      expect(badge.text()).toContain("42");
    });
  });

  // ==========================================
  // SEARCH
  // ==========================================
  describe("search", () => {
    it("renders search input", () => {
      wrapper = createWrapper();
      const input = wrapper.find("#userSearch");
      expect(input.exists()).toBe(true);
    });

    it("filters members by name (case-insensitive)", async () => {
      wrapper = createWrapper();
      await wrapper.setData({ search: "alice" });

      expect(wrapper.vm.searchedProjectMembers).toHaveLength(1);
      expect(wrapper.vm.searchedProjectMembers[0].name).toBe("Alice Admin");
    });

    it("filters members by email (case-insensitive)", async () => {
      wrapper = createWrapper();
      await wrapper.setData({ search: "BOB@" });

      expect(wrapper.vm.searchedProjectMembers).toHaveLength(1);
      expect(wrapper.vm.searchedProjectMembers[0].email).toBe("bob@example.com");
    });

    it("shows all members when search is empty", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.searchedProjectMembers).toHaveLength(3);
    });

    it("returns empty array when no members match search", async () => {
      wrapper = createWrapper();
      await wrapper.setData({ search: "nonexistent" });

      expect(wrapper.vm.searchedProjectMembers).toHaveLength(0);
    });

    it("rows computed returns filtered member count", async () => {
      wrapper = createWrapper();
      expect(wrapper.vm.rows).toBe(3);

      await wrapper.setData({ search: "alice" });
      expect(wrapper.vm.rows).toBe(1);
    });
  });

  // ==========================================
  // NEW MEMBER BUTTON
  // ==========================================
  describe("new member button", () => {
    it("shows New Member button when editable with available_members and available_roles", () => {
      wrapper = createWrapper({
        editable: true,
        available_members: availableMembers,
        available_roles: availableRoles,
      });
      const button = wrapper.find("button.float-right");
      expect(button.exists()).toBe(true);
      expect(button.text()).toContain("New Member");
    });

    it("hides New Member button when not editable", () => {
      wrapper = createWrapper({
        editable: false,
        available_members: availableMembers,
        available_roles: availableRoles,
      });
      // No button with "New Member" text should exist
      const buttons = wrapper.findAll("button");
      const newMemberBtns = buttons.filter((b) => b.text().includes("New Member"));
      expect(newMemberBtns.length).toBe(0);
    });

    it("hides New Member button when available_roles not provided", () => {
      wrapper = createWrapper({
        editable: true,
        available_members: availableMembers,
      });
      const buttons = wrapper.findAll("button");
      const newMemberBtns = buttons.filter((b) => b.text().includes("New Member"));
      expect(newMemberBtns.length).toBe(0);
    });
  });

  // ==========================================
  // ACCESS REQUESTS
  // ==========================================
  describe("access requests", () => {
    it("shows access requests section when editable and requests exist", () => {
      wrapper = createWrapper({
        editable: true,
        access_requests: accessRequests,
        available_members: availableMembers,
      });
      expect(wrapper.text()).toContain("Pending Access Requests");
    });

    it("shows access request count badge", () => {
      wrapper = createWrapper({
        editable: true,
        access_requests: accessRequests,
        available_members: availableMembers,
      });
      // Find the h2 containing "Pending Access Requests"
      const headers = wrapper.findAll("h2");
      const arHeader = headers.filter((h) => h.text().includes("Pending Access Requests"));
      expect(arHeader.at(0).text()).toContain("1");
    });

    it("hides access requests section when not editable", () => {
      wrapper = createWrapper({
        editable: false,
        access_requests: accessRequests,
      });
      expect(wrapper.text()).not.toContain("Pending Access Requests");
    });

    it("hides access requests section when no requests", () => {
      wrapper = createWrapper({
        editable: true,
        access_requests: [],
      });
      expect(wrapper.text()).not.toContain("Pending Access Requests");
    });

    it("pendingProjectMembers derives user info from access_requests", () => {
      wrapper = createWrapper({
        editable: true,
        access_requests: accessRequests,
      });
      expect(wrapper.vm.pendingProjectMembers).toHaveLength(1);
      expect(wrapper.vm.pendingProjectMembers[0].name).toBe("Pending User");
      expect(wrapper.vm.pendingProjectMembers[0].email).toBe("pending@example.com");
    });
  });

  // ==========================================
  // MEMBER TABLE
  // ==========================================
  describe("member table", () => {
    it("renders members table", () => {
      wrapper = createWrapper();
      expect(wrapper.find("#project-members-table").exists()).toBe(true);
    });

    it("shows name and email for each member in the table", () => {
      wrapper = createWrapper();
      const text = wrapper.text();
      expect(text).toContain("Alice Admin");
      expect(text).toContain("alice@example.com");
      expect(text).toContain("Bob Author");
      expect(text).toContain("bob@example.com");
    });

    it("shows remove button when editable", () => {
      wrapper = createWrapper({
        editable: true,
        available_roles: availableRoles,
      });
      const removeButtons = wrapper.findAll(".projectMemberDeleteButton");
      expect(removeButtons.length).toBeGreaterThan(0);
    });

    it("hides remove button when not editable", () => {
      wrapper = createWrapper({ editable: false });
      const removeButtons = wrapper.findAll(".projectMemberDeleteButton");
      expect(removeButtons.length).toBe(0);
    });
  });

  // ==========================================
  // MODAL RESET
  // ==========================================
  describe("modal reset", () => {
    it("resetModal clears selectedMember and access_request_id", () => {
      wrapper = createWrapper({
        editable: true,
        available_members: availableMembers,
        available_roles: availableRoles,
        access_requests: accessRequests,
      });
      // Set some state
      wrapper.vm.selectedMember = { id: 10, name: "Dan" };
      wrapper.vm.access_request_id = 100;

      wrapper.vm.resetModal();

      expect(wrapper.vm.selectedMember).toBeNull();
      expect(wrapper.vm.access_request_id).toBeNull();
    });

    it("setSelectedMember sets member and finds access request id", () => {
      wrapper = createWrapper({
        editable: true,
        available_members: availableMembers,
        available_roles: availableRoles,
        access_requests: accessRequests,
      });

      wrapper.vm.setSelectedMember(availableMembers[0]); // Dan, user_id 10

      expect(wrapper.vm.selectedMember).toEqual(availableMembers[0]);
      expect(wrapper.vm.access_request_id).toBe(100); // access request id for user 10
    });
  });

  // ==========================================
  // PAGINATION
  // ==========================================
  describe("pagination", () => {
    it("renders pagination component", () => {
      wrapper = createWrapper();
      const pagination = wrapper.findComponent({ name: "BPagination" });
      expect(pagination.exists()).toBe(true);
    });

    it("sets perPage to 10", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.perPage).toBe(10);
    });

    it("starts on page 1", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.currentPage).toBe(1);
    });
  });

  // ==========================================
  // AJAX ROLE CHANGE (B4)
  // ==========================================
  describe("AJAX role change", () => {
    it("sends PUT request with new role", async () => {
      const axios = (await import("axios")).default;
      wrapper = createWrapper({ editable: true });
      const member = { id: 1, role: "reviewer" };

      await wrapper.vm.roleChanged({}, member);

      expect(axios.put).toHaveBeenCalledWith("/memberships/1.json", {
        membership: { role: "reviewer" },
      });
    });
  });

  // ==========================================
  // AJAX REMOVE MEMBER (B4)
  // ==========================================
  describe("AJAX remove member", () => {
    it("sends DELETE request and emits memberRemoved", async () => {
      const axios = (await import("axios")).default;
      // Mock confirm to return true
      vi.spyOn(window, "confirm").mockReturnValue(true);
      wrapper = createWrapper({ editable: true });
      const member = { id: 2, name: "Bob", email: "bob@example.com" };

      await wrapper.vm.removeMember(member);

      expect(axios.delete).toHaveBeenCalledWith("/memberships/2.json");
      expect(wrapper.emitted("memberRemoved")).toBeTruthy();
      expect(wrapper.emitted("memberRemoved")[0][0]).toEqual(member);
    });

    it("does not send DELETE when confirm is cancelled", async () => {
      const axios = (await import("axios")).default;
      axios.delete.mockClear();
      vi.spyOn(window, "confirm").mockReturnValue(false);
      wrapper = createWrapper({ editable: true });

      await wrapper.vm.removeMember({ id: 2 });

      expect(axios.delete).not.toHaveBeenCalled();
    });

    it("sets removingId during request", async () => {
      vi.spyOn(window, "confirm").mockReturnValue(true);
      wrapper = createWrapper({ editable: true });

      const promise = wrapper.vm.removeMember({ id: 3 });
      expect(wrapper.vm.removingId).toBe(3);

      await promise;
      expect(wrapper.vm.removingId).toBe(null);
    });
  });
});
