import { describe, it, expect, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import UserProfile from "@/components/users/UserProfile.vue";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: {} })),
    put: vi.fn(() => Promise.resolve({ data: { toast: "Updated" } })),
    post: vi.fn(() => Promise.resolve({ data: { toast: "ok" } })),
    delete: vi.fn(() => Promise.resolve({})),
    patch: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } },
  },
}));

vi.mock("@/api/usersApi", () => ({
  updateProfile: vi.fn(() => Promise.resolve({ data: { toast: "Updated" } })),
  deleteAccount: vi.fn(() => Promise.resolve({})),
  unlinkIdentity: vi.fn(() => Promise.resolve({ data: { toast: "ok" } })),
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
    // Restore any vi.stubGlobal("location", ...) stubs (navigation tests)
    vi.unstubAllGlobals();
  });

  // ── email change requires current password ──────────────────────────
  // REQUIREMENT (field-sensitivity policy — Devise design + OWASP ASVS):
  // name/Slack save without a password; changing the EMAIL (the login
  // identifier) requires the current password. The password field appears
  // only when the email differs from the original, and the payload carries
  // current_password only in that case.
  describe("email change password gate", () => {
    it("hides the current-password field while the email is unchanged", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.emailChanged).toBe(false);
      expect(wrapper.find("#profile-current-password").exists()).toBe(false);
    });

    it("shows the current-password field when the email differs", async () => {
      wrapper = createWrapper();
      wrapper.vm.form.email = "changed@example.com";
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.emailChanged).toBe(true);
      expect(wrapper.find("#profile-current-password").exists()).toBe(true);
    });

    it("never shows the password field for provider-managed users (email read-only)", async () => {
      wrapper = createWrapper({
        user: { ...defaultProps.user, provider: "oidc" },
      });
      wrapper.vm.form.email = "changed@example.com";
      await wrapper.vm.$nextTick();
      expect(wrapper.find("#profile-current-password").exists()).toBe(false);
    });

    it("omits current_password from the payload when the email is unchanged", async () => {
      const { updateProfile } = await import("@/api/usersApi");
      wrapper = createWrapper();
      wrapper.vm.form.name = "Renamed";

      await wrapper.vm.saveProfile();

      expect(updateProfile).toHaveBeenCalledWith({
        name: "Renamed",
        email: "test@example.com",
        slack_user_id: "",
      });
    });

    it("includes current_password in the payload when the email changed", async () => {
      const { updateProfile } = await import("@/api/usersApi");
      wrapper = createWrapper();
      wrapper.vm.form.email = "changed@example.com";
      wrapper.vm.form.current_password = "hunter2!Hunter2!";

      await wrapper.vm.saveProfile();

      expect(updateProfile).toHaveBeenCalledWith({
        name: "Test User",
        email: "changed@example.com",
        slack_user_id: "",
        current_password: "hunter2!Hunter2!",
      });
    });

    it("clears the password field after a successful save", async () => {
      wrapper = createWrapper();
      wrapper.vm.form.email = "changed@example.com";
      wrapper.vm.form.current_password = "hunter2!Hunter2!";

      await wrapper.vm.saveProfile();

      expect(wrapper.vm.form.current_password).toBe("");
    });

    it("rebases the email baseline after a successful change so a follow-up change re-prompts", async () => {
      // Without rebasing, changing BACK to the original address would hide
      // the password field while the server (comparing against the DB)
      // still requires it — the save would 422 with no password input.
      wrapper = createWrapper();
      wrapper.vm.form.email = "changed@example.com";
      wrapper.vm.form.current_password = "hunter2!Hunter2!";

      await wrapper.vm.saveProfile();

      expect(wrapper.vm.emailChanged).toBe(false);
      wrapper.vm.form.email = "test@example.com"; // back to the original
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.emailChanged).toBe(true);
      expect(wrapper.find("#profile-current-password").exists()).toBe(true);
    });

    it("does not rebase the baseline when the save fails", async () => {
      const { updateProfile } = await import("@/api/usersApi");
      updateProfile.mockRejectedValueOnce(
        Object.assign(new Error("422"), { response: { status: 422, data: {} } }),
      );
      wrapper = createWrapper();
      wrapper.vm.form.email = "changed@example.com";
      wrapper.vm.form.current_password = "wrong";

      await wrapper.vm.saveProfile();

      expect(wrapper.vm.emailChanged).toBe(true);
    });
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
    it("seeds the form with profile fields and an empty email-gate password", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.form).toEqual({
        name: "Test User",
        email: "test@example.com",
        slack_user_id: "",
        current_password: "",
      });
    });

    it("does not carry password-change fields (moved to UserPasswordPage)", () => {
      // current_password exists only as the email-change re-auth gate;
      // changing the password itself lives in UserPasswordPage.
      wrapper = createWrapper();
      expect(wrapper.vm.form.password).toBeUndefined();
      expect(wrapper.vm.form.password_confirmation).toBeUndefined();
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

    it("submits the unlink request with current password via unlinkIdentity", async () => {
      const { unlinkIdentity } = await import("@/api/usersApi");
      // location.reload() is the real side effect after unlink (fresh session
      // state). Stub + assert so jsdom never receives the navigation
      // (zero-noise). Restored by afterEach vi.unstubAllGlobals().
      vi.stubGlobal("location", { reload: vi.fn() });
      wrapper = createWrapper({ user: { ...defaultProps.user, provider: "oidc" } });
      wrapper.vm.unlinkForm.current_password = "mypassword";
      await wrapper.vm.submitUnlink();

      expect(unlinkIdentity).toHaveBeenCalledWith({ current_password: "mypassword" });
      expect(globalThis.location.reload).toHaveBeenCalled();
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
    it("calls updateProfile with form data on save", async () => {
      const { updateProfile } = await import("@/api/usersApi");
      wrapper = createWrapper();
      wrapper.vm.form.name = "Updated Name";
      await wrapper.vm.saveProfile();

      expect(updateProfile).toHaveBeenCalledWith(expect.objectContaining({ name: "Updated Name" }));
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

    it("confirmDeleteAccount calls deleteAccount and navigates home", async () => {
      const { deleteAccount } = await import("@/api/usersApi");
      // Navigation to "/" is the requirement after account deletion. Stub +
      // assert so jsdom never receives the navigation (zero-noise).
      // Restored by afterEach vi.unstubAllGlobals().
      vi.stubGlobal("location", { href: "" });
      wrapper = createWrapper();
      await wrapper.vm.confirmDeleteAccount();
      expect(deleteAccount).toHaveBeenCalled();
      expect(globalThis.location.href).toBe("/");
    });
  });

  // ── mixin contract ──────────────────────────────────────────────────
  // REQUIREMENT: no mixins remain; toasts come from the useToast composable.
  describe("mixin contract", () => {
    it("declares no mixins and gets alertOrNotifyResponse from useToast", () => {
      expect(UserProfile.mixins).toBeUndefined();
      wrapper = createWrapper();
      expect(typeof wrapper.vm.alertOrNotifyResponse).toBe("function");
    });
  });
});
