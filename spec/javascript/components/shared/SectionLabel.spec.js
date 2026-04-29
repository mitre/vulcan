import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import SectionLabel from "@/components/shared/SectionLabel.vue";

describe("SectionLabel", () => {
  it("renders friendly label for an XCCDF key", () => {
    const w = mount(SectionLabel, { propsData: { section: "check_content" } });
    expect(w.text()).toBe("Check");
  });

  it("renders (general) for null", () => {
    const w = mount(SectionLabel, { propsData: { section: null } });
    expect(w.text()).toBe("(general)");
  });

  it("renders em-dash placeholder for null when 'placeholder' prop is set", () => {
    const w = mount(SectionLabel, {
      propsData: { section: null, placeholder: true },
    });
    expect(w.text()).toBe("—");
  });

  it("renders the raw key for an unknown section (no crash)", () => {
    const w = mount(SectionLabel, { propsData: { section: "not_a_real_key" } });
    expect(w.text()).toBe("not_a_real_key");
  });

  it("renders friendly label for vuln_discussion", () => {
    const w = mount(SectionLabel, {
      propsData: { section: "vuln_discussion" },
    });
    expect(w.text()).toBe("Vulnerability Discussion");
  });
});
