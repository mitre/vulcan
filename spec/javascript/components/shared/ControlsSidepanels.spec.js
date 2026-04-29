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
import axios from "axios";

vi.mock("axios");

function createWrapper(props = {}) {
  return shallowMount(ControlsSidepanels, {
    localVue,
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
      effectivePermissions: "admin",
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
      axios.get.mockResolvedValueOnce({ data: mockHistories });

      wrapper = createWrapper();
      wrapper.vm.$root.$emit("refresh:activity");

      // Wait for async axios call
      await wrapper.vm.$nextTick();
      await new Promise((resolve) => setTimeout(resolve, 10));

      expect(axios.get).toHaveBeenCalledWith("/components/8/histories");
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
      axios.get.mockResolvedValueOnce({ data: mockHistories });

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
