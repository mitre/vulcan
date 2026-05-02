import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import AlertMixin from "@/mixins/AlertMixin.vue";

/**
 * AlertMixin Tests
 *
 * REQUIREMENTS:
 *
 * alertOrNotifyResponse(response):
 *  - Success path (response.data.toast as string): renders a success toast with that string
 *  - Success path (response.data.toast as object): renders a toast with title/variant/message
 *  - Error path (response.response.data.toast as object): renders a toast (legacy axios error)
 *  - Plan B (B6) — structured permission denied:
 *      response.response.status === 403 && response.response.data.error === 'permission_denied'
 *      Render a danger toast with title "Permission denied", body containing the message and
 *      the admin contacts ("name <email>" lines).
 *  - Fallback: response.message → renders a generic Error toast
 */

let wrapper;
let mockToast;

function createWrapper() {
  mockToast = vi.fn();
  const HostComponent = {
    mixins: [AlertMixin],
    template: "<div></div>",
  };
  const w = mount(HostComponent, { localVue });
  Object.defineProperty(w.vm, "$bvToast", {
    value: { toast: mockToast },
    configurable: true,
    writable: true,
  });
  return w;
}

describe("AlertMixin#alertOrNotifyResponse", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("legacy success paths", () => {
    // PR-717 review remediation .19d — string-toast handling removed.
    // Every controller now returns canonical {title, message, variant}
    // object toasts. The pre-fix `typeof toast === 'string'` branch in
    // AlertMixin had no remaining producers; the test for it was
    // removed alongside the branch. If a backend still returns a string
    // toast, the request falls through to the error path so the dev
    // sees the regression immediately.

    it("renders a toast when data.toast is an object with title/variant/message", () => {
      wrapper = createWrapper();
      wrapper.vm.alertOrNotifyResponse({
        data: { toast: { title: "Done", variant: "success", message: "Updated." } },
      });
      expect(mockToast).toHaveBeenCalledWith(
        "Updated.",
        expect.objectContaining({ title: "Done", variant: "success" }),
      );
    });
  });

  describe("legacy error path (response.data.toast)", () => {
    it("renders a danger toast from a non-structured 4xx response", () => {
      wrapper = createWrapper();
      wrapper.vm.alertOrNotifyResponse({
        response: {
          status: 422,
          data: { toast: { title: "Could not save.", message: "Bad input", variant: "danger" } },
        },
      });
      expect(mockToast).toHaveBeenCalledWith(
        "Bad input",
        expect.objectContaining({ title: "Could not save.", variant: "danger" }),
      );
    });
  });

  describe("Plan B (B6): structured permission denied", () => {
    const permissionDeniedResponse = {
      response: {
        status: 403,
        data: {
          error: "permission_denied",
          message: "You do not have permission to perform that action.",
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

    it("renders a danger toast with title 'Permission denied'", () => {
      wrapper = createWrapper();
      wrapper.vm.alertOrNotifyResponse(permissionDeniedResponse);
      const args = mockToast.mock.calls[0];
      expect(args[1]).toEqual(
        expect.objectContaining({ title: "Permission denied", variant: "danger" }),
      );
    });

    it("includes the message and admin name+email in the toast body", () => {
      wrapper = createWrapper();
      wrapper.vm.alertOrNotifyResponse(permissionDeniedResponse);
      // Body is rendered via $createElement, so we serialize and assert text content
      const body = mockToast.mock.calls[0][0];
      // body may be a VNode or a string — match on its rendered text
      const rendered = wrapper.vm.$createElement("div", [body]);
      // Helper: walk VNode tree collecting text
      const collectText = (node) => {
        if (!node) return "";
        if (typeof node === "string") return node;
        if (Array.isArray(node)) return node.map(collectText).join(" ");
        if (node.text) return node.text;
        if (node.children) return collectText(node.children);
        return "";
      };
      const text = collectText(rendered);
      expect(text).toMatch(/You do not have permission/i);
      expect(text).toMatch(/Alice Admin/);
      expect(text).toMatch(/alice@example\.org/);
      expect(text).toMatch(/Bob Boss/);
      expect(text).toMatch(/bob@example\.org/);
    });

    it("handles a structured response with no admins gracefully", () => {
      wrapper = createWrapper();
      wrapper.vm.alertOrNotifyResponse({
        response: {
          status: 403,
          data: {
            error: "permission_denied",
            message: "Forbidden",
            admins: [],
            toast: { title: "Not Authorized.", message: "Forbidden", variant: "danger" },
          },
        },
      });
      const args = mockToast.mock.calls[0];
      expect(args[1]).toEqual(
        expect.objectContaining({ title: "Permission denied", variant: "danger" }),
      );
    });
  });
});
