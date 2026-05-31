import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import BulkTriageBar from "@/components/triage/BulkTriageBar.vue";

const factory = (props = {}) =>
  mount(BulkTriageBar, { localVue, propsData: { count: 3, ...props } });

describe("BulkTriageBar", () => {
  it("shows the selected count", () => {
    const wrapper = factory({ count: 5 });
    expect(wrapper.find('[data-testid="bulk-count"]').text()).toContain("5 selected");
  });

  it("disables Apply until a triage status is chosen", async () => {
    const wrapper = factory();
    expect(wrapper.find('[data-testid="bulk-apply"]').attributes("disabled")).toBeDefined();

    await wrapper.setData({ triageStatus: "concur" });
    expect(wrapper.find('[data-testid="bulk-apply"]').attributes("disabled")).toBeUndefined();
  });

  it("emits apply with the status and response payload", async () => {
    const wrapper = factory({ count: 2 });
    await wrapper.setData({
      triageStatus: "concur_with_comment",
      response: "  Adopting with changes  ",
    });

    await wrapper.find('[data-testid="bulk-apply"]').trigger("click");

    expect(wrapper.emitted("apply")).toBeTruthy();
    expect(wrapper.emitted("apply")[0][0]).toEqual({
      triage_status: "concur_with_comment",
      response_comment: "Adopting with changes",
    });
  });

  it("sends a null response_comment when none is typed", async () => {
    const wrapper = factory();
    await wrapper.setData({ triageStatus: "informational" });
    await wrapper.find('[data-testid="bulk-apply"]').trigger("click");

    expect(wrapper.emitted("apply")[0][0]).toEqual({
      triage_status: "informational",
      response_comment: null,
    });
  });

  it("requires a response when status is non_concur (Declined)", async () => {
    const wrapper = factory();
    await wrapper.setData({ triageStatus: "non_concur" });
    expect(wrapper.find('[data-testid="bulk-apply"]').attributes("disabled")).toBeDefined();

    await wrapper.setData({ response: "Out of scope for this baseline." });
    expect(wrapper.find('[data-testid="bulk-apply"]').attributes("disabled")).toBeUndefined();
  });

  it("emits clear and resets local state", async () => {
    const wrapper = factory();
    await wrapper.setData({ triageStatus: "concur", response: "x" });

    await wrapper.find('[data-testid="bulk-clear"]').trigger("click");

    expect(wrapper.emitted("clear")).toBeTruthy();
    expect(wrapper.vm.triageStatus).toBeNull();
    expect(wrapper.vm.response).toBe("");
  });

  describe("merge button", () => {
    it("hides Merge when the user is not an admin", () => {
      const wrapper = factory({ count: 3 });
      expect(wrapper.find('[data-testid="bulk-merge"]').exists()).toBe(false);
    });

    it("shows Merge for admins and emits merge on click", async () => {
      const wrapper = factory({ count: 3, canMerge: true });
      const btn = wrapper.find('[data-testid="bulk-merge"]');
      expect(btn.exists()).toBe(true);
      expect(btn.attributes("disabled")).toBeUndefined();
      await btn.trigger("click");
      expect(wrapper.emitted("merge")).toBeTruthy();
    });

    it("disables Merge when fewer than 2 comments are selected", () => {
      const wrapper = factory({ count: 1, canMerge: true });
      expect(wrapper.find('[data-testid="bulk-merge"]').attributes("disabled")).toBeDefined();
    });
  });
});
