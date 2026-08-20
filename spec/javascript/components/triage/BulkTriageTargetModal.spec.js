import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import BulkTriageTargetModal from "@/components/triage/BulkTriageTargetModal.vue";

// REQUIREMENT: bulk duplicate/addressed_by carry ONE shared target applied to
// every selected comment. The bar's Apply opens this modal (the Merge-modal
// sibling shape) hosting the existing pickers; the picker excludes the whole
// bulk selection (duplicate) or the selection's own rules (addressed_by).
const factory = (propsData = {}) =>
  mount(BulkTriageTargetModal, {
    localVue,
    propsData: {
      targetType: "duplicate",
      componentId: 8,
      excludeReviewIds: [10, 11],
      excludeRuleIds: [],
      count: 2,
      ...propsData,
    },
    // b-modal stubbed so its portal/event plumbing doesn't run; pickers
    // stubbed so no fetches fire — their own specs cover their behavior.
    stubs: {
      "b-modal": { template: "<div><slot /><slot name='modal-footer' /></div>" },
      CanonicalCommentPicker: {
        name: "CanonicalCommentPicker",
        props: ["componentId", "excludeReviewIds", "selectedReviewId"],
        template: "<div data-test='canonical-picker-stub' />",
      },
      RulePicker: {
        name: "RulePicker",
        props: ["componentId", "excludeRuleIds", "selectedRuleId"],
        template: "<div data-test='rule-picker-stub' />",
      },
    },
  });

describe("BulkTriageTargetModal", () => {
  it("hosts the canonical comment picker for duplicate, excluding the whole selection", () => {
    const w = factory({ targetType: "duplicate", excludeReviewIds: [10, 11] });
    const picker = w.findComponent({ name: "CanonicalCommentPicker" });
    expect(picker.exists()).toBe(true);
    expect(picker.props("excludeReviewIds")).toEqual([10, 11]);
    expect(w.findComponent({ name: "RulePicker" }).exists()).toBe(false);
  });

  it("hosts the rule picker for addressed_by, excluding the selection's own rules", () => {
    const w = factory({ targetType: "addressed_by", excludeRuleIds: [3, 4] });
    const picker = w.findComponent({ name: "RulePicker" });
    expect(picker.exists()).toBe(true);
    expect(picker.props("excludeRuleIds")).toEqual([3, 4]);
    expect(w.findComponent({ name: "CanonicalCommentPicker" }).exists()).toBe(false);
  });

  it("disables confirm until a target is picked", async () => {
    const w = factory();
    expect(w.vm.canConfirm).toBe(false);
    w.findComponent({ name: "CanonicalCommentPicker" }).vm.$emit("selected", 42);
    await w.vm.$nextTick();
    expect(w.vm.canConfirm).toBe(true);
  });

  it("emits confirm with the picked target id", async () => {
    const w = factory();
    w.findComponent({ name: "CanonicalCommentPicker" }).vm.$emit("selected", 42);
    await w.vm.$nextTick();
    w.vm.confirm();
    expect(w.emitted("confirm")[0]).toEqual([42]);
  });

  it("does not emit confirm without a target", () => {
    const w = factory();
    w.vm.confirm();
    expect(w.emitted("confirm")).toBeFalsy();
  });

  it("resets the picked target when the modal closes", async () => {
    const w = factory();
    w.findComponent({ name: "CanonicalCommentPicker" }).vm.$emit("selected", 42);
    await w.vm.$nextTick();
    w.vm.onHidden();
    expect(w.vm.targetId).toBeNull();
  });

  it("names the action and count on the confirm button", () => {
    const w = factory({ count: 3 });
    expect(w.text()).toContain("Apply to 3 comments");
  });

  describe("kind-keyed noun (both directions)", () => {
    it("srg addressed-by copy says requirement, never rule", () => {
      const w = mount(BulkTriageTargetModal, {
        localVue,
        propsData: {
          targetType: "addressed_by",
          componentId: 8,
          excludeReviewIds: [10],
          excludeRuleIds: [1],
          count: 1,
        },
        provide: { injectedDocumentType: "srg" },
        stubs: { BModal: true, CanonicalCommentPicker: true, RulePicker: true },
      });
      expect(w.vm.title).toBe("Addressed by — pick the target requirement");
      expect(w.vm.explainer).not.toMatch(/\brule\b/);
    });

    it("stig (default) addressed-by copy says rule, never requirement", () => {
      const w = factory({ targetType: "addressed_by" });
      expect(w.vm.title).toBe("Addressed by — pick the target rule");
      expect(w.vm.explainer).toContain("addressed by the rule you pick");
      expect(w.vm.explainer).not.toMatch(/\brequirement\b/);
    });
  });
});
