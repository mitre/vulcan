import { describe, it, expect, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue, captureVulcanToast } from "@test/testHelper";
import InspecControlEditor from "@/components/rules/InspecControlEditor.vue";

/**
 * Requirements for the editor's copy button:
 * - "Copied to clipboard" is shown only after the control text was copied.
 * - When it could not be copied (no clipboard API over plain HTTP, the API
 *   refused, and the textarea fallback failed), the user is told to copy it
 *   manually and is not told it was copied.
 */
describe("InspecControlEditor copy button", () => {
  let wrapper;

  const mountEditor = () => {
    const bvToast = { toast: vi.fn() };
    wrapper = shallowMount(InspecControlEditor, {
      localVue,
      propsData: {
        rule: { inspec_control_body: "describe file('/etc') do end" },
        field: "inspec_control_body",
      },
      mocks: { $bvToast: bvToast },
    });
    return bvToast;
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
    delete document.execCommand;
  });

  it("confirms the copy once the control text is on the clipboard", async () => {
    const writeText = vi.fn(() => Promise.resolve());
    vi.stubGlobal("navigator", { clipboard: { writeText }, userAgent: navigator.userAgent });
    mountEditor();

    const toast = await captureVulcanToast(() => wrapper.vm.copyText(), wrapper);

    expect(writeText).toHaveBeenCalledWith("describe file('/etc') do end");
    expect(toast).toMatchObject({
      title: "Copy",
      variant: "success",
      message: "Copied to clipboard",
    });
  });

  it("warns, and does not claim success, when the text could not be copied", async () => {
    const writeText = vi.fn(() => Promise.reject(new DOMException("denied", "NotAllowedError")));
    vi.stubGlobal("navigator", { clipboard: { writeText }, userAgent: navigator.userAgent });
    document.execCommand = vi.fn(() => false);
    const bvToast = mountEditor();
    const seen = [];
    const listener = (event) => seen.push(event.detail);
    document.addEventListener("vulcan:toast", listener);

    try {
      await captureVulcanToast(() => wrapper.vm.copyText(), wrapper);
    } finally {
      document.removeEventListener("vulcan:toast", listener);
    }

    expect(seen).toEqual([expect.objectContaining({ title: "Copy failed", variant: "warning" })]);
    expect(bvToast.toast).not.toHaveBeenCalled();
  });
});
