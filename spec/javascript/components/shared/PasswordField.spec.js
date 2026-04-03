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
      expect(wrapper.find("input").attributes("autocomplete")).toBe("current-password");
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
      expect(wrapper.find("input").attributes("title")).toBe("This field is required.");
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
  // 6. POLICY CHECKLIST
  // ==========================================
  describe("policy checklist", () => {
    // DoD 2222 default: 15 chars, 2 of each character class
    const defaultPolicy = {
      min_length: 15,
      min_uppercase: 2,
      min_lowercase: 2,
      min_number: 2,
      min_special: 2,
    };

    it("does not render checklist when no policy prop", () => {
      wrapper = createWrapper();
      expect(wrapper.find('[data-testid="password-checklist"]').exists()).toBe(false);
    });

    it("does not render checklist when policy provided but input empty", () => {
      wrapper = createWrapper({ policy: defaultPolicy });
      expect(wrapper.find('[data-testid="password-checklist"]').exists()).toBe(false);
    });

    it("renders checklist when policy provided and user has typed", async () => {
      wrapper = createWrapper({ policy: defaultPolicy });
      await wrapper.find("input").setValue("a");
      expect(wrapper.find('[data-testid="password-checklist"]').exists()).toBe(true);
    });

    it("shows all rules from policy", async () => {
      wrapper = createWrapper({ policy: defaultPolicy });
      await wrapper.find("input").setValue("a");
      const rules = wrapper.findAll('[data-testid="password-rule"]');
      // length + uppercase + lowercase + number + special = 5
      expect(rules.length).toBe(5);
    });

    it("marks met rules with text-success when count satisfied", async () => {
      wrapper = createWrapper({ policy: defaultPolicy });
      // "ab" has 2 lowercase — meets that rule
      await wrapper.find("input").setValue("ab");
      const rules = wrapper.findAll('[data-testid="password-rule"]');
      const lowercaseRule = rules.wrappers.find((r) => r.text().includes("lowercase"));
      expect(lowercaseRule.classes()).toContain("text-success");
    });

    it("marks unmet rules with text-danger when count not satisfied", async () => {
      wrapper = createWrapper({ policy: defaultPolicy });
      // "a" has only 1 lowercase, need 2
      await wrapper.find("input").setValue("A");
      const rules = wrapper.findAll('[data-testid="password-rule"]');
      const uppercaseRule = rules.wrappers.find((r) => r.text().includes("uppercase"));
      expect(uppercaseRule.classes()).toContain("text-danger");
    });

    it("shows correct count in labels", async () => {
      wrapper = createWrapper({ policy: defaultPolicy });
      await wrapper.find("input").setValue("a");
      const rules = wrapper.findAll('[data-testid="password-rule"]');
      const uppercaseRule = rules.wrappers.find((r) => r.text().includes("uppercase"));
      expect(uppercaseRule.text()).toContain("2 uppercase letters");
    });

    it("uses singular form when count is 1", async () => {
      const singlePolicy = {
        min_length: 8,
        min_uppercase: 1,
        min_lowercase: 0,
        min_number: 0,
        min_special: 0,
      };
      wrapper = createWrapper({ policy: singlePolicy });
      await wrapper.find("input").setValue("a");
      const rules = wrapper.findAll('[data-testid="password-rule"]');
      const uppercaseRule = rules.wrappers.find((r) => r.text().includes("uppercase"));
      expect(uppercaseRule.text()).toMatch(/1 uppercase letter$/);
    });

    it("emits update:valid true when all rules met", async () => {
      wrapper = createWrapper({ policy: defaultPolicy });
      // AAbbc12!@defghi = 2up, 7low, 2num, 2spec, 15chars
      await wrapper.find("input").setValue("AAbbc12!@defghi");
      const validEvents = wrapper.emitted("update:valid");
      expect(validEvents[validEvents.length - 1]).toEqual([true]);
    });

    it("emits update:valid false when rules not met", async () => {
      wrapper = createWrapper({ policy: defaultPolicy });
      await wrapper.find("input").setValue("weak");
      const validEvents = wrapper.emitted("update:valid");
      expect(validEvents[validEvents.length - 1]).toEqual([false]);
    });

    it("skips disabled rules (count = 0)", async () => {
      const lengthOnlyPolicy = {
        min_length: 6,
        min_uppercase: 0,
        min_lowercase: 0,
        min_number: 0,
        min_special: 0,
      };
      wrapper = createWrapper({ policy: lengthOnlyPolicy });
      await wrapper.find("input").setValue("abcdef");
      const rules = wrapper.findAll('[data-testid="password-rule"]');
      // Only length rule
      expect(rules.length).toBe(1);
      const validEvents = wrapper.emitted("update:valid");
      expect(validEvents[validEvents.length - 1]).toEqual([true]);
    });
  });

  // ==========================================
  // 7. PASSWORD MATCH INDICATOR
  // ==========================================
  describe("password match indicator", () => {
    it("does not show match indicator when mustMatch not provided", () => {
      wrapper = createWrapper();
      expect(wrapper.find('[data-testid="password-match"]').exists()).toBe(false);
    });

    it("does not show match indicator when input empty", () => {
      wrapper = createWrapper({ mustMatch: "password123" });
      expect(wrapper.find('[data-testid="password-match"]').exists()).toBe(false);
    });

    it("shows 'Passwords match' when values are identical", async () => {
      wrapper = createWrapper({ mustMatch: "MyPassword" });
      await wrapper.find("input").setValue("MyPassword");
      const match = wrapper.find('[data-testid="password-match"]');
      expect(match.exists()).toBe(true);
      expect(match.text()).toContain("Passwords match");
      expect(match.classes()).toContain("text-success");
    });

    it("shows 'Passwords do not match' when values differ", async () => {
      wrapper = createWrapper({ mustMatch: "MyPassword" });
      await wrapper.find("input").setValue("different");
      const match = wrapper.find('[data-testid="password-match"]');
      expect(match.exists()).toBe(true);
      expect(match.text()).toContain("Passwords do not match");
      expect(match.classes()).toContain("text-danger");
    });

    it("updates dynamically when mustMatch prop changes", async () => {
      wrapper = createWrapper({ mustMatch: "original" });
      await wrapper.find("input").setValue("original");
      expect(wrapper.find('[data-testid="password-match"]').classes()).toContain("text-success");

      await wrapper.setProps({ mustMatch: "changed" });
      expect(wrapper.find('[data-testid="password-match"]').classes()).toContain("text-danger");
    });
  });

  // ==========================================
  // 8. ACCESSIBILITY
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
      expect(wrapper.find("button").attributes("aria-label")).toBe("Hide password");
    });
  });
});
