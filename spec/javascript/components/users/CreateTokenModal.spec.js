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

  // ── incorrect-password feedback ─────────────────────────────────────
  // REQUIREMENT: a failed current-password re-verification (422 problem
  // details) surfaces the problem's own title and detail as a danger toast —
  // the user must learn the password was wrong, not watch a silent failure.
  describe("incorrect-password feedback", () => {
    it("surfaces the problem detail when the password re-verification fails", async () => {
      const denied = Object.assign(new Error("Request failed with status code 422"), {
        response: {
          status: 422,
          data: {
            type: "/docs/api/errors#incorrect_password",
            title: "Incorrect password",
            status: 422,
            detail:
              "Creating or managing API tokens re-verifies your identity, " +
              "and the current password provided does not match.",
          },
        },
      });
      createToken.mockRejectedValueOnce(denied);
      wrapper = createWrapper();
      wrapper.vm.form.name = "ci-token";
      wrapper.vm.form.current_password = "wrong-password";

      const toastDetail = await captureVulcanToast(() => wrapper.vm.onSubmit(), wrapper);

      expect(toastDetail).toEqual({
        title: "Incorrect password",
        variant: "danger",
        message:
          "Creating or managing API tokens re-verifies your identity, " +
          "and the current password provided does not match.",
      });
      expect(wrapper.vm.creating).toBe(false);
    });
  });

  // The esbuild Vue pipeline does not decode HTML entities in template
  // attributes — a raw entity in a placeholder reaches the user as literal
  // text. The newline must be a real newline, bound from JavaScript.
  describe("IP allowlist placeholder", () => {
    it("renders a real newline between the CIDR examples, not a literal entity", () => {
      wrapper = createWrapper();
      const textarea = wrapper.find("textarea");
      expect(textarea.attributes("placeholder")).toBe("10.0.0.0/8\n192.168.1.0/24");
    });
  });
});
