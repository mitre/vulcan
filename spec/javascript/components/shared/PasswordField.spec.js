import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import PasswordField from "@/components/shared/PasswordField.vue";

/**
 * PasswordField Component Contract Tests
 *
 * REQUIREMENTS:
 *
 * 1. PASSWORD HIDDEN BY DEFAULT:
 *    - Input type must be "password" on initial render
 *    - User's password is not visible as plaintext
 *
 * 2. TOGGLE VISIBILITY:
 *    - Clicking the toggle button switches input to type="text" (shows password)
 *    - Clicking again switches back to type="password" (hides password)
 *    - Toggle is a button (accessible, keyboard-operable)
 *
 * 3. TOGGLE ICON:
 *    - Shows "eye" icon when password is hidden (click to reveal)
 *    - Shows "eye-slash" icon when password is visible (click to hide)
 *
 * 4. FORM INTEGRATION:
 *    - Input has the correct `name` attribute for form submission
 *    - Input has the correct `id` attribute for label association
 *    - Input has `autocomplete` attribute when provided
 *    - Input has `required` attribute when provided
 *    - Input has `form-control` class for Bootstrap styling
 *
 * 5. VALUE BINDING:
 *    - Emits `input` event when user types (v-model compatible)
 *    - Reflects the current value prop in the input
 *
 * 6. AUTOFOCUS:
 *    - Supports `autofocus` prop to focus the input on mount
 */
describe("PasswordField", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return mount(PasswordField, {
      localVue,
      propsData: {
        name: "user[password]",
        id: "user_password",
        ...props,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // ==========================================
  // 1. PASSWORD HIDDEN BY DEFAULT
  // ==========================================
  describe("default state", () => {
    it("renders input with type='password' by default", () => {
      wrapper = createWrapper();
      const input = wrapper.find("input");
      expect(input.attributes("type")).toBe("password");
    });

    it("renders with form-control class for Bootstrap styling", () => {
      wrapper = createWrapper();
      const input = wrapper.find("input");
      expect(input.classes()).toContain("form-control");
    });
  });

  // ==========================================
  // 2. TOGGLE VISIBILITY
  // ==========================================
  describe("toggle visibility", () => {
    it("switches to type='text' when toggle button clicked", async () => {
      wrapper = createWrapper();
      const toggleBtn = wrapper.find("button");
      expect(toggleBtn.exists()).toBe(true);

      await toggleBtn.trigger("click");
      const input = wrapper.find("input");
      expect(input.attributes("type")).toBe("text");
    });

    it("switches back to type='password' on second click", async () => {
      wrapper = createWrapper();
      const toggleBtn = wrapper.find("button");

      await toggleBtn.trigger("click");
      expect(wrapper.find("input").attributes("type")).toBe("text");

      await toggleBtn.trigger("click");
      expect(wrapper.find("input").attributes("type")).toBe("password");
    });

    it("toggle button has type='button' to prevent form submission", () => {
      wrapper = createWrapper();
      const toggleBtn = wrapper.find("button");
      expect(toggleBtn.attributes("type")).toBe("button");
    });

    it("preserves typed password value when toggling visibility (Vue #6313)", async () => {
      wrapper = createWrapper();
      const input = wrapper.find("input");

      // User types a password
      await input.setValue("my-secret-password");
      expect(input.element.value).toBe("my-secret-password");

      // Toggle to show password — value must survive the type change
      await wrapper.find("button").trigger("click");
      expect(input.element.value).toBe("my-secret-password");
      expect(input.attributes("type")).toBe("text");

      // Toggle back to hide — value must still survive
      await wrapper.find("button").trigger("click");
      expect(input.element.value).toBe("my-secret-password");
      expect(input.attributes("type")).toBe("password");
    });
  });

  // ==========================================
  // 3. TOGGLE ICON
  // ==========================================
  describe("toggle icon", () => {
    it("shows eye icon when password is hidden", () => {
      wrapper = createWrapper();
      expect(wrapper.find(".bi-eye").exists()).toBe(true);
      expect(wrapper.find(".bi-eye-slash").exists()).toBe(false);
    });

    it("shows eye-slash icon when password is visible", async () => {
      wrapper = createWrapper();
      await wrapper.find("button").trigger("click");
      expect(wrapper.find(".bi-eye-slash").exists()).toBe(true);
      expect(wrapper.find(".bi-eye").exists()).toBe(false);
    });
  });

  // ==========================================
  // 4. FORM INTEGRATION
  // ==========================================
  describe("form integration", () => {
    it("sets name attribute on input for form submission", () => {
      wrapper = createWrapper({ name: "user[password]" });
      expect(wrapper.find("input").attributes("name")).toBe("user[password]");
    });

    it("sets id attribute on input for label association", () => {
      wrapper = createWrapper({ id: "user_password" });
      expect(wrapper.find("input").attributes("id")).toBe("user_password");
    });

    it("sets autocomplete attribute when provided", () => {
      wrapper = createWrapper({ autocomplete: "current-password" });
      expect(wrapper.find("input").attributes("autocomplete")).toBe(
        "current-password",
      );
    });

    it("sets required attribute when provided", () => {
      wrapper = createWrapper({ required: true });
      expect(wrapper.find("input").attributes("required")).toBe("required");
    });

    it("does not set required when not provided", () => {
      wrapper = createWrapper();
      expect(wrapper.find("input").attributes("required")).toBeUndefined();
    });

    it("sets title attribute when provided", () => {
      wrapper = createWrapper({ title: "This field is required." });
      expect(wrapper.find("input").attributes("title")).toBe(
        "This field is required.",
      );
    });

    it("applies additional CSS class when provided", () => {
      wrapper = createWrapper({ inputClass: "bottom" });
      const input = wrapper.find("input");
      expect(input.classes()).toContain("form-control");
      expect(input.classes()).toContain("bottom");
    });
  });

  // ==========================================
  // 5. VALUE BINDING
  // ==========================================
  describe("value binding (v-model compatible)", () => {
    it("reflects value prop in input", () => {
      wrapper = createWrapper({ value: "secret123" });
      expect(wrapper.find("input").element.value).toBe("secret123");
    });

    it("emits input event when user types", async () => {
      wrapper = createWrapper();
      const input = wrapper.find("input");
      await input.setValue("newpass");
      expect(wrapper.emitted("input")).toBeTruthy();
      expect(wrapper.emitted("input")[0]).toEqual(["newpass"]);
    });
  });

  // ==========================================
  // 6. ACCESSIBILITY
  // ==========================================
  describe("accessibility", () => {
    it("toggle button has aria-label describing its action", () => {
      wrapper = createWrapper();
      const btn = wrapper.find("button");
      expect(btn.attributes("aria-label")).toBe("Show password");
    });

    it("aria-label changes when password is visible", async () => {
      wrapper = createWrapper();
      await wrapper.find("button").trigger("click");
      expect(wrapper.find("button").attributes("aria-label")).toBe(
        "Hide password",
      );
    });
  });
});
