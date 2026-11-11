import { describe, it, expect, beforeEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";

/**
 * MonacoEditor Component Requirements:
 *
 * 1. EDITOR: creates a Monaco editor with the value, language, theme and
 *    options props, and emits `change` with the editor text on every edit.
 * 2. VALUE SYNC: a `value` equal to the editor text leaves the editor alone
 *    (no cursor or undo reset); a different value is a different document and
 *    replaces the content with setValue, editable or not. What Monaco does
 *    with that (undo reset, no `change`) is covered against the real editor
 *    in MonacoEditor.integration.spec.js.
 * 3. LANGUAGE / THEME / OPTIONS: changes are applied to the live editor.
 * 4. DIFF: `diff` creates a diff editor with `original` as the original model
 *    and `value` as the modified model; prop changes update those models.
 * 5. CLEANUP: the editor is disposed; the diff editor's models are disposed;
 *    a plain editor's model is left to Monaco, which owns it.
 */

const monacoMock = vi.hoisted(() => ({ editor: {} }));
vi.mock("@/utils/monaco", () => ({ monaco: monacoMock }));

import MonacoEditor from "@/components/shared/MonacoEditor.vue";

const READ_ONLY = 91;

function fakeModel(text) {
  return {
    text,
    setValue: vi.fn(function (v) {
      this.text = v;
    }),
    getFullModelRange: vi.fn(() => "full-range"),
    dispose: vi.fn(),
  };
}

function fakeEditor(model, readOnly = false) {
  const listeners = [];
  return {
    model,
    getValue: vi.fn(() => model.text),
    setValue: vi.fn((v) => model.setValue(v)),
    getModel: vi.fn(() => model),
    getOption: vi.fn((opt) => (opt === READ_ONLY ? readOnly : undefined)),
    executeEdits: vi.fn(),
    pushUndoStop: vi.fn(),
    updateOptions: vi.fn(),
    dispose: vi.fn(),
    onDidChangeModelContent: vi.fn((fn) => listeners.push(fn)),
    fireChange(text, event = { isFlush: false }) {
      model.text = text;
      listeners.forEach((fn) => fn(event));
    },
  };
}

let created;

beforeEach(() => {
  created = {};
  Object.assign(monacoMock.editor, {
    EditorOption: { readOnly: READ_ONLY },
    create: vi.fn((el, opts) => {
      created.editor = fakeEditor(fakeModel(opts.value), opts.readOnly);
      created.createOptions = opts;
      return created.editor;
    }),
    createDiffEditor: vi.fn((el, opts) => {
      created.diffOptions = opts;
      const diff = {
        models: null,
        setModel: vi.fn((m) => {
          diff.models = m;
          created.modifiedEditor = fakeEditor(m.modified, opts.readOnly);
        }),
        getModel: vi.fn(() => diff.models),
        getModifiedEditor: vi.fn(() => created.modifiedEditor),
        updateOptions: vi.fn(),
        dispose: vi.fn(),
      };
      created.editor = diff;
      return diff;
    }),
    createModel: vi.fn((text) => fakeModel(text)),
    setModelLanguage: vi.fn(),
    setTheme: vi.fn(),
  });
});

const mountEditor = (propsData) => mount(MonacoEditor, { localVue, propsData });

describe("MonacoEditor", () => {
  describe("editor", () => {
    it("creates an editor from the value, language, theme and options", () => {
      mountEditor({ value: "a", language: "ruby", theme: "vs-dark", options: { tabSize: 2 } });

      expect(monacoMock.editor.create).toHaveBeenCalledTimes(1);
      expect(monacoMock.editor.createDiffEditor).not.toHaveBeenCalled();
      expect(created.createOptions).toMatchObject({
        value: "a",
        language: "ruby",
        theme: "vs-dark",
        tabSize: 2,
      });
    });

    it("emits change with the editor text on every edit", () => {
      const wrapper = mountEditor({ value: "a" });

      created.editor.fireChange("ab");

      expect(wrapper.emitted("change")).toEqual([["ab"]]);
    });
  });

  describe("value sync", () => {
    it("leaves the editor alone when the value already matches its text", async () => {
      const wrapper = mountEditor({ value: "a" });
      created.editor.fireChange("ab");

      await wrapper.setProps({ value: "ab" });

      expect(created.editor.executeEdits).not.toHaveBeenCalled();
      expect(created.editor.setValue).not.toHaveBeenCalled();
    });

    it("replaces the document when the value differs", async () => {
      const wrapper = mountEditor({ value: "a" });

      await wrapper.setProps({ value: "b" });

      expect(created.editor.setValue).toHaveBeenCalledWith("b");
      expect(created.editor.executeEdits).not.toHaveBeenCalled();
    });

    it("replaces the document of a read-only editor the same way", async () => {
      const wrapper = mountEditor({ value: "a", options: { readOnly: true } });

      await wrapper.setProps({ value: "b" });

      expect(created.editor.setValue).toHaveBeenCalledWith("b");
      expect(created.editor.executeEdits).not.toHaveBeenCalled();
    });

    it("does not report the replacement as a change", async () => {
      const wrapper = mountEditor({ value: "a" });

      created.editor.fireChange("b", { isFlush: true });

      expect(wrapper.emitted("change")).toBeUndefined();
    });
  });

  describe("language, theme and options", () => {
    it("re-tokenizes the model when the language changes", async () => {
      const wrapper = mountEditor({ value: "a", language: "ruby" });

      await wrapper.setProps({ language: "yaml" });

      expect(monacoMock.editor.setModelLanguage).toHaveBeenCalledWith(created.editor.model, "yaml");
    });

    it("switches the theme", async () => {
      const wrapper = mountEditor({ value: "a", theme: "vs-dark" });

      await wrapper.setProps({ theme: "vs" });

      expect(monacoMock.editor.setTheme).toHaveBeenCalledWith("vs");
    });

    it("updates the live editor's options", async () => {
      const wrapper = mountEditor({ value: "a", options: { tabSize: 2 } });

      await wrapper.setProps({ options: { tabSize: 4 } });

      expect(created.editor.updateOptions).toHaveBeenCalledWith({ tabSize: 4 });
    });
  });

  describe("diff", () => {
    it("shows original as the original model and value as the modified model", () => {
      mountEditor({ diff: true, original: "old", value: "new", language: "ruby" });

      expect(monacoMock.editor.create).not.toHaveBeenCalled();
      const { original, modified } = created.editor.models;
      expect(original.text).toBe("old");
      expect(modified.text).toBe("new");
    });

    it("updates each side when its prop changes", async () => {
      const wrapper = mountEditor({
        diff: true,
        original: "old",
        value: "new",
        options: { readOnly: true },
      });

      await wrapper.setProps({ original: "older", value: "newer" });

      expect(created.editor.models.original.setValue).toHaveBeenCalledWith("older");
      expect(created.modifiedEditor.setValue).toHaveBeenCalledWith("newer");
    });

    it("re-tokenizes both sides when the language changes", async () => {
      const wrapper = mountEditor({ diff: true, original: "old", value: "new", language: "ruby" });

      await wrapper.setProps({ language: "json" });

      const { original, modified } = created.editor.models;
      expect(monacoMock.editor.setModelLanguage).toHaveBeenCalledWith(original, "json");
      expect(monacoMock.editor.setModelLanguage).toHaveBeenCalledWith(modified, "json");
    });
  });

  describe("cleanup", () => {
    it("disposes the editor and leaves its own model to Monaco", () => {
      const wrapper = mountEditor({ value: "a" });
      const { editor } = created;

      wrapper.destroy();

      expect(editor.dispose).toHaveBeenCalled();
      expect(editor.model.dispose).not.toHaveBeenCalled();
    });

    it("disposes the diff editor and both of its models", () => {
      const wrapper = mountEditor({ diff: true, original: "old", value: "new" });
      const { editor } = created;
      const { original, modified } = editor.models;

      wrapper.destroy();

      expect(editor.dispose).toHaveBeenCalled();
      expect(original.dispose).toHaveBeenCalled();
      expect(modified.dispose).toHaveBeenCalled();
    });
  });
});
