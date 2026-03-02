/**
 * ConsentModal.spec.js
 *
 * Requirements (NIST AC-8):
 * - Shows modal when server says consent is required (config.required === true)
 * - Does NOT show modal when config.required is false (already acknowledged server-side)
 * - Does NOT show modal when disabled (config.enabled is false)
 * - "I Agree" button POSTs to /consent/acknowledge (server-side tracking)
 * - On POST success, hides the modal
 * - On POST failure, re-shows the modal (consent not recorded)
 * - Modal cannot be dismissed via backdrop click or Escape key
 * - Content is rendered as sanitized markdown
 */
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ConsentModal from "@/components/shared/ConsentModal.vue";
import axios from "axios";

// Mock axios
vi.mock("axios");

describe("ConsentModal", () => {
  let wrapper;

  const defaultConfig = {
    enabled: true,
    required: true,
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
    vi.clearAllMocks();
  });

  afterEach(() => {
    if (wrapper) wrapper.destroy();
    document.querySelectorAll(".modal-backdrop, .modal").forEach((el) => el.remove());
  });

  describe("when enabled and required (not acknowledged server-side)", () => {
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

    it("renders sanitized markdown content", () => {
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
    it("POSTs to /consent/acknowledge and hides modal on success", async () => {
      axios.post.mockResolvedValue({ status: 200 });
      wrapper = createWrapper();
      expect(wrapper.vm.showModal).toBe(true);

      await wrapper.vm.onAgree();
      await wrapper.vm.$nextTick();

      expect(axios.post).toHaveBeenCalledWith("/consent/acknowledge", null, expect.any(Object));
      expect(wrapper.vm.showModal).toBe(false);
    });

    it("re-shows modal if POST fails", async () => {
      axios.post.mockRejectedValue(new Error("Network error"));
      wrapper = createWrapper();
      expect(wrapper.vm.showModal).toBe(true);

      await wrapper.vm.onAgree();
      await wrapper.vm.$nextTick();

      expect(axios.post).toHaveBeenCalled();
      expect(wrapper.vm.showModal).toBe(true);
    });
  });

  describe("when required is false (already acknowledged server-side)", () => {
    it("does not show the modal", () => {
      wrapper = createWrapper({ ...defaultConfig, required: false });
      expect(wrapper.vm.showModal).toBe(false);
    });
  });

  describe("when disabled", () => {
    it("does not show the modal", () => {
      wrapper = createWrapper({ ...defaultConfig, enabled: false });
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
});
