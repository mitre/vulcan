import { describe, it, expect, afterEach, vi } from "vitest";
import { captureVulcanToast } from "@test/testHelper";
import { useClipboard } from "@/composables/useClipboard";

/**
 * Requirements for copying text to the user's clipboard:
 * - copyText resolves true only after the text was actually copied, so a
 *   caller never reports success for a copy that did not happen.
 * - In a secure context it uses navigator.clipboard.writeText.
 * - Vulcan can run over plain HTTP (RAILS_FORCE_SSL=false), where the
 *   clipboard API does not exist; it then copies with a hidden textarea and
 *   execCommand("copy"). It does the same when writeText rejects (no
 *   permission, document not focused).
 * - When no method copies, the user is told to copy manually (a warning
 *   toast) and copyText resolves false.
 * - The fallback leaves nothing behind in the document.
 */
describe("useClipboard", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
    delete document.execCommand;
  });

  const textareas = () => document.body.querySelectorAll("textarea").length;

  it("copies with navigator.clipboard in a secure context", async () => {
    const writeText = vi.fn(() => Promise.resolve());
    vi.stubGlobal("navigator", { clipboard: { writeText }, userAgent: navigator.userAgent });
    document.execCommand = vi.fn(() => true);
    const { copyText } = useClipboard();

    let result;
    const toast = await captureVulcanToast(async () => {
      result = await copyText("secret-value");
    });

    expect(result).toBe(true);
    expect(writeText).toHaveBeenCalledWith("secret-value");
    expect(document.execCommand).not.toHaveBeenCalled();
    expect(toast).toBeNull();
  });

  it("falls back to execCommand when writeText is refused", async () => {
    const writeText = vi.fn(() => Promise.reject(new DOMException("denied", "NotAllowedError")));
    vi.stubGlobal("navigator", { clipboard: { writeText }, userAgent: navigator.userAgent });
    document.execCommand = vi.fn(() => true);
    const { copyText } = useClipboard();

    const result = await copyText("secret-value");

    expect(result).toBe(true);
    expect(document.execCommand).toHaveBeenCalledWith("copy");
    expect(textareas()).toBe(0);
  });

  it("falls back to execCommand when the clipboard API is absent (plain HTTP)", async () => {
    vi.stubGlobal("navigator", { userAgent: navigator.userAgent });
    let copiedValue = null;
    document.execCommand = vi.fn(() => {
      copiedValue = document.activeElement?.value ?? document.querySelector("textarea")?.value;
      return true;
    });
    const { copyText } = useClipboard();

    const result = await copyText("secret-value");

    expect(result).toBe(true);
    expect(copiedValue).toBe("secret-value");
    expect(textareas()).toBe(0);
  });

  it("warns and resolves false when no method can copy", async () => {
    vi.stubGlobal("navigator", { userAgent: navigator.userAgent });
    document.execCommand = vi.fn(() => false);
    const { copyText } = useClipboard();

    let result;
    const toast = await captureVulcanToast(async () => {
      result = await copyText("secret-value");
    });

    expect(result).toBe(false);
    expect(toast).toMatchObject({ title: "Copy failed", variant: "warning" });
    expect(textareas()).toBe(0);
  });

  it("treats a throwing execCommand as a failed copy", async () => {
    vi.stubGlobal("navigator", { userAgent: navigator.userAgent });
    document.execCommand = vi.fn(() => {
      throw new Error("unsupported");
    });
    const { copyText } = useClipboard();

    let result;
    const toast = await captureVulcanToast(async () => {
      result = await copyText("secret-value");
    });

    expect(result).toBe(false);
    expect(toast).toMatchObject({ title: "Copy failed", variant: "warning" });
    expect(textareas()).toBe(0);
  });

  it("names what failed to copy when the caller says what it is", async () => {
    vi.stubGlobal("navigator", { userAgent: navigator.userAgent });
    document.execCommand = vi.fn(() => false);
    const { copyText } = useClipboard();

    const toast = await captureVulcanToast(() =>
      copyText("secret-value", { what: "the reset link" }),
    );

    expect(JSON.stringify(toast.message)).toContain("the reset link");
  });
});
