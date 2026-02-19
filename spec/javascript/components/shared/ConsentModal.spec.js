/**
 * ConsentModal.spec.js
 *
 * Requirements:
 * - Shows modal when enabled AND user has not acknowledged current version
 * - Does NOT show modal when disabled
 * - Does NOT show modal when user has already acknowledged current version
 * - "I Agree" button writes acknowledgment to localStorage
 * - Version increment re-prompts the user (new version key)
 * - Modal cannot be dismissed via backdrop click or Escape key
 * - Content is rendered as sanitized markdown
 */
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ConsentModal from "@/components/shared/ConsentModal.vue";

describe("ConsentModal", () => {
  let wrapper;

  const defaultConfig = {
    enabled: true,
    version: "1",
    title: "Terms of Use",
    content: "**You must agree** to the terms.",
  };

  const createWrapper = (config = defaultConfig) => {
    const div = document.createElement("div");
    document.body.appendChild(div);
    return mount(ConsentModal, {
      localVue,
      attachTo: div,
      propsData: { config },
    });
  };

  beforeEach(() => {
    localStorage.clear();
  });

  afterEach(() => {
    if (wrapper) wrapper.destroy();
    // Clean up any modal remnants from document.body
    document.querySelectorAll(".modal-backdrop, .modal").forEach((el) => el.remove());
  });

  describe("when enabled and not acknowledged", () => {
    beforeEach(() => {
      wrapper = createWrapper();
    });

    it("shows the modal", () => {
      expect(wrapper.vm.showModal).toBe(true);
    });

    it("renders the title", () => {
      const modal = wrapper.findComponent({ name: "BModal" });
      expect(modal.props("title")).toBe("Terms of Use");
    });

    it("renders sanitized markdown content via computed property", () => {
      expect(wrapper.vm.sanitizedContent).toContain("<strong>You must agree</strong>");
    });

    it("prevents backdrop dismissal", () => {
      const modal = wrapper.findComponent({ name: "BModal" });
      expect(modal.props("noCloseOnBackdrop")).toBe(true);
    });

    it("prevents Escape key dismissal", () => {
      const modal = wrapper.findComponent({ name: "BModal" });
      expect(modal.props("noCloseOnEsc")).toBe(true);
    });

    it("hides the header close button", () => {
      const modal = wrapper.findComponent({ name: "BModal" });
      expect(modal.props("hideHeaderClose")).toBe(true);
    });
  });

  describe("when I Agree is clicked", () => {
    it("writes acknowledgment to localStorage and hides modal", async () => {
      wrapper = createWrapper();
      expect(wrapper.vm.showModal).toBe(true);

      // Call the method directly (BModal footer slot rendering is unreliable in jsdom)
      wrapper.vm.onAgree();
      await wrapper.vm.$nextTick();

      expect(localStorage.getItem("vulcan-consent-v1")).toBe("true");
      expect(wrapper.vm.showModal).toBe(false);
    });
  });

  describe("when already acknowledged", () => {
    it("does not show the modal", () => {
      localStorage.setItem("vulcan-consent-v1", "true");
      wrapper = createWrapper();
      expect(wrapper.vm.showModal).toBe(false);
    });
  });

  describe("when disabled", () => {
    it("does not show the modal", () => {
      wrapper = createWrapper({ ...defaultConfig, enabled: false });
      expect(wrapper.vm.showModal).toBe(false);
    });
  });

  describe("version increment", () => {
    it("re-prompts when version changes", () => {
      localStorage.setItem("vulcan-consent-v1", "true");
      wrapper = createWrapper({ ...defaultConfig, version: "2" });
      expect(wrapper.vm.showModal).toBe(true);
    });

    it("does not re-prompt for same version", () => {
      localStorage.setItem("vulcan-consent-v1", "true");
      wrapper = createWrapper();
      expect(wrapper.vm.showModal).toBe(false);
    });
  });

  describe("XSS protection", () => {
    it("sanitizes dangerous HTML in content", () => {
      wrapper = createWrapper({
        ...defaultConfig,
        content: '<script>alert("xss")</script>Safe text',
      });
      expect(wrapper.vm.sanitizedContent).not.toContain("<script>");
      expect(wrapper.vm.sanitizedContent).toContain("Safe text");
    });
  });

  describe("empty content", () => {
    it("renders empty content gracefully", () => {
      wrapper = createWrapper({ ...defaultConfig, content: "" });
      expect(wrapper.vm.sanitizedContent).toBe("");
    });
  });

  describe("storage key format", () => {
    it("uses version-specific storage key", () => {
      wrapper = createWrapper({ ...defaultConfig, version: "42" });
      expect(wrapper.vm.storageKey).toBe("vulcan-consent-v42");
    });
  });
});
