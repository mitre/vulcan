import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import DeclineRelocationModal from "@/components/rules/DeclineRelocationModal.vue";

/**
 * DeclineRelocationModal requirements (decline with rationale):
 *
 * 1. Names the proposal being declined and collects a rationale.
 * 2. Confirm is disabled until a non-blank rationale is entered — the
 *    rationale is the message back to the source author, so it is
 *    required, not optional.
 * 3. Confirm emits decline with the rationale; the field clears when
 *    the modal reopens.
 */
describe("DeclineRelocationModal", () => {
  let wrapper;

  const ModalStub = { template: "<div><slot></slot><slot name='modal-footer'></slot></div>" };

  const createWrapper = (props = {}) => {
    return mount(DeclineRelocationModal, {
      localVue,
      propsData: {
        visible: true,
        sourceDisplayedName: "WALK-00-000012",
        ...props,
      },
      stubs: { "b-modal": ModalStub },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  it("names the proposal being declined", () => {
    wrapper = createWrapper();
    expect(wrapper.text()).toContain("WALK-00-000012");
  });

  it("disables confirm until a non-blank rationale is entered", async () => {
    wrapper = createWrapper();
    const confirm = wrapper.find('[data-test="confirm-decline"]');
    expect(confirm.attributes("disabled")).toBeDefined();

    await wrapper.find('[data-test="decline-rationale-input"]').setValue("   ");
    expect(confirm.attributes("disabled")).toBeDefined();

    await wrapper.find('[data-test="decline-rationale-input"]').setValue("Covered elsewhere.");
    expect(confirm.attributes("disabled")).toBeUndefined();
  });

  it("emits decline with the rationale on confirm", async () => {
    wrapper = createWrapper();
    await wrapper.find('[data-test="decline-rationale-input"]').setValue("Covered elsewhere.");
    await wrapper.find('[data-test="confirm-decline"]').trigger("click");

    expect(wrapper.emitted("decline")).toEqual([["Covered elsewhere."]]);
  });

  it("labels confirm with the DISA non-concur verb and SRG-worded placeholder", () => {
    wrapper = createWrapper();
    expect(wrapper.find('[data-test="confirm-decline"]').text()).toBe("Non-concur");
    expect(
      wrapper.find('[data-test="decline-rationale-input"]').attributes("placeholder"),
    ).toContain("in this SRG");
  });
});
