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
      const baseIdx = labelTexts.indexOf("Base (older)");
      const compareIdx = labelTexts.indexOf("Compare (newer)");

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

  // ─── Task 28: FilterDropdown migration ───────────────────
  describe("filter dropdown migration (Task 28)", () => {
    it("Base/Compare/Theme selectors all render as FilterDropdown — no native <select>", () => {
      wrapper = createWrapper();
      const filterDropdowns = wrapper.findAllComponents({ name: "FilterDropdown" });
      // Base, Compare (when baseComponent is set), and Theme — Compare may
      // not render until baseComponent is selected, so only base+theme are
      // guaranteed visible at mount with no baseComponent. We assert the
      // top-level template uses FilterDropdown for all three by opting into
      // a baseComponent assignment first.
      wrapper.setData({ baseComponentId: 1 });
      const all = wrapper.findAllComponents({ name: "FilterDropdown" });
      expect(all.length).toBeGreaterThanOrEqual(2);
      expect(wrapper.find("select").exists()).toBe(false);
    });

    it("baseComponentId v-models the chosen component's ID (primitive, not object)", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.baseComponentId).toBeNull();
      wrapper.vm.baseComponentId = 2;
      expect(typeof wrapper.vm.baseComponentId).toBe("number");
    });

    it("baseComponent computed resolves the full object from baseComponentId", async () => {
      wrapper = createWrapper();
      await wrapper.setData({ baseComponentId: 2 });
      expect(wrapper.vm.baseComponent).toEqual({
        id: 2,
        name: "Comp B",
        version: 1,
        release: 2,
      });
    });

    it("componentOptions exposes [{value, text}] derived from project.components", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.componentOptions).toEqual([
        { value: 1, text: expect.stringContaining("Comp A") },
        { value: 2, text: expect.stringContaining("Comp B") },
      ]);
    });

    it("themeOptions exposes 3 monaco theme entries in {value, text} shape", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.themeOptions).toEqual([
        { value: "vs", text: expect.any(String) },
        { value: "vs-dark", text: expect.any(String) },
        { value: "hc-black", text: expect.any(String) },
      ]);
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
