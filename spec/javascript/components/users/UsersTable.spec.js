import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import UsersTable from "@/components/users/UsersTable.vue";
import axios from "axios";

vi.mock("axios");

describe("UsersTable", () => {
  let wrapper;

  const users = [
    {
      id: 1,
      name: "Alice Admin",
      email: "alice@test.com",
      admin: true,
      provider: null,
      last_sign_in_at: "2026-01-15T10:00:00Z",
    },
    {
      id: 2,
      name: "Bob User",
      email: "bob@test.com",
      admin: false,
      provider: "github",
      last_sign_in_at: null,
    },
    {
      id: 3,
      name: "Carol LDAP",
      email: "carol@test.com",
      admin: false,
      provider: "ldap",
      last_sign_in_at: "2026-02-01T10:00:00Z",
    },
  ];

  const mountTable = (props = {}) => {
    wrapper = mount(UsersTable, {
      localVue,
      propsData: { users, ...props },
      attachTo: document.createElement("div"),
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("rendering", () => {
    beforeEach(() => mountTable());

    it("displays user count", () => {
      expect(wrapper.text()).toContain("3");
    });

    it("renders all users in table", () => {
      const rows = wrapper.findAll("#users-table tbody tr");
      expect(rows.length).toBe(3);
    });

    it("shows search input with aria-label", () => {
      const input = wrapper.find("#userSearch");
      expect(input.attributes("aria-label")).toBe("Search users");
    });

    it("displays provider labels correctly", () => {
      const text = wrapper.text();
      expect(text).toContain("Local User");
      expect(text).toContain("GITHUB User");
      expect(text).toContain("LDAP User");
    });

    it("displays role badges", () => {
      const badges = wrapper.findAll(".badge");
      const badgeTexts = badges.wrappers.map((b) => b.text());
      expect(badgeTexts).toContain("Admin");
      expect(badgeTexts).toContain("User");
    });

    it("formats last sign in dates", () => {
      expect(wrapper.text()).toContain("Never");
    });

    it("has sortable columns", () => {
      expect(wrapper.vm.fields.filter((f) => f.sortable).length).toBe(4);
    });
  });

  describe("search", () => {
    beforeEach(() => mountTable());

    it("filters by name", async () => {
      await wrapper.find("#userSearch").setValue("alice");
      expect(wrapper.findAll("#users-table tbody tr").length).toBe(1);
    });

    it("filters by email", async () => {
      await wrapper.find("#userSearch").setValue("bob@");
      expect(wrapper.findAll("#users-table tbody tr").length).toBe(1);
    });
  });

  describe("edit action", () => {
    beforeEach(() => mountTable());

    it("emits edit-user when edit button clicked", async () => {
      const editBtns = wrapper.findAll('[aria-label^="Edit"]');
      await editBtns.at(0).trigger("click");
      expect(wrapper.emitted("edit-user")).toBeTruthy();
      expect(wrapper.emitted("edit-user")[0][0].id).toBe(1);
    });

    it("has aria-labels on action buttons", () => {
      const editBtns = wrapper.findAll('[aria-label^="Edit"]');
      expect(editBtns.at(0).attributes("aria-label")).toBe("Edit Alice Admin");
    });
  });

  describe("locked user badge", () => {
    it("shows Locked badge when user has locked_at", () => {
      const usersWithLocked = [
        ...users,
        {
          id: 4,
          name: "Locked User",
          email: "locked@test.com",
          admin: false,
          provider: null,
          last_sign_in_at: null,
          locked_at: "2026-02-19T10:00:00Z",
          failed_attempts: 3,
        },
      ];
      mountTable({ users: usersWithLocked, lockoutEnabled: true });
      const badges = wrapper.findAll(".badge");
      const badgeTexts = badges.wrappers.map((b) => b.text());
      expect(badgeTexts).toContain("Locked");
    });

    it("does not show Locked badge when lockoutEnabled is false", () => {
      const usersWithLocked = [
        {
          id: 4,
          name: "Locked User",
          email: "locked@test.com",
          admin: false,
          provider: null,
          last_sign_in_at: null,
          locked_at: "2026-02-19T10:00:00Z",
          failed_attempts: 3,
        },
      ];
      mountTable({ users: usersWithLocked, lockoutEnabled: false });
      const badges = wrapper.findAll(".badge");
      const badgeTexts = badges.wrappers.map((b) => b.text());
      expect(badgeTexts).not.toContain("Locked");
    });

    it("does not show Locked badge when user is not locked", () => {
      mountTable({ lockoutEnabled: true });
      const badges = wrapper.findAll(".badge");
      const badgeTexts = badges.wrappers.map((b) => b.text());
      expect(badgeTexts).not.toContain("Locked");
    });
  });

  describe("delete action", () => {
    beforeEach(() => mountTable());

    it("shows confirm modal when delete clicked", async () => {
      const deleteBtns = wrapper.findAll('[aria-label^="Remove"]');
      await deleteBtns.at(0).trigger("click");
      expect(wrapper.vm.showDeleteModal).toBe(true);
      expect(wrapper.vm.userToDelete.id).toBe(1);
    });

    it("sends DELETE request on confirm", async () => {
      axios.delete.mockResolvedValue({ data: { toast: "Removed." } });

      wrapper.vm.userToDelete = users[1];
      await wrapper.vm.handleDelete();

      expect(axios.delete).toHaveBeenCalledWith("/users/2");
    });

    it("emits user-deleted on successful delete", async () => {
      axios.delete.mockResolvedValue({ data: { toast: "Removed." } });

      wrapper.vm.userToDelete = users[1];
      await wrapper.vm.handleDelete();

      expect(wrapper.emitted("user-deleted")).toBeTruthy();
      expect(wrapper.emitted("user-deleted")[0][0].id).toBe(2);
    });
  });
});
