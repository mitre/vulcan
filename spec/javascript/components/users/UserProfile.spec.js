import { describe, it, expect, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import UserProfile from "@/components/users/UserProfile.vue";

vi.mock("axios", () => ({
  default: {
    put: vi.fn(() => Promise.resolve({ data: { toast: "Updated" } })),
    post: vi.fn(() => Promise.resolve({ data: { toast: "ok" } })),
    delete: vi.fn(() => Promise.resolve({})),
    defaults: { headers: { common: {} } },
  },
}));

/**
 * UserProfile is the Profile Information sub-page of the user settings
 * shell. Password change and Activity history live in their own pages
 * (UserPasswordPage / UserActivityPage); My Comments is a separate
 * top-level page reachable from the settings shell's left-rail nav.
 *
 * This component owns:
 *   - Save Profile button (PUT /users)
 *   - Identity provider banner + Unlink modal
 *   - Pending email confirmation banner
 *   - Delete Account button + modal
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
  };

  const createWrapper = (props = {}) =>
    shallowMount(UserProfile, {
      localVue,
      propsData: { ...defaultProps, ...props },
      stubs: { BaseCommandBar: true },
    });

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("layout", () => {
    it("renders Profile Information as a single card section", () => {
      wrapper = createWrapper();
      expect(wrapper.html()).toContain("Profile Information");
    });

    it("does NOT render Change Password (moved to its own page)", () => {
      wrapper = createWrapper();
      expect(wrapper.html()).not.toContain("Change Password");
    });

    it("does NOT render an Activity sidebar (moved to its own page)", () => {
      wrapper = createWrapper();
      expect(wrapper.find("#user-activity-sidebar").exists()).toBe(false);
    });
  });

  describe("command bar", () => {
    it("renders BaseCommandBar with a Save handler", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "BaseCommandBar" }).exists()).toBe(true);
      expect(typeof wrapper.vm.saveProfile).toBe("function");
    });
  });

  describe("form fields", () => {
    it("seeds the form with name, email, and slack_user_id only", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.form).toEqual({
        name: "Test User",
        email: "test@example.com",
        slack_user_id: "",
      });
    });

    it("does not carry password fields (moved to UserPasswordPage)", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.form.password).toBeUndefined();
      expect(wrapper.vm.form.current_password).toBeUndefined();
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

    it("submits the unlink request with current password", async () => {
      const axios = (await import("axios")).default;
      wrapper = createWrapper({ user: { ...defaultProps.user, provider: "oidc" } });
      wrapper.vm.unlinkForm.current_password = "mypassword";
      await wrapper.vm.submitUnlink();

      expect(axios.post).toHaveBeenCalledWith("/users/unlink_identity", {
        current_password: "mypassword",
      });
    });
  });

  describe("session auth method vs linked provider", () => {
    it("shows 'Email and password' when signing in locally with no linked provider", () => {
      wrapper = createWrapper({
        user: { ...defaultProps.user, provider: null },
        sessionAuthMethod: "local",
      });
      expect(wrapper.vm.currentSessionMethod).toBe("Email and password");
      expect(wrapper.vm.linkedProvider).toBeNull();
    });

    it("shows 'Email and password' when signing in locally but Okta is linked", () => {
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

    it("defaults sessionAuthMethod to 'local' when not provided", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.currentSessionMethod).toBe("Email and password");
    });
  });

  describe("save profile", () => {
    it("calls axios.put with form data on save", async () => {
      const axios = (await import("axios")).default;
      wrapper = createWrapper();
      wrapper.vm.form.name = "Updated Name";
      await wrapper.vm.saveProfile();

      expect(axios.put).toHaveBeenCalledWith("/users", {
        user: expect.objectContaining({ name: "Updated Name" }),
      });
    });
  });

  describe("email confirmation", () => {
    it("shows pending confirmation when email is unconfirmed", () => {
      wrapper = createWrapper({
        user: { ...defaultProps.user, unconfirmed_email: "new@example.com" },
      });
      expect(wrapper.vm.isPendingConfirmation).toBe(true);
    });

    it("does not show pending when email is confirmed", () => {
      wrapper = createWrapper({
        user: { ...defaultProps.user, unconfirmed_email: null },
      });
      expect(wrapper.vm.isPendingConfirmation).toBe(false);
    });
  });

  describe("delete account", () => {
    it("openDeleteAccount shows the confirmation modal", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.showDeleteModal).toBe(false);
      wrapper.vm.openDeleteAccount();
      expect(wrapper.vm.showDeleteModal).toBe(true);
    });

    it("confirmDeleteAccount calls axios.delete", async () => {
      const axios = (await import("axios")).default;
      wrapper = createWrapper();
      await wrapper.vm.confirmDeleteAccount();
      expect(axios.delete).toHaveBeenCalledWith("/users");
    });
  });
});
