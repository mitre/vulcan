/**
 * ControlsSidepanels — B5 Reactivity Tests
 *
 * REQUIREMENT: When a rule is saved or its status changes, the Activity and
 * Reviews sidepanels must refresh to show the latest data. The frontend emits
 * "refresh:activity" on $root after rule fetch success. ControlsSidepanels
 * listens for this event and re-fetches component histories.
 */
import { describe, it, expect, afterEach, vi } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import ControlsSidepanels from "@/components/shared/ControlsSidepanels.vue";
import { getHistories } from "@/api/componentsApi";

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
  getHistories: vi.fn(() => Promise.resolve({ data: [] })),
}));

// Permissions come from the page-root provide (usePermissions inject),
// matching production: ProjectComponent/Rules provide "effectivePermissions".
function createWrapper(props = {}, permissions = "admin") {
  return shallowMount(ControlsSidepanels, {
    localVue,
    provide: { effectivePermissions: permissions },
    propsData: {
      component: {
        id: 8,
        name: "Test Component",
        version: 1,
        release: 1,
        title: "Test STIG",
        description: "Test description",
        histories: [],
        reviews: [],
        memberships: [],
        metadata: {},
        additional_questions: [],
      },
      ...props,
    },
  });
}

describe("ControlsSidepanels", () => {
  let wrapper;

  afterEach(() => {
    if (wrapper) wrapper.destroy();
    vi.restoreAllMocks();
  });

  // REQUIREMENT: permissions arrive via the root provide (usePermissions
  // inject), not a prop. Role gates: admin panels need "admin", authoring
  // panels need "author" or above (canEdit).
  describe("permissions via inject (usePermissions)", () => {
    it("canAdmin is true when admin permissions are provided", () => {
      wrapper = createWrapper({}, "admin");
      expect(wrapper.vm.canAdmin).toBe(true);
    });

    it("canAdmin is false for author permissions", () => {
      wrapper = createWrapper({}, "author");
      expect(wrapper.vm.canAdmin).toBe(false);
    });

    it("canEdit is true for author permissions", () => {
      wrapper = createWrapper({}, "author");
      expect(wrapper.vm.canEdit).toBe(true);
    });

    it("canEdit is false for viewer permissions", () => {
      wrapper = createWrapper({}, "viewer");
      expect(wrapper.vm.canEdit).toBe(false);
    });

    it("exposes the injected effectivePermissions for child prop pass-through", () => {
      wrapper = createWrapper({}, "reviewer");
      expect(wrapper.vm.effectivePermissions).toBe("reviewer");
    });
  });

  describe("B5: refresh:activity reactivity", () => {
    it("listens for refresh:activity event on $root", () => {
      wrapper = createWrapper();
      // The component should have registered the listener
      expect(wrapper.vm.$root._events["refresh:activity"]).toBeTruthy();
    });

    it("fetches component histories when refresh:activity is emitted", async () => {
      const mockHistories = [
        {
          id: 1,
          action: "update",
          name: "Test User",
          audited_changes: [{ field: "title", prev_value: "Old", new_value: "New" }],
          created_at: "2026-03-05T00:00:00Z",
        },
      ];
      getHistories.mockResolvedValueOnce({ data: mockHistories });

      wrapper = createWrapper();
      wrapper.vm.$root.$emit("refresh:activity");

      // Wait for async axios call
      await wrapper.vm.$nextTick();
      await new Promise((resolve) => setTimeout(resolve, 10));

      expect(getHistories).toHaveBeenCalledWith(8);
    });

    it("updates local histories data after fetch", async () => {
      const mockHistories = [
        {
          id: 99,
          action: "update",
          name: "Test User",
          audited_changes: [],
          created_at: "2026-03-05T00:00:00Z",
        },
      ];
      getHistories.mockResolvedValueOnce({ data: mockHistories });

      wrapper = createWrapper();
      // Initial histories empty
      expect(wrapper.vm.localHistories).toEqual([]);

      wrapper.vm.$root.$emit("refresh:activity");
      await wrapper.vm.$nextTick();
      await new Promise((resolve) => setTimeout(resolve, 10));

      expect(wrapper.vm.localHistories).toEqual(mockHistories);
    });

    it("cleans up listener on destroy", () => {
      wrapper = createWrapper();
      const root = wrapper.vm.$root;
      expect(root._events["refresh:activity"].length).toBe(1);

      wrapper.destroy();
      // After destroy, listener should be removed (Vue 2 may leave empty array)
      const listeners = root._events["refresh:activity"];
      expect(!listeners || listeners.length === 0).toBe(true);
      wrapper = null; // prevent double destroy in afterEach
    });
  });
});
