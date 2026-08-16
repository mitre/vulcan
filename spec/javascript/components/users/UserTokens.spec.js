import { describe, it, expect, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue, captureVulcanToast } from "@test/testHelper";
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
});
