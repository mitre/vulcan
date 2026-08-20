import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import AcceptRelocationModal from "@/components/rules/AcceptRelocationModal.vue";

/**
 * AcceptRelocationModal requirements (dry-run preview + confirm):
 *
 * 1. Renders the server's dry-run preview before any write: the source
 *    requirement, the destination component, the number it would land
 *    under, and that the source becomes history.
 * 2. Confirm is enabled ONLY for a valid preview and emits accept —
 *    nothing lands without the explicit confirm.
 * 3. An invalid preview renders every server reason verbatim and keeps
 *    confirm disabled — the server stays authoritative.
 * 4. While the dry-run is loading, confirm is disabled.
 */
const MARKER = {
  id: 7,
  source_rule_id: 11,
  component_id: 9,
  target_technology_token: "CTR",
  source_displayed_name: "WALK-00-000012",
  component_name: "Other SRG",
};

const VALID_PREVIEW = {
  valid: true,
  errors: [],
  source_displayed_name: "WALK-00-000012",
  target_component_id: 5,
  target_component_name: "Container SRG",
  would_create: {
    title: "The requirement moving in",
    status: "Applicable",
    rule_id: "000003",
    derived_from_srg_rule_id: 42,
  },
  would_tombstone_source: true,
};

const INVALID_PREVIEW = {
  ...VALID_PREVIEW,
  valid: false,
  errors: [
    "target component does not declare SRG-CORE-OS as a source SRG — add it first",
    "target component is released",
  ],
  would_create: { ...VALID_PREVIEW.would_create, rule_id: null },
};

describe("AcceptRelocationModal", () => {
  let wrapper;

  const ModalStub = { template: "<div><slot></slot><slot name='modal-footer'></slot></div>" };

  const createWrapper = (props = {}) => {
    return mount(AcceptRelocationModal, {
      localVue,
      propsData: {
        visible: true,
        marker: MARKER,
        preview: VALID_PREVIEW,
        loading: false,
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

  it("renders the dry-run preview — source, destination, landed number, history statement", () => {
    wrapper = createWrapper();
    const text = wrapper.text().replace(/\s+/g, " ");
    expect(text).toContain("WALK-00-000012");
    expect(text).toContain("Container SRG");
    expect(text).toContain("000003");
    expect(text).toContain("history");
  });

  it("enables confirm for a valid preview and emits accept on click", async () => {
    wrapper = createWrapper();
    const confirm = wrapper.find('[data-test="confirm-accept"]');
    expect(confirm.attributes("disabled")).toBeUndefined();
    await confirm.trigger("click");
    expect(wrapper.emitted("accept")).toEqual([[]]);
  });

  it("renders every server reason and disables confirm for an invalid preview", () => {
    wrapper = createWrapper({ preview: INVALID_PREVIEW });
    const text = wrapper.text().replace(/\s+/g, " ");
    expect(text).toContain("does not declare SRG-CORE-OS as a source SRG");
    expect(text).toContain("target component is released");
    expect(wrapper.find('[data-test="confirm-accept"]').attributes("disabled")).toBeDefined();
  });

  it("labels confirm with the DISA concur verb", () => {
    wrapper = createWrapper();
    expect(wrapper.find('[data-test="confirm-accept"]').text()).toBe("Concur and move");
  });

  it("disables confirm while the dry-run is loading", () => {
    wrapper = createWrapper({ preview: null, loading: true });
    expect(wrapper.find('[data-test="confirm-accept"]').attributes("disabled")).toBeDefined();
  });
});
