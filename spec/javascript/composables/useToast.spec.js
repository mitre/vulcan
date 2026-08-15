import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { useToast, TOAST_EVENT } from "@/composables/useToast";

/**
 * useToast Tests
 *
 * REQUIREMENTS (ported from the AlertMixin behavior contract):
 *
 * The composable is the toast PRODUCER. Because each esbuild pack bundles its
 * own module graph (iife, no splitting), producers and the Toaster renderer
 * never share module state across packs — so the transport is a DOM
 * CustomEvent (TOAST_EVENT) with a plain-data detail payload. Toaster.vue
 * (toaster pack, on every page) is the single renderer/$bvToast caller.
 *
 * showToast(message, options):
 *  - dispatches TOAST_EVENT with {title, variant, message} detail
 *  - defaults: title "Success", variant "success"
 * showSuccess / showError / showWarning: variant + default-title shorthands
 *
 * alertOrNotifyResponse(response):
 *  - Success path (response.data.toast object): {title, variant, message} from the toast
 *  - Error path (response.response.data.toast object): same, from legacy axios error shape
 *  - Canonical message arrays pass through as arrays (Toaster renders paragraphs)
 *  - Structured permission denied (403 + RFC 9457 problem `type` ending in
 *      #permission_denied): title "Permission denied", variant "danger",
 *      message from the problem `detail` + admins list, autoHideDelay 8000;
 *      other 403 problem types fall through to their toast extension
 *  - Fallback: response.message → generic Error toast
 *  - No toast and no message → dispatches nothing
 */

let detail;
let handler;

beforeEach(() => {
  detail = null;
  handler = vi.fn((event) => {
    detail = event.detail;
  });
  document.addEventListener(TOAST_EVENT, handler);
});

afterEach(() => {
  document.removeEventListener(TOAST_EVENT, handler);
});

describe("useToast#showToast", () => {
  it("dispatches a toast event with title, variant, and message", () => {
    const { showToast } = useToast();
    showToast("Saved.", { title: "Done", variant: "info" });
    expect(handler).toHaveBeenCalledTimes(1);
    expect(detail).toEqual({ title: "Done", variant: "info", message: "Saved." });
  });

  it("defaults title to 'Success' and variant to 'success'", () => {
    const { showToast } = useToast();
    showToast("Saved.");
    expect(detail).toEqual({ title: "Success", variant: "success", message: "Saved." });
  });

  it("passes autoHideDelay through when provided", () => {
    const { showToast } = useToast();
    showToast("Slow down.", { title: "Hold on", variant: "warning", autoHideDelay: 8000 });
    expect(detail).toEqual({
      title: "Hold on",
      variant: "warning",
      message: "Slow down.",
      autoHideDelay: 8000,
    });
  });
});

describe("useToast variant shorthands", () => {
  it("showSuccess dispatches a success toast titled 'Success'", () => {
    const { showSuccess } = useToast();
    showSuccess("It worked.");
    expect(detail).toEqual({ title: "Success", variant: "success", message: "It worked." });
  });

  it("showError dispatches a danger toast titled 'Error'", () => {
    const { showError } = useToast();
    showError("It broke.");
    expect(detail).toEqual({ title: "Error", variant: "danger", message: "It broke." });
  });

  it("showWarning dispatches a warning toast titled 'Warning'", () => {
    const { showWarning } = useToast();
    showWarning("Careful.");
    expect(detail).toEqual({ title: "Warning", variant: "warning", message: "Careful." });
  });
});

describe("useToast#alertOrNotifyResponse", () => {
  describe("success path (response.data.toast)", () => {
    it("dispatches a toast from a canonical object with title/variant/message", () => {
      const { alertOrNotifyResponse } = useToast();
      alertOrNotifyResponse({
        data: { toast: { title: "Done", variant: "success", message: "Updated." } },
      });
      expect(detail).toEqual({ title: "Done", variant: "success", message: "Updated." });
    });

    it("defaults missing title/variant to 'Success'/'success'", () => {
      const { alertOrNotifyResponse } = useToast();
      alertOrNotifyResponse({ data: { toast: { message: "Updated." } } });
      expect(detail).toEqual({ title: "Success", variant: "success", message: "Updated." });
    });

    it("passes canonical message arrays through as arrays", () => {
      const { alertOrNotifyResponse } = useToast();
      alertOrNotifyResponse({
        data: { toast: { title: "Notice", variant: "success", message: ["One.", "Two."] } },
      });
      expect(detail).toEqual({ title: "Notice", variant: "success", message: ["One.", "Two."] });
    });
  });

  describe("error path (response.response.data.toast)", () => {
    it("dispatches a danger toast from a non-structured 4xx response", () => {
      const { alertOrNotifyResponse } = useToast();
      alertOrNotifyResponse({
        response: {
          status: 422,
          data: { toast: { title: "Could not save.", message: "Bad input", variant: "danger" } },
        },
      });
      expect(detail).toEqual({ title: "Could not save.", variant: "danger", message: "Bad input" });
    });
  });

  describe("degenerate input (a caller bug or transport error must degrade, not throw)", () => {
    it("does not throw and dispatches nothing when called with undefined", () => {
      const { alertOrNotifyResponse } = useToast();
      expect(() => alertOrNotifyResponse(undefined)).not.toThrow();
      expect(detail).toBeNull();
    });

    it("shows a generic error toast from a bare Error (timeout/network — no .response)", () => {
      const { alertOrNotifyResponse } = useToast();
      alertOrNotifyResponse(new Error("Request timed out"));
      expect(detail).toEqual({ title: "Error", variant: "danger", message: "Request timed out" });
    });
  });

  describe("structured permission denied", () => {
    // RFC 9457 problem body (application/problem+json): `type` is the
    // stable machine key, `detail` the human why, `admins` the who-to-ask
    // extension. The legacy toast extension rides along for older readers.
    const permissionDeniedResponse = {
      response: {
        status: 403,
        data: {
          type: "/docs/api/errors#permission_denied",
          title: "Permission denied",
          status: 403,
          detail: "You do not have permission to perform that action.",
          admins: [
            { name: "Alice Admin", email: "alice@example.org" },
            { name: "Bob Boss", email: "bob@example.org" },
          ],
          toast: {
            title: "Not Authorized.",
            message: "You do not have permission to perform that action.",
            variant: "danger",
          },
        },
      },
    };

    it("dispatches a danger toast titled 'Permission denied' with detail, admins, and 8s delay", () => {
      const { alertOrNotifyResponse } = useToast();
      alertOrNotifyResponse(permissionDeniedResponse);
      expect(detail).toEqual({
        title: "Permission denied",
        variant: "danger",
        message: "You do not have permission to perform that action.",
        admins: [
          { name: "Alice Admin", email: "alice@example.org" },
          { name: "Bob Boss", email: "bob@example.org" },
        ],
        autoHideDelay: 8000,
      });
    });

    it("normalizes a missing admins array to empty", () => {
      const { alertOrNotifyResponse } = useToast();
      alertOrNotifyResponse({
        response: {
          status: 403,
          data: { type: "/docs/api/errors#permission_denied", detail: "Forbidden" },
        },
      });
      expect(detail).toEqual({
        title: "Permission denied",
        variant: "danger",
        message: "Forbidden",
        admins: [],
        autoHideDelay: 8000,
      });
    });

    it("ignores non-permission problem types on 403 (falls through to the toast extension)", () => {
      const { alertOrNotifyResponse } = useToast();
      alertOrNotifyResponse({
        response: {
          status: 403,
          data: {
            type: "/docs/api/errors#insufficient_token_scope",
            detail: "This request requires the write scope, and the token does not grant it.",
            toast: { title: "Not Authorized.", message: "No scope", variant: "danger" },
          },
        },
      });
      expect(detail).toEqual({ title: "Not Authorized.", variant: "danger", message: "No scope" });
    });
  });

  describe("fallbacks", () => {
    it("dispatches a generic Error toast from response.message", () => {
      const { alertOrNotifyResponse } = useToast();
      alertOrNotifyResponse({ message: "Network Error" });
      expect(detail).toEqual({ title: "Error", variant: "danger", message: "Network Error" });
    });

    it("dispatches nothing when there is no toast and no message", () => {
      const { alertOrNotifyResponse } = useToast();
      alertOrNotifyResponse({ data: {} });
      expect(handler).not.toHaveBeenCalled();
    });
  });
});
