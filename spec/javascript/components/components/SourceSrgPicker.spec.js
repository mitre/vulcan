import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import VueMultiselect from "vue-multiselect";
import SourceSrgPicker from "@/components/components/SourceSrgPicker.vue";

/**
 * SourceSrgPicker Contract Tests
 *
 * REQUIREMENTS (multi-parent creation flow):
 *
 * 1. ELIGIBILITY BY CONSTRUCTION: the picker offers ONLY parents
 *    eligible for the chosen profile — core families for srg,
 *    derived (non-core) for stig. Ineligible sources never appear,
 *    mirroring the backend AuthoringProfile registry policy.
 *
 * 2. MULTI-SELECT WITH A PRIMARY: the author declares 1..N sources;
 *    exactly one is the primary. The primary DEFAULTS to the first
 *    selection and may be changed before create. Removing the
 *    primary source reassigns the primary to the first remaining.
 *
 * 3. v-model CONTRACT: value is { sourceIds: [], primaryId: null };
 *    every mutation emits input with the complete new state.
 */

const CORE_OS = { id: 1, srg_id: "SRG-CORE-OS", title: "OS Core", version: "V1R1", core: true };
const CORE_APP = { id: 2, srg_id: "SRG-CORE-APP", title: "APP Core", version: "V1R1", core: true };
const DERIVED_GPOS = { id: 3, srg_id: "GPOS-SRG", title: "GPOS SRG", version: "V3R3", core: false };
const DERIVED_CTR = {
  id: 4,
  srg_id: "CTR-SRG",
  title: "Container SRG",
  version: "V2R4",
  core: false,
};
const ALL_SRGS = [CORE_OS, CORE_APP, DERIVED_GPOS, DERIVED_CTR];

describe("SourceSrgPicker", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return mount(SourceSrgPicker, {
      localVue,
      propsData: {
        srgs: ALL_SRGS,
        documentType: "srg",
        value: { sourceIds: [], primaryId: null },
        ...props,
      },
    });
  };

  const offeredIds = () =>
    wrapper
      .findComponent(VueMultiselect)
      .props("options")
      .map((srg) => srg.id);

  const lastEmitted = () => {
    const events = wrapper.emitted("input");
    return events[events.length - 1][0];
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  describe("eligibility by construction (registry policy mirror)", () => {
    it("offers only core families for an srg-kind component", () => {
      wrapper = createWrapper({ documentType: "srg" });
      expect(offeredIds()).toEqual([CORE_OS.id, CORE_APP.id]);
    });

    it("offers only derived (non-core) families for a stig-kind component", () => {
      wrapper = createWrapper({ documentType: "stig" });
      expect(offeredIds()).toEqual([DERIVED_GPOS.id, DERIVED_CTR.id]);
    });

    it("offers nothing until a profile is chosen", () => {
      wrapper = createWrapper({ documentType: null });
      expect(offeredIds()).toEqual([]);
    });
  });

  describe("primary designation", () => {
    it("defaults the primary to the first selection", async () => {
      wrapper = createWrapper();
      await wrapper.findComponent(VueMultiselect).vm.$emit("input", [CORE_OS]);

      expect(lastEmitted()).toEqual({ sourceIds: [CORE_OS.id], primaryId: CORE_OS.id });
    });

    it("keeps the existing primary when more sources are added", async () => {
      wrapper = createWrapper({ value: { sourceIds: [CORE_OS.id], primaryId: CORE_OS.id } });
      await wrapper.findComponent(VueMultiselect).vm.$emit("input", [CORE_OS, CORE_APP]);

      expect(lastEmitted()).toEqual({
        sourceIds: [CORE_OS.id, CORE_APP.id],
        primaryId: CORE_OS.id,
      });
    });

    it("changes the primary via the radio before create", async () => {
      wrapper = createWrapper({
        value: { sourceIds: [CORE_OS.id, CORE_APP.id], primaryId: CORE_OS.id },
      });
      // BootstrapVue inherits non-prop attributes onto the underlying
      // <input>, so the testid selector IS the radio input.
      await wrapper.find(`input[data-testid="primary-radio-${CORE_APP.id}"]`).setChecked();

      expect(lastEmitted()).toEqual({
        sourceIds: [CORE_OS.id, CORE_APP.id],
        primaryId: CORE_APP.id,
      });
    });

    it("reassigns the primary to the first remaining source when the primary is removed", async () => {
      wrapper = createWrapper({
        value: { sourceIds: [CORE_OS.id, CORE_APP.id], primaryId: CORE_OS.id },
      });
      await wrapper.findComponent(VueMultiselect).vm.$emit("input", [CORE_APP]);

      expect(lastEmitted()).toEqual({ sourceIds: [CORE_APP.id], primaryId: CORE_APP.id });
    });

    it("clears the primary when the last source is removed", async () => {
      wrapper = createWrapper({ value: { sourceIds: [CORE_OS.id], primaryId: CORE_OS.id } });
      await wrapper.findComponent(VueMultiselect).vm.$emit("input", []);

      expect(lastEmitted()).toEqual({ sourceIds: [], primaryId: null });
    });
  });

  describe("selected-source display", () => {
    it("lists each selected source with a primary radio", () => {
      wrapper = createWrapper({
        value: { sourceIds: [CORE_OS.id, CORE_APP.id], primaryId: CORE_OS.id },
      });

      expect(wrapper.find(`[data-testid="primary-radio-${CORE_OS.id}"]`).exists()).toBe(true);
      expect(wrapper.find(`[data-testid="primary-radio-${CORE_APP.id}"]`).exists()).toBe(true);
      const text = wrapper.text().replace(/\s+/g, " ");
      expect(text).toContain("OS Core");
      expect(text).toContain("APP Core");
    });
  });
});
