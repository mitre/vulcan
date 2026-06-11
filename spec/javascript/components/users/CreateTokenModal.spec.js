import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CreateTokenModal from "@/components/users/CreateTokenModal.vue";

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
 * - Carries only AlertMixin (FormMixin was verified dead —
 *   authenticityToken never referenced).
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
  // REQUIREMENT: only AlertMixin remains (until the toast migration).
  describe("mixin contract", () => {
    it("declares only AlertMixin", () => {
      expect(CreateTokenModal.mixins).toHaveLength(1);
      expect(CreateTokenModal.mixins[0].methods.alertOrNotifyResponse).toBeDefined();
    });
  });
});
