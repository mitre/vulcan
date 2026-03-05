/**
 * DiffViewer Regression Tests
 *
 * REQUIREMENTS:
 * - C9: Base dropdown appears FIRST, Compare dropdown SECOND
 * - Theme selector present and updates monacoEditorOptions
 * - Inline/Side-by-Side toggle updates renderSideBySide and increments editorKey
 * - Monaco editor key includes editorKey for forced re-render on option changes
 */
import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import DiffViewer from "@/components/project/DiffViewer.vue";

describe("DiffViewer", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return shallowMount(DiffViewer, {
      localVue,
      propsData: {
        project: {
          id: 1,
          name: "Test Project",
          components: [
            { id: 1, name: "Comp A", version: 1, release: 1 },
            { id: 2, name: "Comp B", version: 1, release: 2 },
          ],
        },
        ...props,
      },
      stubs: {
        MonacoEditor: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  // ─── C9: Dropdown order ──────────────────────────────────
  describe("dropdown order (C9)", () => {
    it("Base dropdown appears before Compare dropdown", () => {
      wrapper = createWrapper();
      const labels = wrapper.findAll(".rounded-0");
      const labelTexts = labels.wrappers.map((w) => w.text());
      const baseIdx = labelTexts.indexOf("Base");
      const compareIdx = labelTexts.indexOf("Compare");

      expect(baseIdx).toBeGreaterThanOrEqual(0);
      expect(compareIdx).toBeGreaterThanOrEqual(0);
      expect(baseIdx).toBeLessThan(compareIdx);
    });

    it("Base dropdown binds to baseComponent", () => {
      wrapper = createWrapper();
      const baseSelect = wrapper.find("#baseComponent");
      expect(baseSelect.exists()).toBe(true);
    });

    it("Compare dropdown binds to diffComponent", () => {
      wrapper = createWrapper();
      const diffSelect = wrapper.find("#diffComponent");
      expect(diffSelect.exists()).toBe(true);
    });
  });

  // ─── Theme selector ──────────────────────────────────────
  describe("theme selector", () => {
    it("has a theme dropdown", () => {
      wrapper = createWrapper();
      const themeSelect = wrapper.find("#diffTheme");
      expect(themeSelect.exists()).toBe(true);
    });

    it("updateTheme changes monacoEditorOptions.theme", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.monacoEditorOptions.theme).toBe("vs-dark");

      wrapper.vm.updateTheme("vs");
      expect(wrapper.vm.monacoEditorOptions.theme).toBe("vs");
    });

    it("updateTheme increments editorKey for re-render", () => {
      wrapper = createWrapper();
      const initialKey = wrapper.vm.editorKey;
      wrapper.vm.updateTheme("hc-black");
      expect(wrapper.vm.editorKey).toBe(initialKey + 1);
    });
  });

  // ─── Inline/Side-by-Side toggle ──────────────────────────
  describe("inline/side-by-side toggle", () => {
    it("toggles renderSideBySide", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.monacoEditorOptions.renderSideBySide).toBe(true);

      wrapper.vm.updateSettings("renderSideBySide", false);
      expect(wrapper.vm.monacoEditorOptions.renderSideBySide).toBe(false);
    });

    it("increments editorKey on toggle", () => {
      wrapper = createWrapper();
      const initialKey = wrapper.vm.editorKey;
      wrapper.vm.updateSettings("renderSideBySide", false);
      expect(wrapper.vm.editorKey).toBe(initialKey + 1);
    });
  });
});
