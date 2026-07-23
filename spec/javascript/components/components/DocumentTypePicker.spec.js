import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import DocumentTypePicker from "@/components/components/DocumentTypePicker.vue";

/**
 * DocumentTypePicker Contract Tests
 *
 * REQUIREMENTS:
 *
 * 1. THE CREATION-TIME CHOICE IS LEGIBLE, NOT TWO BARE RADIOS:
 *    Each option carries a plain-language description. The copy is
 *    LOCKED — these tests pin it verbatim (word-for-word; only
 *    line-wrapping may vary, so assertions normalize whitespace).
 *
 * 2. THE CHOICE IS EXCLUSIVE AND STARTS EMPTY:
 *    No profile is preselected — the author must make the choice.
 *
 * 3. v-model CONTRACT:
 *    Selecting an option emits input with "stig" or "srg"; the value
 *    prop drives the checked state.
 */

// LOCKED copy — do not reword (creation-dialog copy decision).
const QUESTION = "What are you authoring?";
const STIG_DESCRIPTION =
  'Implement an existing SRG\'s requirements for a specific product (e.g. "Red Hat OpenShift STIG"). ' +
  "You'll work each requirement to a compliance posture: Configurable, Inherently Meets, " +
  "Does Not Meet, or Not Applicable.";
const SRG_DESCRIPTION =
  'Author a new Security Requirements Guide derived from core SRGs (e.g. "Container Platform SRG"). ' +
  "You'll decide which requirements apply to the technology and tailor their content.";
const PERMANENCE_NOTE = "This choice is permanent for the component.";

describe("DocumentTypePicker", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return mount(DocumentTypePicker, {
      localVue,
      propsData: { value: null, ...props },
    });
  };

  const normalizedText = () => wrapper.text().replace(/\s+/g, " ");

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  describe("locked copy renders verbatim", () => {
    it("asks the question", () => {
      wrapper = createWrapper();
      expect(normalizedText()).toContain(QUESTION);
    });

    it("renders the STIG option title and its full locked description", () => {
      wrapper = createWrapper();
      const text = normalizedText();
      expect(text).toContain("STIG");
      expect(text).toContain(STIG_DESCRIPTION);
    });

    it("renders the SRG option title and its full locked description", () => {
      wrapper = createWrapper();
      const text = normalizedText();
      expect(text).toContain("SRG");
      expect(text).toContain(SRG_DESCRIPTION);
    });

    it("renders the permanence note", () => {
      wrapper = createWrapper();
      expect(normalizedText()).toContain(PERMANENCE_NOTE);
    });
  });

  describe("exclusive choice with no default", () => {
    it("renders exactly two radio options: stig and srg", () => {
      wrapper = createWrapper();
      const radios = wrapper.findAll('input[type="radio"]');
      expect(radios.length).toBe(2);
      expect(radios.at(0).attributes("value")).toBe("stig");
      expect(radios.at(1).attributes("value")).toBe("srg");
    });

    it("preselects nothing when value is null", () => {
      wrapper = createWrapper();
      const radios = wrapper.findAll('input[type="radio"]');
      expect(radios.at(0).element.checked).toBe(false);
      expect(radios.at(1).element.checked).toBe(false);
    });

    it("checks the option matching the value prop", () => {
      wrapper = createWrapper({ value: "srg" });
      const radios = wrapper.findAll('input[type="radio"]');
      expect(radios.at(0).element.checked).toBe(false);
      expect(radios.at(1).element.checked).toBe(true);
    });
  });

  describe("v-model contract", () => {
    it("emits input with 'stig' when the STIG option is selected", async () => {
      wrapper = createWrapper();
      await wrapper.findAll('input[type="radio"]').at(0).setChecked();
      expect(wrapper.emitted("input")).toBeTruthy();
      expect(wrapper.emitted("input")[0]).toEqual(["stig"]);
    });

    it("emits input with 'srg' when the SRG option is selected", async () => {
      wrapper = createWrapper();
      await wrapper.findAll('input[type="radio"]').at(1).setChecked();
      expect(wrapper.emitted("input")).toBeTruthy();
      expect(wrapper.emitted("input")[0]).toEqual(["srg"]);
    });
  });
});
