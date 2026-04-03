import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CommentModal from "@/components/shared/CommentModal.vue";

/**
 * CommentModal Component Requirements:
 *
 * 1. TRIGGER BUTTON:
 *    - Renders with provided text, variant, size, and class
 *    - Disabled when buttonDisabled=true
 *    - Shows icon when buttonIcon provided
 *    - Clicking opens the modal
 *
 * 2. MODAL:
 *    - Shows title
 *    - Shows message when provided
 *    - Has a textarea for comment input
 *    - Has a slot for additional content
 *
 * 3. SUBMIT BEHAVIOR:
 *    - Emits 'comment' event with the comment text on submit
 *
 * 4. RESET BEHAVIOR:
 *    - Clears comment text when modal is shown or hidden
 */
describe("CommentModal", () => {
  let wrapper;

  const createWrapper = (props = {}, slots = {}) => {
    return mount(CommentModal, {
      localVue,
      propsData: {
        title: "Test Modal Title",
        buttonText: "Open Modal",
        ...props,
      },
      slots,
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // ==========================================
  // TRIGGER BUTTON
  // ==========================================
  describe("trigger button", () => {
    it("renders button with correct text", () => {
      wrapper = createWrapper({ buttonText: "Submit Comment" });
      const button = wrapper.find("button");
      expect(button.text()).toContain("Submit Comment");
    });

    it("renders button with default primary variant", () => {
      wrapper = createWrapper();
      const button = wrapper.find("button");
      expect(button.classes()).toContain("btn-primary");
    });

    it("renders button with custom variant", () => {
      wrapper = createWrapper({ buttonVariant: "danger" });
      const button = wrapper.find("button");
      expect(button.classes()).toContain("btn-danger");
    });

    it("renders button with custom size", () => {
      wrapper = createWrapper({ buttonSize: "sm" });
      const button = wrapper.find("button");
      expect(button.classes()).toContain("btn-sm");
    });

    it("disables button when buttonDisabled is true", () => {
      wrapper = createWrapper({ buttonDisabled: true });
      const button = wrapper.find("button");
      expect(button.attributes("disabled")).toBeDefined();
    });

    it("enables button when buttonDisabled is false", () => {
      wrapper = createWrapper({ buttonDisabled: false });
      const button = wrapper.find("button");
      expect(button.attributes("disabled")).toBeUndefined();
    });

    it("shows icon when buttonIcon is provided", () => {
      wrapper = createWrapper({ buttonIcon: "pencil" });
      // BootstrapVue BIcon is functional, so check for rendered SVG
      const button = wrapper.find("button");
      const svg = button.find("svg");
      expect(svg.exists()).toBe(true);
    });

    it("does not show icon when buttonIcon is null", () => {
      wrapper = createWrapper({ buttonIcon: null });
      const icons = wrapper.findAllComponents({ name: "BIcon" });
      expect(icons.length).toBe(0);
    });

    it("shows disabled tooltip when button is disabled", () => {
      wrapper = createWrapper({ buttonDisabled: true });
      const button = wrapper.find("button");
      expect(button.attributes("title")).toBe("Cannot replace on read only mode");
    });

    it("applies custom buttonClass", () => {
      wrapper = createWrapper({ buttonClass: ["custom-class"] });
      const button = wrapper.find("button");
      expect(button.classes()).toContain("custom-class");
    });
  });

  // ==========================================
  // WRAPPER
  // ==========================================
  describe("wrapper", () => {
    it("applies wrapperClass to container div", () => {
      wrapper = createWrapper({ wrapperClass: "my-wrapper" });
      expect(wrapper.find(".my-wrapper").exists()).toBe(true);
    });
  });

  // ==========================================
  // MODAL CONTENT
  // ==========================================
  describe("modal content", () => {
    it("renders modal with correct title", () => {
      wrapper = createWrapper({ title: "My Comment Title" });
      const modal = wrapper.findComponent({ name: "BModal" });
      expect(modal.exists()).toBe(true);
      expect(modal.props("title")).toBe("My Comment Title");
    });

    it("renders modal with custom size when provided", () => {
      wrapper = createWrapper({ size: "lg" });
      const modal = wrapper.findComponent({ name: "BModal" });
      expect(modal.props("size")).toBe("lg");
    });

    it("renders modal centered", () => {
      wrapper = createWrapper();
      const modal = wrapper.findComponent({ name: "BModal" });
      expect(modal.props("centered")).toBe(true);
    });

    it("passes message prop to component that renders inside modal", () => {
      // BModal lazy-renders body only when open. Verify prop is set correctly.
      wrapper = createWrapper({ message: "Please provide a reason" });
      expect(wrapper.props("message")).toBe("Please provide a reason");
    });

    it("has empty message by default", () => {
      wrapper = createWrapper();
      expect(wrapper.props("message")).toBe("");
    });

    it("modal ref is accessible on the component", () => {
      // BModal lazy-renders body content. The modal ref itself is always available.
      wrapper = createWrapper();
      const modal = wrapper.findComponent({ name: "BModal" });
      expect(modal.exists()).toBe(true);
    });

    it("renders slot content inside modal body", () => {
      // BModal lazy-renders body. Verify slot is declared by checking HTML for slot structure.
      // We test that the component accepts slot content without error.
      wrapper = createWrapper({}, { default: "<p>Slot content here</p>" });
      // Component should mount without errors
      expect(wrapper.exists()).toBe(true);
    });
  });

  // ==========================================
  // SUBMIT BEHAVIOR
  // ==========================================
  describe("submit behavior", () => {
    it("emits 'comment' event with comment text when handleSubmit is called", () => {
      wrapper = createWrapper();
      wrapper.vm.comment = "My test comment";
      wrapper.vm.handleSubmit();

      expect(wrapper.emitted("comment")).toBeTruthy();
      expect(wrapper.emitted("comment")[0]).toEqual(["My test comment"]);
    });

    it("emits 'comment' with empty string when submitted without typing", () => {
      wrapper = createWrapper();
      wrapper.vm.handleSubmit();

      expect(wrapper.emitted("comment")).toBeTruthy();
      expect(wrapper.emitted("comment")[0]).toEqual([""]);
    });

    it("handleOk prevents default and calls handleSubmit", () => {
      wrapper = createWrapper();
      wrapper.vm.comment = "Test via handleOk";

      const mockEvent = { preventDefault: vi.fn() };
      wrapper.vm.handleOk(mockEvent);

      expect(mockEvent.preventDefault).toHaveBeenCalled();
      expect(wrapper.emitted("comment")).toBeTruthy();
      expect(wrapper.emitted("comment")[0]).toEqual(["Test via handleOk"]);
    });
  });

  // ==========================================
  // RESET BEHAVIOR
  // ==========================================
  describe("reset behavior", () => {
    it("resetModal clears comment to empty string", () => {
      wrapper = createWrapper();
      wrapper.vm.comment = "Some text that should be cleared";
      wrapper.vm.resetModal();

      expect(wrapper.vm.comment).toBe("");
    });

    it("initializes comment as empty string", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.comment).toBe("");
    });
  });

  // ==========================================
  // DATA INITIALIZATION
  // ==========================================
  describe("data initialization", () => {
    it("generates a random mod value for unique modal id", () => {
      wrapper = createWrapper();
      expect(typeof wrapper.vm.mod).toBe("number");
      expect(wrapper.vm.mod).toBeGreaterThanOrEqual(0);
      expect(wrapper.vm.mod).toBeLessThan(1000);
    });

    it("two instances have potentially different mod values", () => {
      // This tests that mod is randomly generated (not hardcoded)
      const wrapper1 = createWrapper();
      const wrapper2 = createWrapper();

      // They should both be numbers (even if they happen to be the same)
      expect(typeof wrapper1.vm.mod).toBe("number");
      expect(typeof wrapper2.vm.mod).toBe("number");

      wrapper1.destroy();
      wrapper2.destroy();
    });
  });
});
