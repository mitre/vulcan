import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CreateUserModal from "@/components/users/CreateUserModal.vue";
import axios from "axios";

vi.mock("axios");

// BModal renders content outside the wrapper in jsdom.
// Test via wrapper.vm (data/methods) and document.querySelector for DOM.
describe("CreateUserModal", () => {
  let wrapper;

  const mountModal = (props = {}) => {
    const div = document.createElement("div");
    document.body.appendChild(div);
    wrapper = mount(CreateUserModal, {
      localVue,
      propsData: {
        visible: true,
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

  describe("form fields", () => {
    beforeEach(() => mountModal());

    it("renders name, email, and admin fields in DOM", () => {
      expect(document.querySelector("#create-user-name")).toBeTruthy();
      expect(document.querySelector("#create-user-email")).toBeTruthy();
      expect(document.querySelector("#create-user-admin")).toBeTruthy();
    });

    it("does not show SMTP info alert when smtp is disabled", () => {
      expect(document.querySelector(".alert-info")).toBeFalsy();
    });
  });

  describe("with SMTP enabled", () => {
    beforeEach(() => mountModal({ smtpEnabled: true }));

    it("shows info alert about setup email", () => {
      expect(document.querySelector(".alert-info")).toBeTruthy();
      expect(document.querySelector(".alert-warning")).toBeFalsy();
    });
  });

  describe("form submission", () => {
    beforeEach(() => mountModal());

    it("posts to /users/admin_create on submit", async () => {
      const userData = {
        id: 99,
        name: "Jane",
        email: "jane@test.com",
        admin: false,
        provider: null,
      };
      axios.post.mockResolvedValue({ data: { toast: "User created.", user: userData } });

      wrapper.vm.form.name = "Jane";
      wrapper.vm.form.email = "jane@test.com";

      await wrapper.vm.onSubmit({ preventDefault: vi.fn() });

      expect(axios.post).toHaveBeenCalledWith("/users/admin_create", {
        user: { name: "Jane", email: "jane@test.com", admin: false },
      });
    });

    it("emits user-created with user data on success", async () => {
      const userData = {
        id: 99,
        name: "Jane",
        email: "jane@test.com",
        admin: false,
        provider: null,
      };
      axios.post.mockResolvedValue({ data: { toast: "User created.", user: userData } });

      await wrapper.vm.onSubmit({ preventDefault: vi.fn() });

      expect(wrapper.emitted("user-created")).toBeTruthy();
      expect(wrapper.emitted("user-created")[0][0]).toEqual(userData);
    });

    it("emits update:visible false on success", async () => {
      axios.post.mockResolvedValue({ data: { toast: "OK", user: {} } });

      await wrapper.vm.onSubmit({ preventDefault: vi.fn() });

      expect(wrapper.emitted("update:visible")).toBeTruthy();
      const updates = wrapper.emitted("update:visible");
      expect(updates[updates.length - 1][0]).toBe(false);
    });

    it("handles error response without emitting user-created", async () => {
      axios.post.mockRejectedValue({
        response: {
          data: { toast: { title: "Error", message: ["Bad email"], variant: "danger" } },
        },
      });

      await wrapper.vm.onSubmit({ preventDefault: vi.fn() });

      expect(wrapper.emitted("user-created")).toBeFalsy();
    });
  });

  describe("with password (SMTP off)", () => {
    beforeEach(() => mountModal({ smtpEnabled: false }));

    it("includes password in POST when provided and confirmed", async () => {
      const userData = {
        id: 99,
        name: "Jane",
        email: "jane@test.com",
        admin: false,
        provider: null,
      };
      axios.post.mockResolvedValue({ data: { toast: "Created.", user: userData } });

      wrapper.vm.form.name = "Jane";
      wrapper.vm.form.email = "jane@test.com";
      wrapper.vm.form.password = "N3wSecure!!Pass99";
      wrapper.vm.form.passwordConfirm = "N3wSecure!!Pass99";

      await wrapper.vm.onSubmit({ preventDefault: vi.fn() });

      expect(axios.post).toHaveBeenCalledWith("/users/admin_create", {
        user: { name: "Jane", email: "jane@test.com", admin: false, password: "N3wSecure!!Pass99" },
      });
    });

    it("does not submit when passwords do not match", async () => {
      wrapper.vm.form.name = "Jane";
      wrapper.vm.form.email = "jane@test.com";
      wrapper.vm.form.password = "N3wSecure!!Pass99";
      wrapper.vm.form.passwordConfirm = "Different!!Pass99";

      await wrapper.vm.onSubmit({ preventDefault: vi.fn() });

      expect(axios.post).not.toHaveBeenCalled();
    });

    it("stores reset_url from response when no password provided", async () => {
      const userData = {
        id: 99,
        name: "Jane",
        email: "jane@test.com",
        admin: false,
        provider: null,
      };
      const resetUrl = "http://localhost:3000/users/password/edit?reset_password_token=abc123";
      axios.post.mockResolvedValue({
        data: { toast: "Created.", user: userData, reset_url: resetUrl },
      });

      await wrapper.vm.onSubmit({ preventDefault: vi.fn() });

      expect(wrapper.vm.createdResetUrl).toBe(resetUrl);
    });
  });

  describe("form reset", () => {
    it("resets form when modal becomes visible", async () => {
      mountModal({ visible: false });
      wrapper.vm.form.name = "leftover";

      await wrapper.setProps({ visible: true });
      expect(wrapper.vm.form.name).toBe("");
      expect(wrapper.vm.form.email).toBe("");
      expect(wrapper.vm.form.admin).toBe(false);
    });
  });
});
