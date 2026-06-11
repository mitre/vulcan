import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import NewProjectModal from "@/components/projects/NewProjectModal.vue";

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

vi.mock("@/api/projectsApi", () => ({
  createProject: vi.fn(() => Promise.resolve({ data: {} })),
}));

/**
 * NewProjectModal Component Tests
 *
 * REQUIREMENTS:
 * - Renders the new-project modal with an empty form.
 * - Carries only AlertMixin (FormMixin was verified dead —
 *   authenticityToken never referenced).
 */
describe("NewProjectModal", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return mount(NewProjectModal, {
      localVue,
      propsData: { visible: false, ...props },
      stubs: { BModal: true },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  it("renders with an empty project form", () => {
    wrapper = createWrapper();
    expect(wrapper.vm.form.name).toBe("");
  });

  // ── mixin contract ──────────────────────────────────────────────────
  // REQUIREMENT: only AlertMixin remains (until the toast migration).
  describe("mixin contract", () => {
    it("declares only AlertMixin", () => {
      expect(NewProjectModal.mixins).toHaveLength(1);
      expect(NewProjectModal.mixins[0].methods.alertOrNotifyResponse).toBeDefined();
    });
  });
});
