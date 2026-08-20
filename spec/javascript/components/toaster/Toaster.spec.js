import { describe, it, expect, vi, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import Toaster from "@/components/toaster/Toaster.vue";
import { TOAST_EVENT } from "@/composables/useToast";

/**
 * Toaster Tests
 *
 * REQUIREMENTS:
 *
 * Toaster is the single $bvToast renderer for the app. Producers in other
 * packs dispatch TOAST_EVENT CustomEvents (see useToast.js for why the
 * transport is a DOM event); Toaster listens on document and renders:
 *  - string message → passed through as the toast body
 *  - array message → a <div> of <p> paragraphs (AlertMixin#arrayToMessage parity)
 *  - admins present → permission-denied body: message paragraph,
 *    "Project administrators:" heading, and "Name <email>" list items
 *    (AlertMixin#permissionDeniedBody parity)
 *  - options: title + variant from the payload, solid always true,
 *    autoHideDelay passed through when present
 *  - Rails flash props (notice/alert) render success/danger toasts on mount
 *  - the document listener is removed on destroy (no leak across Turbolinks visits)
 */

let wrapper;

function createWrapper(propsData = {}) {
  const w = mount(Toaster, { localVue, propsData });
  return w;
}

function stubBvToast(w) {
  const mockToast = vi.fn();
  Object.defineProperty(w.vm, "$bvToast", {
    value: { toast: mockToast },
    configurable: true,
    writable: true,
  });
  return mockToast;
}

function emitToast(detail) {
  document.dispatchEvent(new CustomEvent(TOAST_EVENT, { detail }));
}

// Walk a VNode tree (or string) collecting its text content.
function collectText(node) {
  if (!node) return "";
  if (typeof node === "string") return node;
  if (Array.isArray(node)) return node.map(collectText).join(" ");
  if (node.text) return node.text;
  if (node.children) return collectText(node.children);
  return "";
}

afterEach(() => {
  if (wrapper) wrapper.destroy();
  wrapper = null;
});

describe("Toaster toast-event rendering", () => {
  it("renders a string-message toast with title, variant, and solid", () => {
    wrapper = createWrapper();
    const mockToast = stubBvToast(wrapper);
    emitToast({ title: "Done", variant: "info", message: "Saved." });
    expect(mockToast).toHaveBeenCalledWith("Saved.", {
      title: "Done",
      variant: "info",
      solid: true,
    });
  });

  it("renders an array message as a div of paragraphs", () => {
    wrapper = createWrapper();
    const mockToast = stubBvToast(wrapper);
    emitToast({ title: "Notice", variant: "success", message: ["First line.", "Second line."] });
    const [body, options] = mockToast.mock.calls[0];
    expect(options).toEqual({ title: "Notice", variant: "success", solid: true });
    expect(body.tag).toBe("div");
    expect(body.children).toHaveLength(2);
    expect(body.children.every((child) => child.tag === "p")).toBe(true);
    expect(collectText(body)).toMatch(/First line\./);
    expect(collectText(body)).toMatch(/Second line\./);
  });

  it("passes autoHideDelay through when present", () => {
    wrapper = createWrapper();
    const mockToast = stubBvToast(wrapper);
    emitToast({ title: "Hold on", variant: "warning", message: "Slow down.", autoHideDelay: 8000 });
    expect(mockToast).toHaveBeenCalledWith("Slow down.", {
      title: "Hold on",
      variant: "warning",
      solid: true,
      autoHideDelay: 8000,
    });
  });

  it("renders a permission-denied body with message and admin contacts", () => {
    wrapper = createWrapper();
    const mockToast = stubBvToast(wrapper);
    emitToast({
      title: "Permission denied",
      variant: "danger",
      message: "You do not have permission to perform that action.",
      admins: [
        { name: "Alice Admin", email: "alice@example.org" },
        { name: "Bob Boss", email: "bob@example.org" },
      ],
      autoHideDelay: 8000,
    });
    const [body, options] = mockToast.mock.calls[0];
    expect(options).toEqual({
      title: "Permission denied",
      variant: "danger",
      solid: true,
      autoHideDelay: 8000,
    });
    const text = collectText(body);
    expect(text).toMatch(/You do not have permission/);
    expect(text).toMatch(/Project administrators:/);
    expect(text).toMatch(/Alice Admin <alice@example\.org>/);
    expect(text).toMatch(/Bob Boss <bob@example\.org>/);
  });

  it("renders a permission-denied body without the admins section when the list is empty", () => {
    wrapper = createWrapper();
    const mockToast = stubBvToast(wrapper);
    emitToast({
      title: "Permission denied",
      variant: "danger",
      message: "Forbidden",
      admins: [],
      autoHideDelay: 8000,
    });
    const text = collectText(mockToast.mock.calls[0][0]);
    expect(text).toMatch(/Forbidden/);
    expect(text).not.toMatch(/Project administrators:/);
  });

  it("stops listening once destroyed", () => {
    wrapper = createWrapper();
    const mockToast = stubBvToast(wrapper);
    wrapper.destroy();
    emitToast({ title: "Late", variant: "info", message: "Too late." });
    expect(mockToast).not.toHaveBeenCalled();
    wrapper = null;
  });
});

describe("Toaster Rails flash props", () => {
  // Flash toasts fire in mounted(), so the $bvToast stub must be installed
  // from a created() hook — after mount() returns it would be too late.
  it("renders a success Notice toast from the notice prop", () => {
    const mockToast = vi.fn();
    const w = mount(Toaster, {
      localVue,
      propsData: { notice: "Signed in." },
      created() {
        Object.defineProperty(this, "$bvToast", {
          value: { toast: mockToast },
          configurable: true,
          writable: true,
        });
      },
    });
    const [body, options] = mockToast.mock.calls[0];
    expect(options).toEqual({ title: "Notice", variant: "success", solid: true });
    expect(collectText(body)).toMatch(/Signed in\./);
    w.destroy();
  });

  it("renders a danger Error toast from the alert prop", () => {
    const mockToast = vi.fn();
    const w = mount(Toaster, {
      localVue,
      propsData: { alert: "Access denied." },
      created() {
        Object.defineProperty(this, "$bvToast", {
          value: { toast: mockToast },
          configurable: true,
          writable: true,
        });
      },
    });
    const [body, options] = mockToast.mock.calls[0];
    expect(options).toEqual({ title: "Error", variant: "danger", solid: true });
    expect(collectText(body)).toMatch(/Access denied\./);
    w.destroy();
  });
});
