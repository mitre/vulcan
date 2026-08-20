import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import { createPinia, setActivePinia } from "pinia";
import NewRuleModalForm from "@/components/rules/forms/NewRuleModalForm.vue";

/**
 * NewRuleModalForm Component Tests
 *
 * REQUIREMENTS:
 * - Shows a clone confirmation (with the source rule text) when
 *   forDuplicate is true, and a create confirmation otherwise.
 * - Submitting emits create:rule on $root with the duplicate flag and
 *   source rule id; the success callback selects the new rule.
 * - Carries NO mixins — the previously imported FormMixin was verified
 *   dead (authenticityToken never referenced).
 */
describe("NewRuleModalForm", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    const pinia = createPinia();
    setActivePinia(pinia);
    const w = mount(NewRuleModalForm, {
      localVue,
      pinia,
      propsData: {
        idPrefix: "duplicate",
        title: "Clone Control",
        forDuplicate: true,
        selectedRuleId: 7,
        selectedRuleText: "TEST-000010",
        ...props,
      },
      stubs: {
        // render slot content so the confirmation text is assertable
        BModal: { template: "<div><slot /></div>" },
      },
    });
    vi.spyOn(w.vm.$root, "$emit");
    return w;
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("confirmation text", () => {
    it("shows the clone confirmation with the source rule text", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Clone control TEST-000010?");
    });

    it("shows the create confirmation when not duplicating", () => {
      wrapper = createWrapper({ forDuplicate: false });
      expect(wrapper.text()).toContain("Create a new control in this project?");
    });
  });

  describe("submit", () => {
    it("emits create:rule with the duplicate flag and source id", () => {
      wrapper = createWrapper();
      wrapper.vm.handleSubmit();
      expect(wrapper.vm.$root.$emit).toHaveBeenCalledWith(
        "create:rule",
        { duplicate: true, id: 7 },
        expect.any(Function),
      );
    });

    it("selects the newly created rule via the success callback", () => {
      wrapper = createWrapper();
      const selectSpy = vi.spyOn(wrapper.vm.ruleStore, "selectRule");
      wrapper.vm.handleSubmit();
      const callback = wrapper.vm.$root.$emit.mock.calls[0][2];
      callback({ data: { data: { id: 99 } } });
      expect(selectSpy).toHaveBeenCalledWith(99);
    });
  });

  // ── dead-mixin removal contract ─────────────────────────────────────
  // REQUIREMENT: the component carries no mixins at all. FormMixin was
  // imported but its only member (authenticityToken) was never used.
  describe("mixin-free contract", () => {
    it("declares no mixins", () => {
      expect(NewRuleModalForm.mixins).toBeUndefined();
    });
  });
});
