import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import MarkRelocationModal from "@/components/rules/MarkRelocationModal.vue";

/**
 * MarkRelocationModal requirements (the mark affordance):
 *
 * 1. Collects the destination family technology token (uppercased) and
 *    emits mark with it on confirm.
 * 2. Confirm is disabled until a token is entered.
 * 3. The token input clears when the modal reopens.
 */
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
});
