import { describe, it, expect, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";

// Mock EasyMDE - it's a third-party library that manipulates DOM heavily
vi.mock("easymde", () => {
  return {
    default: vi.fn().mockImplementation(function (options) {
      this.options = options;
      this.value = vi.fn().mockReturnValue(options.initialValue || "");
      this.codemirror = {
        on: vi.fn(),
      };
      this.toTextArea = vi.fn();
      return this;
    }),
  };
});

// Mock the syntax highlighter
vi.mock("@/utilities/syntaxHighlighter", () => ({
  highlightCode: vi.fn((code, lang) => `<pre class="shiki"><code>${code}</code></pre>`),
}));

import MarkdownTextarea from "@/components/shared/MarkdownTextarea.vue";

/**
 * MarkdownTextarea Component Contract:
 *
 * 1. v-model compatibility: accepts `value` prop, emits `input` event
 * 2. Mode switching: disabled=true shows preview, disabled=false shows editor
 * 3. Empty state: shows "No content" placeholder when value is empty and disabled
 */
describe("MarkdownTextarea", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return shallowMount(MarkdownTextarea, {
      localVue,
      propsData: {
        value: "",
        disabled: false,
        ...props,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
    vi.clearAllMocks();
  });

  describe("read-only mode (disabled=true)", () => {
    it("renders markdown as HTML when value contains content", () => {
      wrapper = createWrapper({
        disabled: true,
        value: "**bold text**",
      });

      const preview = wrapper.find(".markdown-preview");
      expect(preview.exists()).toBe(true);
      // Should contain rendered HTML, not raw markdown
      expect(preview.html()).toContain("<strong>");
    });

    it('shows "No content" placeholder when value is empty', () => {
      wrapper = createWrapper({
        disabled: true,
        value: "",
      });

      const preview = wrapper.find(".markdown-preview");
      expect(preview.exists()).toBe(true);
      expect(preview.text()).toContain("No content");
    });

    it("does not render the editor textarea", () => {
      wrapper = createWrapper({
        disabled: true,
        value: "some content",
      });

      expect(wrapper.find(".easymde-wrapper").exists()).toBe(false);
      expect(wrapper.find("textarea").exists()).toBe(false);
    });
  });

  describe("edit mode (disabled=false)", () => {
    it("renders the editor wrapper with textarea", () => {
      wrapper = createWrapper({
        disabled: false,
        value: "editable content",
      });

      expect(wrapper.find(".easymde-wrapper").exists()).toBe(true);
      expect(wrapper.find("textarea").exists()).toBe(true);
    });

    it("does not render the read-only preview", () => {
      wrapper = createWrapper({
        disabled: false,
        value: "editable content",
      });

      expect(wrapper.find(".markdown-preview").exists()).toBe(false);
    });
  });

  describe("v-model contract", () => {
    it("emits input event when editor content changes", async () => {
      wrapper = createWrapper({
        disabled: false,
        value: "initial",
      });

      // Wait for EasyMDE initialization
      await wrapper.vm.$nextTick();
      await wrapper.vm.$nextTick();

      // Get the change handler that was registered with codemirror
      const EasyMDE = (await import("easymde")).default;
      const instance = EasyMDE.mock.results[0]?.value;

      if (instance?.codemirror?.on) {
        // Find the 'change' handler
        const changeCall = instance.codemirror.on.mock.calls.find((call) => call[0] === "change");

        if (changeCall) {
          // Simulate content change
          instance.value.mockReturnValue("new content");
          changeCall[1](); // Call the change handler

          expect(wrapper.emitted("input")).toBeTruthy();
          expect(wrapper.emitted("input")[0][0]).toBe("new content");
        }
      }
    });
  });

  describe("mode switching", () => {
    it("switches from preview to editor when disabled changes to false", async () => {
      wrapper = createWrapper({
        disabled: true,
        value: "content",
      });

      expect(wrapper.find(".markdown-preview").exists()).toBe(true);
      expect(wrapper.find(".easymde-wrapper").exists()).toBe(false);

      await wrapper.setProps({ disabled: false });

      expect(wrapper.find(".markdown-preview").exists()).toBe(false);
      expect(wrapper.find(".easymde-wrapper").exists()).toBe(true);
    });

    it("switches from editor to preview when disabled changes to true", async () => {
      wrapper = createWrapper({
        disabled: false,
        value: "content",
      });

      expect(wrapper.find(".easymde-wrapper").exists()).toBe(true);
      expect(wrapper.find(".markdown-preview").exists()).toBe(false);

      await wrapper.setProps({ disabled: true });

      expect(wrapper.find(".easymde-wrapper").exists()).toBe(false);
      expect(wrapper.find(".markdown-preview").exists()).toBe(true);
    });
  });
});
