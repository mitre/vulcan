import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ConfirmComponentReleaseMixin from "@/mixins/ConfirmComponentReleaseMixin.vue";
import { patchComponent } from "@/api/componentsApi";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: {} })),
    post: vi.fn(() => Promise.resolve({ data: {} })),
    put: vi.fn(() => Promise.resolve({ data: {} })),
    patch: vi.fn(() => Promise.resolve({ data: {} })),
    delete: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } },
  },
}));

vi.mock("@/api/componentsApi", () => ({
  patchComponent: vi.fn(() => Promise.resolve({ data: {} })),
}));

/**
 * ConfirmComponentReleaseMixin Tests
 *
 * REQUIREMENTS:
 *
 * confirmComponentRelease():
 * 1. If component.releasable is false, does nothing (early return)
 * 2. Shows a BootstrapVue confirmation dialog with title "Release Component"
 * 3. On confirm (value = true):
 *    - Sends PATCH /components/:id with { component: { released: true } }
 *    - On success: calls alertOrNotifyResponse(response) and emits 'projectUpdated'
 *    - On error: calls alertOrNotifyResponse(error)
 * 4. On cancel (value = false/null): does not send any request
 *
 * Dependencies:
 * - this.component.id and this.component.releasable
 * - this.$bvModal.msgBoxConfirm() -> Promise<boolean|null>
 * - this.$createElement() (Vue built-in, creates VNode for dialog body)
 * - this.alertOrNotifyResponse(response)
 * - this.$emit('projectUpdated')
 * - patchComponent()
 */

let wrapper;
let mockMsgBoxConfirm;
let mockAlertOrNotify;

function createWrapper({ releasable = true, componentId = 42 } = {}) {
  mockAlertOrNotify = vi.fn();

  const HostComponent = {
    mixins: [ConfirmComponentReleaseMixin],
    data() {
      return {
        component: { id: componentId, releasable },
      };
    },
    methods: {
      alertOrNotifyResponse: mockAlertOrNotify,
    },
    template: "<div></div>",
  };

  const w = mount(HostComponent, { localVue });

  // BootstrapVue installs $bvModal as a read-only getter on Vue.prototype.
  // vue-test-utils `mocks` option uses simple assignment which silently fails
  // against getter properties. Shadow the getter on this specific instance.
  Object.defineProperty(w.vm, "$bvModal", {
    value: { msgBoxConfirm: mockMsgBoxConfirm },
    configurable: true,
    writable: true,
  });

  return w;
}

describe("ConfirmComponentReleaseMixin", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Default: dialog resolves to false (cancel)
    mockMsgBoxConfirm = vi.fn().mockResolvedValue(false);
  });

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // ==========================================
  // EARLY RETURN — component not releasable
  // ==========================================
  describe("when component is not releasable", () => {
    it("does nothing and does not show confirmation dialog", () => {
      wrapper = createWrapper({ releasable: false });

      wrapper.vm.confirmComponentRelease();

      expect(mockMsgBoxConfirm).not.toHaveBeenCalled();
    });

    it("does not send any HTTP request", () => {
      wrapper = createWrapper({ releasable: false });

      wrapper.vm.confirmComponentRelease();

      expect(patchComponent).not.toHaveBeenCalled();
    });
  });

  // ==========================================
  // CONFIRMATION DIALOG
  // ==========================================
  describe("when component is releasable", () => {
    it('shows confirmation dialog with "Release Component" title', async () => {
      wrapper = createWrapper({ releasable: true });

      wrapper.vm.confirmComponentRelease();
      await vi.waitFor(() => expect(mockMsgBoxConfirm).toHaveBeenCalled());

      const callArgs = mockMsgBoxConfirm.mock.calls[0];
      // Second argument is the options object
      expect(callArgs[1].title).toBe("Release Component");
    });

    it('shows dialog with "Release Component" ok button and success variant', async () => {
      wrapper = createWrapper({ releasable: true });

      wrapper.vm.confirmComponentRelease();
      await vi.waitFor(() => expect(mockMsgBoxConfirm).toHaveBeenCalled());

      const options = mockMsgBoxConfirm.mock.calls[0][1];
      expect(options.okTitle).toBe("Release Component");
      expect(options.okVariant).toBe("success");
    });

    it("passes a VNode body to the dialog (not a plain string)", async () => {
      wrapper = createWrapper({ releasable: true });

      wrapper.vm.confirmComponentRelease();
      await vi.waitFor(() => expect(mockMsgBoxConfirm).toHaveBeenCalled());

      const body = mockMsgBoxConfirm.mock.calls[0][0];
      // $createElement returns a VNode object, not a string
      expect(body).toBeDefined();
      expect(typeof body).not.toBe("string");
    });
  });

  // ==========================================
  // USER CONFIRMS — successful PATCH
  // ==========================================
  describe("when user confirms release", () => {
    beforeEach(() => {
      mockMsgBoxConfirm = vi.fn().mockResolvedValue(true);
    });

    it("sends PATCH request with released: true", async () => {
      const mockResponse = { data: { success: true } };
      patchComponent.mockResolvedValue(mockResponse);

      wrapper = createWrapper({ releasable: true, componentId: 99 });
      wrapper.vm.confirmComponentRelease();

      await vi.waitFor(() => expect(patchComponent).toHaveBeenCalled());

      expect(patchComponent).toHaveBeenCalledWith(99, { released: true });
    });

    it("calls alertOrNotifyResponse with the response on success", async () => {
      const mockResponse = { data: { message: "Released!" } };
      patchComponent.mockResolvedValue(mockResponse);

      wrapper = createWrapper({ releasable: true });
      wrapper.vm.confirmComponentRelease();

      await vi.waitFor(() => expect(mockAlertOrNotify).toHaveBeenCalledWith(mockResponse));
    });

    it('emits "projectUpdated" event on successful release', async () => {
      patchComponent.mockResolvedValue({ data: {} });

      wrapper = createWrapper({ releasable: true });
      wrapper.vm.confirmComponentRelease();

      await vi.waitFor(() => expect(wrapper.emitted("projectUpdated")).toBeTruthy());
    });
  });

  // ==========================================
  // USER CONFIRMS — PATCH fails
  // ==========================================
  describe("when PATCH request fails", () => {
    beforeEach(() => {
      mockMsgBoxConfirm = vi.fn().mockResolvedValue(true);
    });

    it("calls alertOrNotifyResponse with the error", async () => {
      const mockError = { response: { status: 500, data: { error: "Server error" } } };
      patchComponent.mockRejectedValue(mockError);

      wrapper = createWrapper({ releasable: true });
      wrapper.vm.confirmComponentRelease();

      await vi.waitFor(() => expect(mockAlertOrNotify).toHaveBeenCalledWith(mockError));
    });

    it('does not emit "projectUpdated" on failure', async () => {
      patchComponent.mockRejectedValue(new Error("Network error"));

      wrapper = createWrapper({ releasable: true });
      wrapper.vm.confirmComponentRelease();

      // Wait for the async chain to settle
      await new Promise((resolve) => setTimeout(resolve, 50));

      expect(wrapper.emitted("projectUpdated")).toBeFalsy();
    });
  });

  // ==========================================
  // USER CANCELS
  // ==========================================
  describe("when user cancels the dialog", () => {
    it("does not send PATCH when user clicks Cancel (false)", async () => {
      mockMsgBoxConfirm = vi.fn().mockResolvedValue(false);

      wrapper = createWrapper({ releasable: true });
      wrapper.vm.confirmComponentRelease();

      // Wait for the promise chain to settle
      await new Promise((resolve) => setTimeout(resolve, 50));

      expect(patchComponent).not.toHaveBeenCalled();
    });

    it("does not send PATCH when user clicks away (null)", async () => {
      mockMsgBoxConfirm = vi.fn().mockResolvedValue(null);

      wrapper = createWrapper({ releasable: true });
      wrapper.vm.confirmComponentRelease();

      // Wait for the promise chain to settle
      await new Promise((resolve) => setTimeout(resolve, 50));

      expect(patchComponent).not.toHaveBeenCalled();
    });

    it('does not emit "projectUpdated" when cancelled', async () => {
      mockMsgBoxConfirm = vi.fn().mockResolvedValue(false);

      wrapper = createWrapper({ releasable: true });
      wrapper.vm.confirmComponentRelease();

      await new Promise((resolve) => setTimeout(resolve, 50));

      expect(wrapper.emitted("projectUpdated")).toBeFalsy();
    });
  });
});
