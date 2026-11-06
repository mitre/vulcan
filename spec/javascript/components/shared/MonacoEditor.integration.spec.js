import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import MonacoEditor from "@/components/shared/MonacoEditor.vue";

/**
 * MonacoEditor requirements that only hold against the real editor.
 *
 * MonacoEditor.spec.js drives the component with fakes, so it can verify
 * which Monaco calls are made but not what Monaco does with them. The
 * failures below were invisible to it: Monaco's content-change listener fires
 * on programmatic edits too, and executeEdits puts those edits on the undo
 * stack. These specs load the real Monaco (jsdom is enough for the model and
 * undo machinery; see the window shims in spec/javascript/setup.js).
 *
 * 1. A DOCUMENT SWAP IS NOT AN EDIT. When the parent pushes a different
 *    `value` (the user selected another rule and the editor instance is
 *    reused), the component must not emit `change`. A `change` here is
 *    treated by InspecControlEditor as an edit of the newly selected rule and
 *    marks it dirty for autosave. This holds for editable and read-only
 *    editors alike.
 * 2. UNDO NEVER CROSSES A DOCUMENT SWAP. After the parent pushes a different
 *    `value`, undo must not bring back the previous document. Otherwise rule
 *    A's text reappears inside rule B's editor and is saved onto rule B.
 * 3. USER EDITS STILL WORK. Typing emits `change` with the new text, and undo
 *    of a user edit restores the previous text and emits it, so the parent's
 *    copy of the document follows the editor.
 */

const RULE_A = "control 'rule-a' do\nend\n";
const RULE_B = "control 'rule-b' do\nend\n";

let wrapper;
let host;

function mountEditor(options = {}) {
  host = document.createElement("div");
  document.body.appendChild(host);
  wrapper = mount(MonacoEditor, {
    localVue,
    attachTo: host,
    propsData: { value: RULE_A, language: "ruby", options: { automaticLayout: false, ...options } },
  });
  return wrapper;
}

function typeAtEnd(editor, text) {
  const model = editor.getModel();
  const end = model.getFullModelRange().getEndPosition();
  editor.executeEdits("user", [
    {
      range: {
        startLineNumber: end.lineNumber,
        startColumn: end.column,
        endLineNumber: end.lineNumber,
        endColumn: end.column,
      },
      text,
    },
  ]);
  editor.pushUndoStop();
}

afterEach(() => {
  if (wrapper) {
    wrapper.destroy();
    wrapper = null;
  }
  if (host) {
    host.remove();
    host = null;
  }
});

describe("MonacoEditor with the real Monaco", () => {
  describe("a document swap pushed by the parent", () => {
    it("is not emitted as a change from an editable editor", async () => {
      mountEditor();

      await wrapper.setProps({ value: RULE_B });

      expect(wrapper.vm.editor.getValue()).toBe(RULE_B);
      expect(wrapper.emitted("change")).toBeUndefined();
    });

    it("is not emitted as a change from a read-only editor", async () => {
      mountEditor({ readOnly: true });

      await wrapper.setProps({ value: RULE_B });

      expect(wrapper.vm.editor.getValue()).toBe(RULE_B);
      expect(wrapper.emitted("change")).toBeUndefined();
    });

    it("cannot be undone back to the previous document", async () => {
      mountEditor();
      await wrapper.setProps({ value: RULE_B });

      wrapper.vm.editor.trigger("spec", "undo", null);

      expect(wrapper.vm.editor.getValue()).toBe(RULE_B);
      expect(wrapper.emitted("change")).toBeUndefined();
    });
  });

  describe("a user edit", () => {
    it("is emitted as a change with the new text", () => {
      mountEditor();

      typeAtEnd(wrapper.vm.editor, "# reviewed\n");

      expect(wrapper.emitted("change")).toEqual([[`${RULE_A}# reviewed\n`]]);
    });

    it("can be undone, and the undo is emitted as a change", () => {
      mountEditor();
      typeAtEnd(wrapper.vm.editor, "# reviewed\n");

      wrapper.vm.editor.trigger("spec", "undo", null);

      expect(wrapper.vm.editor.getValue()).toBe(RULE_A);
      expect(wrapper.emitted("change").at(-1)).toEqual([RULE_A]);
    });

    it("survives a parent echo of the same text without losing undo", async () => {
      mountEditor();
      typeAtEnd(wrapper.vm.editor, "# reviewed\n");

      await wrapper.setProps({ value: `${RULE_A}# reviewed\n` });
      wrapper.vm.editor.trigger("spec", "undo", null);

      expect(wrapper.vm.editor.getValue()).toBe(RULE_A);
    });
  });
});
