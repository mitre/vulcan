import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import UserPasswordPage from "@/components/users/UserPasswordPage.vue";

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

/**
 * UserPasswordPage Component Tests
 *
 * REQUIREMENTS:
 * - Renders the change-password page for the given user.
 * - Carries only AlertMixin (FormMixin was verified dead —
 *   authenticityToken never referenced).
 */
describe("UserPasswordPage", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return mount(UserPasswordPage, {
      localVue,
      propsData: {
        user: { id: 7, name: "Demo Admin", email: "admin@example.com" },
        ...props,
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  it("renders the password form fields", () => {
    wrapper = createWrapper();
    expect(wrapper.find("input[type='password']").exists()).toBe(true);
  });

  // ── mixin contract ──────────────────────────────────────────────────
  // REQUIREMENT: only AlertMixin remains (until the toast migration).
  describe("mixin contract", () => {
    it("declares only AlertMixin", () => {
      expect(UserPasswordPage.mixins).toHaveLength(1);
      expect(UserPasswordPage.mixins[0].methods.alertOrNotifyResponse).toBeDefined();
    });
  });
});
