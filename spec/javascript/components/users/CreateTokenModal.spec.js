import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue, captureVulcanToast } from "@test/testHelper";
import CreateTokenModal from "@/components/users/CreateTokenModal.vue";
import { createToken } from "@/api/tokensApi";

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

vi.mock("@/api/tokensApi", () => ({
  createToken: vi.fn(() => Promise.resolve({ data: {} })),
}));

/**
 * CreateTokenModal Component Tests
 *
 * REQUIREMENTS:
 * - Renders the personal-access-token creation modal.
 * - Carries no mixins — toasts come from the useToast composable
 *   (FormMixin was verified dead; authenticityToken never referenced).
 */
describe("CreateTokenModal", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return mount(CreateTokenModal, {
      localVue,
      propsData: { visible: false, maxLifetimeDays: 365, ...props },
      stubs: { BModal: true },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  it("renders with default token form state", () => {
    wrapper = createWrapper();
    expect(wrapper.vm.form.name).toBe("");
  });

  // ── mixin contract ──────────────────────────────────────────────────
  // REQUIREMENT: no mixins remain; toasts come from the useToast composable.
  describe("mixin contract", () => {
    it("declares no mixins and gets alertOrNotifyResponse from useToast", () => {
      expect(CreateTokenModal.mixins).toBeUndefined();
      wrapper = createWrapper();
      expect(typeof wrapper.vm.alertOrNotifyResponse).toBe("function");
    });
  });

  // ── transport-failure degradation ───────────────────────────────────
  // REQUIREMENT: the submit catch hands the ERROR itself to
  // alertOrNotifyResponse — a transport failure rejects with a bare Error
  // (no .response), and the user must see an error toast, not silence.
  describe("transport-failure degradation", () => {
    it("surfaces an error toast when creation fails without an HTTP response", async () => {
      createToken.mockRejectedValueOnce(new Error("Request timed out"));
      wrapper = createWrapper();
      wrapper.vm.form.name = "ci-token";
      wrapper.vm.form.current_password = "current-password";

      const toastDetail = await captureVulcanToast(() => wrapper.vm.onSubmit(), wrapper);

      expect(toastDetail).toEqual({
        title: "Error",
        variant: "danger",
        message: "Request timed out",
      });
      expect(wrapper.vm.creating).toBe(false);
    });
  });
});
