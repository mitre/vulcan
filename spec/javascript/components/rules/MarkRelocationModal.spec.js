import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import MarkRelocationModal from "@/components/rules/MarkRelocationModal.vue";
import FilterDropdown from "@/components/shared/FilterDropdown.vue";

/**
 * MarkRelocationModal requirements (the propose affordance):
 *
 * 1. Proposes relocation to a destination SRG: collects the SRG's
 *    technology token (uppercased) and emits mark with it on confirm.
 * 2. Confirm is disabled until a token is entered.
 * 3. The token input clears when the modal reopens.
 * 4. Copy is the DISA propose vocabulary: the destination SRG's authors
 *    concur or non-concur; nothing changes here until then; the
 *    proposal is withdrawable while open. Never the word family.
 * 5. DESTINATION PICKER: the modal renders the labelled options provided
 *    by useRelocations' destination vocabulary (labelling and merging
 *    are pinned in the composable spec) and appends ONLY its own
 *    Other-SRG entry; picking one emits its abbreviation on confirm.
 *    The Other option (and the empty options case) reveals the free
 *    token input — proposing to an SRG the caller cannot see stays
 *    possible without disclosure.
 */
const DESTINATION_OPTIONS = [
  { value: "RCVA", text: "Walkthrough receiving SRG" },
  { value: "GPOS", text: "GPOS SRG (next release)" },
];
describe("MarkRelocationModal", () => {
  let wrapper;

  const ModalStub = { template: "<div><slot></slot><slot name='modal-footer'></slot></div>" };

  const createWrapper = (props = {}) => {
    return mount(MarkRelocationModal, {
      localVue,
      propsData: { visible: true, ruleDisplayName: "CNTR-00-000051", ...props },
      stubs: { "b-modal": ModalStub },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  it("emits mark with the uppercased token on confirm", async () => {
    wrapper = createWrapper();
    await wrapper.find('[data-test="relocation-token-input"]').setValue("ctr");
    await wrapper.find('[data-test="confirm-mark"]').trigger("click");

    expect(wrapper.emitted("mark")).toEqual([["CTR"]]);
  });

  it("disables confirm until a token is entered", () => {
    wrapper = createWrapper();
    expect(wrapper.find('[data-test="confirm-mark"]').attributes("disabled")).toBeDefined();
  });

  it("names the requirement being marked", () => {
    wrapper = createWrapper();
    expect(wrapper.text()).toContain("CNTR-00-000051");
  });

  it("carries the propose copy — destination SRG, adjudicated by its authors", () => {
    wrapper = createWrapper();
    const text = wrapper.text().replace(/\s+/g, " ");
    expect(text).toContain("Propose relocating");
    expect(text).toContain("Destination SRG");
    expect(text).toContain("concur or non-concur");
    expect(wrapper.find('[data-test="confirm-mark"]').text()).toBe("Propose relocation");
    expect(text.toLowerCase()).not.toContain("family");
  });

  describe("destination picker", () => {
    it("renders the provided labelled options and appends only its Other entry", () => {
      wrapper = createWrapper({ destinationOptions: DESTINATION_OPTIONS });
      const options = wrapper.findComponent(FilterDropdown).props("options");
      expect(options.map((o) => o.text)).toEqual([
        "Walkthrough receiving SRG",
        "GPOS SRG (next release)",
        "Other SRG… (enter its abbreviation)",
      ]);
      expect(options.map((o) => o.value)).toEqual(["RCVA", "GPOS", "__other__"]);
    });

    it("emits the picked destination's token on confirm — no free input shown", async () => {
      wrapper = createWrapper({ destinationOptions: DESTINATION_OPTIONS });
      expect(wrapper.find('[data-test="relocation-token-input"]').exists()).toBe(false);
      wrapper.findComponent(FilterDropdown).vm.$emit("input", "GPOS");
      await wrapper.vm.$nextTick();
      const confirm = wrapper.find('[data-test="confirm-mark"]');
      expect(confirm.attributes("disabled")).toBeUndefined();
      await confirm.trigger("click");
      expect(wrapper.emitted("mark")).toEqual([["GPOS"]]);
    });

    it("reveals the free token input for the Other-SRG option", async () => {
      wrapper = createWrapper({ destinationOptions: DESTINATION_OPTIONS });
      wrapper.findComponent(FilterDropdown).vm.$emit("input", "__other__");
      await wrapper.vm.$nextTick();
      await wrapper.find('[data-test="relocation-token-input"]').setValue("ctr");
      await wrapper.find('[data-test="confirm-mark"]').trigger("click");
      expect(wrapper.emitted("mark")).toEqual([["CTR"]]);
    });

    it("shows the free token input directly when no destinations are visible", () => {
      wrapper = createWrapper({ destinationOptions: [] });
      expect(wrapper.findComponent(FilterDropdown).exists()).toBe(false);
      expect(wrapper.find('[data-test="relocation-token-input"]').exists()).toBe(true);
    });

    it("resets the picked destination when the modal reopens (the show handler)", async () => {
      wrapper = createWrapper({ destinationOptions: DESTINATION_OPTIONS });
      wrapper.findComponent(FilterDropdown).vm.$emit("input", "GPOS");
      await wrapper.vm.$nextTick();
      // Fire the modal's show event through the stub — pins the
      // @show="reset" template wiring, not just the reset method.
      wrapper.findComponent(ModalStub).vm.$emit("show");
      await wrapper.vm.$nextTick();
      expect(wrapper.find('[data-test="confirm-mark"]').attributes("disabled")).toBeDefined();
    });
  });
});
