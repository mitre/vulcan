import { describe, it, expect, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue, captureVulcanToast, flushPromises } from "@test/testHelper";
import UserTokens from "@/components/users/UserTokens.vue";
import { listTokens, revokeToken } from "@/api/tokensApi";

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
  listTokens: vi.fn(() => Promise.resolve({ data: { personal_access_tokens: [] } })),
  revokeToken: vi.fn(() => Promise.resolve({ data: {} })),
}));

/**
 * UserTokens Component Tests
 *
 * REQUIREMENTS:
 * - Loads the personal-access-token list on mount.
 * - The revoke catch hands the ERROR itself to alertOrNotifyResponse — a
 *   transport failure rejects with a bare Error (no .response), and the
 *   user must see an error toast, not silence.
 */
describe("UserTokens", () => {
  let wrapper;

  const createWrapper = () => shallowMount(UserTokens, { localVue });

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  it("loads tokens on mount", () => {
    wrapper = createWrapper();
    expect(listTokens).toHaveBeenCalled();
  });

  it("revoke surfaces an error toast when the request fails without an HTTP response", async () => {
    revokeToken.mockRejectedValueOnce(new Error("Request timed out"));
    wrapper = createWrapper();
    wrapper.vm.tokenToRevoke = { id: 5, name: "ci-token" };

    const toastDetail = await captureVulcanToast(() => wrapper.vm.doRevoke(), wrapper);

    expect(toastDetail).toEqual({
      title: "Error",
      variant: "danger",
      message: "Request timed out",
    });
    expect(wrapper.vm.revoking).toBe(false);
  });

  describe("copyToken", () => {
    afterEach(() => {
      vi.unstubAllGlobals();
      vi.restoreAllMocks();
      delete document.execCommand;
    });

    it("copies via navigator.clipboard when the API is available", async () => {
      const writeText = vi.fn(() => Promise.resolve());
      vi.stubGlobal("navigator", { clipboard: { writeText }, userAgent: navigator.userAgent });
      wrapper = createWrapper();
      await wrapper.setData({ newlyCreatedToken: "vulcan_secret" });

      wrapper.vm.copyToken();
      await flushPromises();

      expect(writeText).toHaveBeenCalledWith("vulcan_secret");
      expect(wrapper.vm.copied).toBe(true);
    });

    it("falls back to execCommand in a non-secure context (no clipboard API)", async () => {
      vi.stubGlobal("navigator", { userAgent: navigator.userAgent });
      const execCommand = vi.fn(() => true);
      document.execCommand = execCommand;
      wrapper = createWrapper();
      await wrapper.setData({ newlyCreatedToken: "vulcan_secret" });

      wrapper.vm.copyToken();

      expect(execCommand).toHaveBeenCalledWith("copy");
      expect(wrapper.vm.copied).toBe(true);
    });

    it("surfaces a toast when neither clipboard nor execCommand can copy", async () => {
      vi.stubGlobal("navigator", { userAgent: navigator.userAgent });
      document.execCommand = vi.fn(() => false);
      wrapper = createWrapper();
      await wrapper.setData({ newlyCreatedToken: "vulcan_secret" });

      const toast = await captureVulcanToast(() => wrapper.vm.copyToken(), wrapper);

      expect(toast).toMatchObject({ title: "Copy failed", variant: "warning" });
      expect(wrapper.vm.copied).toBe(false);
    });
  });
});
