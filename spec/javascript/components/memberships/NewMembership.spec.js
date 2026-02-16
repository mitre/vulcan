import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import NewMembership from "@/components/memberships/NewMembership.vue";

/**
 * NewMembership Component Requirements:
 *
 * 1. USER SEARCH:
 *    - Shows search input (VueSimpleSuggest) when no user selected
 *    - Shows alert with user name/email when user selected
 *    - Dismissing alert clears selected user
 *
 * 2. ROLE SELECTION:
 *    - Shows role radio buttons only when a user is selected
 *    - Shows one radio button per available role
 *    - Each role has a capitalized label and description
 *
 * 3. SUBMIT:
 *    - Submit button disabled when no user or role selected
 *    - Submit button enabled when both user and role selected
 *    - Button text is "Add User to Project"
 *
 * 4. HIDDEN FORM FIELDS:
 *    - Contains membership_type hidden field
 *    - Contains membership_id hidden field
 *    - Contains user_id hidden field (from selectedUser)
 *    - Contains role hidden field (from selectedRole)
 *    - Contains access_request_id hidden field
 *    - Contains authenticity_token hidden field
 *
 * 5. PRE-SELECTED MEMBER:
 *    - When selected_member prop is provided, starts with that user selected
 *    - Shows alert with pre-selected user's name and email
 */
describe("NewMembership", () => {
  let wrapper;

  const availableMembers = [
    { id: 1, name: "Alice Admin", email: "alice@example.com" },
    { id: 2, name: "Bob Author", email: "bob@example.com" },
    { id: 3, name: "Carol Viewer", email: "carol@example.com" },
  ];

  const availableRoles = ["viewer", "author", "reviewer", "admin"];

  const createWrapper = (props = {}) => {
    return mount(NewMembership, {
      localVue,
      propsData: {
        membership_type: "Project",
        membership_id: 42,
        available_members: availableMembers,
        available_roles: availableRoles,
        ...props,
      },
      stubs: {
        VueSimpleSuggest: {
          template: '<input class="vue-simple-suggest-stub" />',
          props: ["list", "filterByQuery", "displayAttribute", "placeholder", "styles"],
        },
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // ==========================================
  // USER SEARCH / SELECTION
  // ==========================================
  describe("user search and selection", () => {
    it("shows search input when no user is selected", () => {
      wrapper = createWrapper();
      expect(wrapper.find(".vue-simple-suggest-stub").exists()).toBe(true);
    });

    it("hides search input when a user is selected", () => {
      wrapper = createWrapper({ selected_member: availableMembers[0] });
      expect(wrapper.find(".vue-simple-suggest-stub").exists()).toBe(false);
    });

    it("shows alert with user name and email when user is selected", () => {
      wrapper = createWrapper({ selected_member: availableMembers[0] });
      const alert = wrapper.findComponent({ name: "BAlert" });
      expect(alert.exists()).toBe(true);
      expect(alert.text()).toContain("Alice Admin");
      expect(alert.text()).toContain("alice@example.com");
    });

    it("setSelectedUser sets the user and clears search", () => {
      wrapper = createWrapper();
      wrapper.vm.setSelectedUser(availableMembers[1]);

      expect(wrapper.vm.selectedUser).toEqual(availableMembers[1]);
      expect(wrapper.vm.search).toBe("");
    });

    it("setSelectedUser to null clears the selection", () => {
      wrapper = createWrapper({ selected_member: availableMembers[0] });
      wrapper.vm.setSelectedUser(null);

      expect(wrapper.vm.selectedUser).toBeNull();
    });
  });

  // ==========================================
  // ROLE SELECTION
  // ==========================================
  describe("role selection", () => {
    it("shows role radio buttons when a user is selected", () => {
      wrapper = createWrapper({ selected_member: availableMembers[0] });
      const roleInputs = wrapper.findAll(".role-input");
      expect(roleInputs.length).toBe(availableRoles.length);
    });

    it("hides role selection when no user is selected", () => {
      wrapper = createWrapper();
      const roleInputs = wrapper.findAll(".role-input");
      expect(roleInputs.length).toBe(0);
    });

    it("shows capitalized role labels", () => {
      wrapper = createWrapper({ selected_member: availableMembers[0] });
      const roleLabels = wrapper.findAll(".role-label");
      expect(roleLabels.at(0).text()).toBe("Viewer");
      expect(roleLabels.at(1).text()).toBe("Author");
      expect(roleLabels.at(2).text()).toBe("Reviewer");
      expect(roleLabels.at(3).text()).toBe("Admin");
    });

    it("shows role descriptions", () => {
      wrapper = createWrapper({ selected_member: availableMembers[0] });
      const descriptions = wrapper.findAll(".role-description");
      expect(descriptions.length).toBe(availableRoles.length);
      // Each description should have text content
      descriptions.wrappers.forEach((d) => {
        expect(d.text().length).toBeGreaterThan(0);
      });
    });

    it("setSelectedRole sets the role", () => {
      wrapper = createWrapper({ selected_member: availableMembers[0] });
      wrapper.vm.setSelectedRole("reviewer");

      expect(wrapper.vm.selectedRole).toBe("reviewer");
    });
  });

  // ==========================================
  // SUBMIT BUTTON
  // ==========================================
  describe("submit button", () => {
    it("is disabled when no user is selected", () => {
      wrapper = createWrapper();
      const submitBtn = wrapper.find('button[type="submit"]');
      expect(submitBtn.attributes("disabled")).toBeDefined();
    });

    it("is disabled when user is selected but no role", () => {
      wrapper = createWrapper({ selected_member: availableMembers[0] });
      // selectedRole is still null
      const submitBtn = wrapper.find('button[type="submit"]');
      expect(submitBtn.attributes("disabled")).toBeDefined();
    });

    it("is enabled when both user and role are selected", async () => {
      wrapper = createWrapper({ selected_member: availableMembers[0] });
      wrapper.vm.setSelectedRole("author");
      await wrapper.vm.$nextTick();

      const submitBtn = wrapper.find('button[type="submit"]');
      expect(submitBtn.attributes("disabled")).toBeUndefined();
    });

    it("has text 'Add User to Project'", () => {
      wrapper = createWrapper();
      const submitBtn = wrapper.find('button[type="submit"]');
      expect(submitBtn.text()).toBe("Add User to Project");
    });

    it("isSubmitDisabled is true when selectedUser is null", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.isSubmitDisabled).toBe(true);
    });

    it("isSubmitDisabled is true when selectedRole is null", () => {
      wrapper = createWrapper({ selected_member: availableMembers[0] });
      expect(wrapper.vm.isSubmitDisabled).toBe(true);
    });

    it("isSubmitDisabled is false when both selectedUser and selectedRole are set", () => {
      wrapper = createWrapper({ selected_member: availableMembers[0] });
      wrapper.vm.setSelectedRole("author");
      expect(wrapper.vm.isSubmitDisabled).toBe(false);
    });
  });

  // ==========================================
  // HIDDEN FORM FIELDS
  // ==========================================
  describe("hidden form fields", () => {
    it("contains membership_type hidden field with correct value", () => {
      wrapper = createWrapper();
      const field = wrapper.find("#NewMembershipMembershipType");
      expect(field.exists()).toBe(true);
      expect(field.element.value).toBe("Project");
    });

    it("contains membership_id hidden field with correct value", () => {
      wrapper = createWrapper();
      const field = wrapper.find("#NewMembershipMembershipId");
      expect(field.exists()).toBe(true);
      expect(field.element.value).toBe("42");
    });

    it("contains user_id hidden field reflecting selected user", () => {
      wrapper = createWrapper({ selected_member: availableMembers[0] });
      const field = wrapper.find("#NewMembershipEmail");
      expect(field.exists()).toBe(true);
      expect(field.element.value).toBe("1"); // Alice's id
    });

    it("contains role hidden field reflecting selected role", async () => {
      wrapper = createWrapper({ selected_member: availableMembers[0] });
      wrapper.vm.setSelectedRole("reviewer");
      await wrapper.vm.$nextTick();

      const field = wrapper.find("#NewMembershipRole");
      expect(field.exists()).toBe(true);
      expect(field.element.value).toBe("reviewer");
    });

    it("contains authenticity_token hidden field", () => {
      wrapper = createWrapper();
      const field = wrapper.find("#NewProjectMemberAuthenticityToken");
      expect(field.exists()).toBe(true);
      // setup.js sets csrf-token to "test-csrf-token"
      expect(field.element.value).toBe("test-csrf-token");
    });

    it("contains access_request_id hidden field", () => {
      wrapper = createWrapper({ access_request_id: 99 });
      const field = wrapper.find("#access_request_id");
      expect(field.exists()).toBe(true);
      expect(field.element.value).toBe("99");
    });

    it("form action points to /memberships/", () => {
      wrapper = createWrapper();
      const form = wrapper.find("form");
      expect(form.attributes("action")).toBe("/memberships/");
      expect(form.attributes("method")).toBe("post");
    });
  });

  // ==========================================
  // PRE-SELECTED MEMBER
  // ==========================================
  describe("pre-selected member", () => {
    it("shows selected user alert when selected_member prop provided", () => {
      wrapper = createWrapper({
        selected_member: availableMembers[1],
      });
      const alert = wrapper.findComponent({ name: "BAlert" });
      expect(alert.exists()).toBe(true);
      expect(alert.text()).toContain("Bob Author");
      expect(alert.text()).toContain("bob@example.com");
    });

    it("initializes selectedUser from selected_member prop", () => {
      wrapper = createWrapper({
        selected_member: availableMembers[2],
      });
      expect(wrapper.vm.selectedUser).toEqual(availableMembers[2]);
    });

    it("selectedUserId returns selected user id", () => {
      wrapper = createWrapper({
        selected_member: availableMembers[0],
      });
      expect(wrapper.vm.selectedUserId).toBe(1);
    });

    it("selectedUserId returns undefined when no user selected", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.selectedUserId).toBeUndefined();
    });
  });
});
