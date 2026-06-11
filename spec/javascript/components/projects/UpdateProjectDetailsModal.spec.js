import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import UpdateProjectDetailsModal from "@/components/projects/UpdateProjectDetailsModal.vue";

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
  updateProject: vi.fn(() => Promise.resolve({ data: {} })),
}));

/**
 * UpdateProjectDetailsModal Component Tests
 *
 * REQUIREMENTS:
 * - Seeds its form from the given project.
 * - Renders the opener visibly DISABLED with a tooltip (never hidden)
 *   when the user lacks permission — the disable-not-hide UX rule.
 * - Carries only AlertMixin (FormMixin was verified dead —
 *   authenticityToken never referenced).
 */
describe("UpdateProjectDetailsModal", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return mount(UpdateProjectDetailsModal, {
      localVue,
      propsData: {
        project: { id: 4, name: "Container Platform", description: "A test project" },
        ...props,
      },
      stubs: { BModal: true },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  it("seeds the form from the project", () => {
    wrapper = createWrapper();
    expect(wrapper.vm.name).toBe("Container Platform");
    expect(wrapper.vm.description).toBe("A test project");
  });

  it("renders the opener disabled (not hidden) when disabled", () => {
    wrapper = createWrapper({ disabled: true, disabledTitle: "Admins only" });
    const opener = wrapper.find("button");
    expect(opener.exists()).toBe(true);
    expect(opener.attributes("disabled")).toBeDefined();
  });

  // ── mixin contract ──────────────────────────────────────────────────
  // REQUIREMENT: only AlertMixin remains (until the toast migration).
  describe("mixin contract", () => {
    it("declares only AlertMixin", () => {
      expect(UpdateProjectDetailsModal.mixins).toHaveLength(1);
      expect(UpdateProjectDetailsModal.mixins[0].methods.alertOrNotifyResponse).toBeDefined();
    });
  });
});
