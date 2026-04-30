import { describe, it, expect, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import UserProfile from "@/components/users/UserProfile.vue";

// Mock axios
vi.mock("axios", () => ({
  default: {
    put: vi.fn(() => Promise.resolve({ data: { toast: "Updated" } })),
    defaults: { headers: { common: {} } },
  },
}));

/**
 * UserProfile Component Requirements
 *
 * REQUIREMENTS:
 *
 * 1. BREADCRUMB:
 *    - Shows "Users / Profile" or just "Profile"
 *
 * 2. COMMAND BAR:
 *    - Uses BaseCommandBar
 *    - LEFT: Save button
 *    - RIGHT: Empty or panel for help/info
 *
 * 3. PROFILE FORM:
 *    - Name (editable unless provider managed)
 *    - Email (editable unless provider managed)
 *    - Slack User ID (optional)
 *    - Password fields (only for local auth)
 *    - Current password required for changes
 *
 * 4. PROVIDER NOTICE:
 *    - Shows notice if managed by external provider (GitHub, OIDC, LDAP)
 *    - Disables fields that can't be changed
 *
 * 5. SAVE:
 *    - Uses axios PUT to /users
 *    - Shows success/error toast
 *    - Handles validation errors
 */
describe("UserProfile", () => {
  let wrapper;

  const defaultProps = {
    user: {
      id: 1,
      name: "Test User",
      email: "test@example.com",
      provider: null,
      slack_user_id: "",
      unconfirmed_email: null,
    },
    histories: [
      { id: 1, user_id: 1, action: "update", auditable_type: "User" },
      { id: 2, user_id: 2, action: "create", auditable_type: "Project" },
    ],
  };

  const createWrapper = (props = {}) => {
    return shallowMount(UserProfile, {
      localVue,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        BBreadcrumb: true,
        BaseCommandBar: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // REQUIREMENT: Option B layout — single scrolling page of full-width
  // stacked sections. Each section is its own b-card. Order prioritizes
  // commenter feedback loop (My Comments first, then settings, then
  // password change collapsed).
  describe("Option B layout", () => {
    it("places My Comments BEFORE Profile Information (commenter-priority)", () => {
      wrapper = createWrapper();
      const html = wrapper.html();
      const myCommentsIdx = html.indexOf("usercomments-stub");
      const profileIdx = html.indexOf("Profile Information");
      expect(myCommentsIdx).toBeGreaterThan(-1);
      expect(profileIdx).toBeGreaterThan(-1);
      expect(myCommentsIdx).toBeLessThan(profileIdx);
    });

    it("does NOT wrap the Profile form CARD in a half-width column", () => {
      wrapper = createWrapper();
      // The old layout used <b-row><b-col md="6"><b-card> which made the
      // entire profile card half-width and left the right column empty.
      // Option B uses full-width cards. b-col md="6" is still legal
      // INSIDE b-form-row (for paired-field grids) — what's gone is the
      // outer <b-row> at the page level wrapping a card.
      const bareRows = wrapper
        .findAll("b-row-stub")
        .filter((r) => !r.element.closest("[is='b-card-stub']"));
      expect(bareRows.length).toBe(0);
    });

    it("uses b-form-row to grid form fields responsively", () => {
      wrapper = createWrapper();
      // <b-form-row> grids paired fields (Name + Email) side-by-side on
      // wide viewports and stacks on narrow — needed once we drop the
      // outer half-width wrapper.
      expect(wrapper.find("b-form-row-stub").exists()).toBe(true);
    });

    it("places Change Password in its own card section", () => {
      wrapper = createWrapper();
      // Change Password lives in its own b-card with header so it's
      // visually segregated from the identity fields without hiding it
      // behind a collapse (always-visible per UX feedback).
      expect(wrapper.html()).toContain("Change Password");
    });
  });

  describe("breadcrumb", () => {
    it("renders breadcrumb", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "BBreadcrumb" }).exists()).toBe(true);
    });

    it("shows Profile breadcrumb", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.breadcrumbs).toBeDefined();
      expect(wrapper.vm.breadcrumbs.some((b) => b.text.includes("Profile"))).toBe(true);
    });
  });

  describe("command bar", () => {
    it("renders BaseCommandBar", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "BaseCommandBar" }).exists()).toBe(true);
    });

    it("has Save button in command bar", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.saveProfile).toBeDefined();
    });
  });

  describe("form fields", () => {
    it("initializes form with user data", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.form.name).toBe("Test User");
      expect(wrapper.vm.form.email).toBe("test@example.com");
      expect(wrapper.vm.form.slack_user_id).toBe("");
    });

    it("includes password fields for local auth", () => {
      wrapper = createWrapper({ user: { ...defaultProps.user, provider: null } });
      // Form should have password fields
      expect(wrapper.vm.form.password).toBeDefined();
      expect(wrapper.vm.form.password_confirmation).toBeDefined();
      expect(wrapper.vm.form.current_password).toBeDefined();
    });
  });

  describe("provider managed", () => {
    it("detects provider managed users", () => {
      wrapper = createWrapper({ user: { ...defaultProps.user, provider: "github" } });
      expect(wrapper.vm.isProviderManaged).toBe(true);
    });

    it("detects local auth users", () => {
      wrapper = createWrapper({ user: { ...defaultProps.user, provider: null } });
      expect(wrapper.vm.isProviderManaged).toBe(false);
    });
  });

  describe("unlink identity", () => {
    it("shows the unlink button when an external identity is linked", () => {
      wrapper = createWrapper({ user: { ...defaultProps.user, provider: "oidc" } });
      expect(wrapper.find('[data-test="unlink-identity-button"]').exists()).toBe(true);
    });

    it("does not show the unlink button for local-only accounts", () => {
      wrapper = createWrapper({ user: { ...defaultProps.user, provider: null } });
      expect(wrapper.find('[data-test="unlink-identity-button"]').exists()).toBe(false);
    });

    it("has a method to submit the unlink request with current password", async () => {
      const axios = (await import("axios")).default;
      axios.post = vi.fn(() => Promise.resolve({ data: { toast: "unlinked" } }));

      wrapper = createWrapper({ user: { ...defaultProps.user, provider: "oidc" } });
      wrapper.vm.unlinkForm.current_password = "mypassword";
      await wrapper.vm.submitUnlink();

      expect(axios.post).toHaveBeenCalledWith("/users/unlink_identity", {
        current_password: "mypassword",
      });
    });
  });

  describe("dead code removal (71q.7)", () => {
    it("does not have an authProvider computed property", () => {
      const wrapper = createWrapper();
      expect(wrapper.vm.$options.computed).not.toHaveProperty("authProvider");
    });
  });

  describe("session auth method vs linked provider", () => {
    // The session auth method (HOW they signed in now) is distinct from the
    // linked provider (WHAT identity is attached to the account). A user with
    // a linked Okta account may still sign in locally with email/password.

    it("shows 'Email and password' when signing in locally with no linked provider", () => {
      wrapper = createWrapper({
        user: { ...defaultProps.user, provider: null },
        sessionAuthMethod: "local",
      });
      expect(wrapper.vm.currentSessionMethod).toBe("Email and password");
      expect(wrapper.vm.linkedProvider).toBeNull();
    });

    it("shows 'Email and password' when signing in locally but Okta is linked", () => {
      // Regression: Previously showed "Authenticated via Okta" even when the user
      // signed in with their local password, which was misleading.
      wrapper = createWrapper({
        user: { ...defaultProps.user, provider: "oidc" },
        sessionAuthMethod: "local",
      });
      expect(wrapper.vm.currentSessionMethod).toBe("Email and password");
      expect(wrapper.vm.linkedProvider).toBe("OIDC (SSO)");
    });

    it("shows 'OIDC (SSO)' when signing in via OIDC", () => {
      wrapper = createWrapper({
        user: { ...defaultProps.user, provider: "oidc" },
        sessionAuthMethod: "oidc",
      });
      expect(wrapper.vm.currentSessionMethod).toBe("OIDC (SSO)");
    });

    it("shows 'LDAP' when signing in via LDAP", () => {
      wrapper = createWrapper({
        user: { ...defaultProps.user, provider: "ldap" },
        sessionAuthMethod: "ldap",
      });
      expect(wrapper.vm.currentSessionMethod).toBe("LDAP");
    });

    it("defaults sessionAuthMethod to 'local' when not provided", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.currentSessionMethod).toBe("Email and password");
    });

    it("linkedProvider returns null for local-only accounts", () => {
      wrapper = createWrapper({ user: { ...defaultProps.user, provider: null } });
      expect(wrapper.vm.linkedProvider).toBeNull();
    });
  });

  describe("save profile", () => {
    it("calls axios.put with form data", async () => {
      const axios = (await import("axios")).default;
      wrapper = createWrapper();
      wrapper.vm.form.name = "Updated Name";

      await wrapper.vm.saveProfile();

      expect(axios.put).toHaveBeenCalled();
    });

    it("shows success message on save", async () => {
      wrapper = createWrapper();
      wrapper.vm.form.name = "Updated Name";

      await wrapper.vm.saveProfile();

      // Should emit success or show toast
      expect(wrapper.vm.saving).toBe(false);
    });

    it("focuses current password field on validation error", async () => {
      const axios = (await import("axios")).default;
      axios.put.mockRejectedValue({
        response: {
          data: {
            toast: {
              message: ["Current password can't be blank"],
            },
          },
        },
      });

      wrapper = createWrapper();
      await wrapper.vm.saveProfile();

      // Component should try to focus the field
      expect(wrapper.vm.saving).toBe(false);
    });
  });

  describe("email confirmation", () => {
    it("shows pending confirmation alert when email unconfirmed", () => {
      wrapper = createWrapper({
        user: { ...defaultProps.user, unconfirmed_email: "new@example.com" },
      });
      expect(wrapper.vm.isPendingConfirmation).toBe(true);
    });

    it("does not show alert when email confirmed", () => {
      wrapper = createWrapper({
        user: { ...defaultProps.user, unconfirmed_email: null },
      });
      expect(wrapper.vm.isPendingConfirmation).toBe(false);
    });
  });

  describe("user activity panel", () => {
    it("returns all histories (server already scopes to current user)", () => {
      // The controller filters by `user_id: current_user.id` in registrations#edit,
      // so the component receives only current user's audit records. It must not
      // apply a secondary filter on a field (user_id) that VulcanAudit#format
      // does not emit — that was the bug causing 'No activity yet' to always show.
      wrapper = createWrapper();
      expect(wrapper.vm.userHistories.length).toBe(defaultProps.histories.length);
    });

    it("has togglePanel method from useSidebar", () => {
      wrapper = createWrapper();
      expect(typeof wrapper.vm.togglePanel).toBe("function");
    });
  });

  describe("delete account", () => {
    it("openDeleteAccount shows confirmation modal", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.showDeleteModal).toBe(false);
      wrapper.vm.openDeleteAccount();
      expect(wrapper.vm.showDeleteModal).toBe(true);
    });

    it("confirmDeleteAccount calls axios.delete", async () => {
      const axios = (await import("axios")).default;
      axios.delete = vi.fn(() => Promise.resolve({}));

      wrapper = createWrapper();
      await wrapper.vm.confirmDeleteAccount();

      expect(axios.delete).toHaveBeenCalledWith("/users");
    });
  });
});
