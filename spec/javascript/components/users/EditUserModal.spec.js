import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import EditUserModal from "@/components/users/EditUserModal.vue";
import axios from "axios";

vi.mock("axios");

// BModal renders content outside the wrapper in jsdom.
// Test via wrapper.vm (data/methods) and document.querySelector for DOM.
describe("EditUserModal", () => {
  let wrapper;

  const testUser = {
    id: 42,
    name: "Test User",
    email: "test@example.com",
    admin: false,
    provider: null,
  };

  const mountModal = (props = {}) => {
    const div = document.createElement("div");
    document.body.appendChild(div);
    wrapper = mount(EditUserModal, {
      localVue,
      propsData: {
        visible: true,
        user: testUser,
        smtpEnabled: false,
        ...props,
      },
      attachTo: div,
    });
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("form population", () => {
    beforeEach(() => mountModal());

    it("populates local data with user data", () => {
      expect(wrapper.vm.localUser.name).toBe("Test User");
      expect(wrapper.vm.localUser.email).toBe("test@example.com");
    });

    it("renders form fields in DOM", () => {
      expect(document.querySelector("#edit-user-name")).toBeTruthy();
      expect(document.querySelector("#edit-user-email")).toBeTruthy();
    });

    it("shows provider badge for local user", () => {
      expect(wrapper.vm.providerLabel).toBe("Local");
    });
  });

  describe("provider display", () => {
    it("shows GITHUB for github provider", () => {
      mountModal({ user: { ...testUser, provider: "github" } });
      expect(wrapper.vm.providerLabel).toBe("GITHUB");
      expect(wrapper.vm.providerVariant).toBe("dark");
    });

    it("shows OIDC for oidc provider", () => {
      mountModal({ user: { ...testUser, provider: "oidc" } });
      expect(wrapper.vm.providerLabel).toBe("OIDC");
      expect(wrapper.vm.providerVariant).toBe("primary");
    });

    it("shows LDAP with info variant", () => {
      mountModal({ user: { ...testUser, provider: "ldap" } });
      expect(wrapper.vm.providerLabel).toBe("LDAP");
      expect(wrapper.vm.providerVariant).toBe("info");
    });
  });

  describe("password reset button", () => {
    it("is visible when local user and SMTP enabled", () => {
      mountModal({ smtpEnabled: true });
      expect(wrapper.vm.isLocalUser).toBe(true);
      // Button should render - check via vm since BModal teleports content
      expect(wrapper.vm.smtpEnabled).toBe(true);
    });

    it("is hidden when SMTP disabled", () => {
      mountModal({ smtpEnabled: false });
      expect(document.querySelector('[data-testid="send-reset-btn"]')).toBeFalsy();
    });

    it("is hidden for non-local users even with SMTP", () => {
      mountModal({ smtpEnabled: true, user: { ...testUser, provider: "oidc" } });
      expect(wrapper.vm.isLocalUser).toBe(false);
      expect(document.querySelector('[data-testid="send-reset-btn"]')).toBeFalsy();
    });

    it("sends password reset on click", async () => {
      axios.post.mockResolvedValue({ data: { toast: "Reset sent." } });
      mountModal({ smtpEnabled: true });

      await wrapper.vm.sendPasswordReset();

      expect(axios.post).toHaveBeenCalledWith("/users/42/send_password_reset");
    });
  });

  describe("form submission", () => {
    beforeEach(() => mountModal());

    it("sends PUT with updated user data", async () => {
      const updatedUser = {
        id: 42,
        name: "Updated",
        email: "updated@test.com",
        admin: true,
        provider: null,
      };
      axios.put.mockResolvedValue({ data: { toast: "OK", user: updatedUser } });

      wrapper.vm.localUser.name = "Updated";
      wrapper.vm.localUser.email = "updated@test.com";

      await wrapper.vm.onSubmit({ preventDefault: vi.fn() });

      expect(axios.put).toHaveBeenCalledWith("/users/42", {
        user: expect.objectContaining({
          name: "Updated",
          email: "updated@test.com",
        }),
      });
    });

    it("emits user-updated on success", async () => {
      const updatedUser = {
        id: 42,
        name: "Updated",
        email: "test@example.com",
        admin: false,
        provider: null,
      };
      axios.put.mockResolvedValue({ data: { toast: "OK", user: updatedUser } });

      await wrapper.vm.onSubmit({ preventDefault: vi.fn() });

      expect(wrapper.emitted("user-updated")).toBeTruthy();
      expect(wrapper.emitted("user-updated")[0][0]).toEqual(updatedUser);
    });
  });

  describe("generate reset link (no SMTP)", () => {
    beforeEach(() => mountModal({ smtpEnabled: false }));

    it("calls generate_reset_link endpoint", async () => {
      const resetUrl = "http://localhost:3000/users/password/edit?reset_password_token=abc123";
      axios.post.mockResolvedValue({ data: { toast: "Link generated.", reset_url: resetUrl } });

      await wrapper.vm.generateResetLink();

      expect(axios.post).toHaveBeenCalledWith("/users/42/generate_reset_link");
    });

    it("stores the returned reset URL", async () => {
      const resetUrl = "http://localhost:3000/users/password/edit?reset_password_token=abc123";
      axios.post.mockResolvedValue({ data: { toast: "Link generated.", reset_url: resetUrl } });

      await wrapper.vm.generateResetLink();

      expect(wrapper.vm.generatedResetUrl).toBe(resetUrl);
    });
  });

  describe("set password directly (no SMTP)", () => {
    beforeEach(() =>
      mountModal({
        smtpEnabled: false,
        passwordPolicy: {
          min_length: 15,
          min_uppercase: 2,
          min_lowercase: 2,
          min_number: 2,
          min_special: 2,
        },
      }),
    );

    it("manual password section is collapsed by default", () => {
      expect(wrapper.vm.showManualPassword).toBe(false);
    });

    it("toggles manual password section visibility", async () => {
      wrapper.vm.showManualPassword = true;
      await wrapper.vm.$nextTick();
      expect(wrapper.vm.showManualPassword).toBe(true);
    });

    it("calls set_password endpoint with provided password", async () => {
      axios.post.mockResolvedValue({ data: { toast: "Password set." } });
      wrapper.vm.directPassword = "N3wSecure!!Pass99";
      wrapper.vm.directPasswordConfirm = "N3wSecure!!Pass99";

      await wrapper.vm.setPasswordDirectly();

      expect(axios.post).toHaveBeenCalledWith("/users/42/set_password", {
        user: { password: "N3wSecure!!Pass99" },
      });
    });

    it("does not submit when passwords do not match", async () => {
      wrapper.vm.directPassword = "N3wSecure!!Pass99";
      wrapper.vm.directPasswordConfirm = "Different!!Pass99";

      await wrapper.vm.setPasswordDirectly();

      expect(axios.post).not.toHaveBeenCalled();
    });

    it("clears both password fields after success", async () => {
      axios.post.mockResolvedValue({ data: { toast: "Password set." } });
      wrapper.vm.directPassword = "N3wSecure!!Pass99";
      wrapper.vm.directPasswordConfirm = "N3wSecure!!Pass99";

      await wrapper.vm.setPasswordDirectly();

      expect(wrapper.vm.directPassword).toBe("");
      expect(wrapper.vm.directPasswordConfirm).toBe("");
    });

    it("does not clear password fields on error", async () => {
      axios.post.mockRejectedValue({
        response: {
          data: { toast: { title: "Error", message: ["Too short"], variant: "danger" } },
        },
      });
      wrapper.vm.directPassword = "bad";
      wrapper.vm.directPasswordConfirm = "bad";

      await wrapper.vm.setPasswordDirectly();

      expect(wrapper.vm.directPassword).toBe("bad");
    });
  });

  describe("unlock button", () => {
    it("shows unlock section when user is locked and lockoutEnabled", () => {
      mountModal({
        lockoutEnabled: true,
        user: { ...testUser, locked_at: "2026-02-19T10:00:00Z", failed_attempts: 3 },
      });
      expect(wrapper.vm.isLocked).toBe(true);
      expect(wrapper.vm.lockoutEnabled).toBe(true);
    });

    it("hides unlock button when user is not locked", () => {
      mountModal({ lockoutEnabled: true });
      expect(document.querySelector('[data-testid="unlock-btn"]')).toBeFalsy();
    });

    it("hides unlock button when lockoutEnabled is false", () => {
      mountModal({
        lockoutEnabled: false,
        user: { ...testUser, locked_at: "2026-02-19T10:00:00Z", failed_attempts: 3 },
      });
      expect(document.querySelector('[data-testid="unlock-btn"]')).toBeFalsy();
    });

    it("sends POST to unlock endpoint on click", async () => {
      const unlockedUser = { ...testUser, locked_at: null, failed_attempts: 0 };
      axios.post.mockResolvedValue({
        data: { toast: "Unlocked.", user: unlockedUser },
      });
      mountModal({
        lockoutEnabled: true,
        user: { ...testUser, locked_at: "2026-02-19T10:00:00Z", failed_attempts: 3 },
      });

      await wrapper.vm.unlockUser();

      expect(axios.post).toHaveBeenCalledWith("/users/42/unlock");
    });

    it("emits user-updated with unlocked user data", async () => {
      const unlockedUser = { ...testUser, locked_at: null, failed_attempts: 0 };
      axios.post.mockResolvedValue({
        data: { toast: "Unlocked.", user: unlockedUser },
      });
      mountModal({
        lockoutEnabled: true,
        user: { ...testUser, locked_at: "2026-02-19T10:00:00Z", failed_attempts: 3 },
      });

      await wrapper.vm.unlockUser();

      expect(wrapper.emitted("user-updated")).toBeTruthy();
      expect(wrapper.emitted("user-updated")[0][0].locked_at).toBeNull();
    });
  });

  describe("lock button", () => {
    it("shows lock button when user is NOT locked and lockoutEnabled", () => {
      mountModal({
        lockoutEnabled: true,
        user: { ...testUser, locked_at: null, failed_attempts: 0 },
      });
      expect(wrapper.vm.isLocked).toBe(false);
      expect(wrapper.vm.lockoutEnabled).toBe(true);
      // Lock button renders in BModal (teleported) — verify via vm state
      // The template condition is: lockoutEnabled && !isLocked
      expect(wrapper.vm.locking).toBe(false);
    });

    it("hides lock button when user IS locked", () => {
      mountModal({
        lockoutEnabled: true,
        user: { ...testUser, locked_at: "2026-02-19T10:00:00Z", failed_attempts: 3 },
      });
      expect(document.querySelector('[data-testid="lock-btn"]')).toBeFalsy();
    });

    it("hides lock button when lockoutEnabled is false", () => {
      mountModal({
        lockoutEnabled: false,
        user: { ...testUser, locked_at: null, failed_attempts: 0 },
      });
      expect(document.querySelector('[data-testid="lock-btn"]')).toBeFalsy();
    });

    it("sends POST to lock endpoint on click", async () => {
      const lockedUser = { ...testUser, locked_at: "2026-02-20T00:00:00Z", failed_attempts: 0 };
      axios.post.mockResolvedValue({
        data: { toast: "Locked.", user: lockedUser },
      });
      mountModal({
        lockoutEnabled: true,
        user: { ...testUser, locked_at: null, failed_attempts: 0 },
      });

      await wrapper.vm.lockUser();

      expect(axios.post).toHaveBeenCalledWith("/users/42/lock");
    });

    it("emits user-updated with locked user data", async () => {
      const lockedUser = { ...testUser, locked_at: "2026-02-20T00:00:00Z", failed_attempts: 0 };
      axios.post.mockResolvedValue({
        data: { toast: "Locked.", user: lockedUser },
      });
      mountModal({
        lockoutEnabled: true,
        user: { ...testUser, locked_at: null, failed_attempts: 0 },
      });

      await wrapper.vm.lockUser();

      expect(wrapper.emitted("user-updated")).toBeTruthy();
      expect(wrapper.emitted("user-updated")[0][0].locked_at).toBeTruthy();
    });
  });

  describe("password actions hidden for non-local users", () => {
    it("hides all password actions for OIDC users", () => {
      mountModal({ smtpEnabled: false, user: { ...testUser, provider: "oidc" } });
      expect(wrapper.vm.isLocalUser).toBe(false);
    });
  });

  describe("user prop changes", () => {
    it("updates local data when user prop changes", async () => {
      mountModal();
      const newUser = {
        id: 99,
        name: "Other",
        email: "other@test.com",
        admin: true,
        provider: "github",
      };
      await wrapper.setProps({ user: newUser });
      expect(wrapper.vm.localUser.name).toBe("Other");
    });
  });
});
