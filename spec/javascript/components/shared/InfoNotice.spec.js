import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import InfoNotice from "@/components/shared/InfoNotice.vue";

describe("InfoNotice", () => {
  it("renders info-circle icon and text from prop", () => {
    const w = mount(InfoNotice, { localVue, propsData: { text: "Test message" } });
    expect(w.find(".info-notice").exists()).toBe(true);
    expect(w.text()).toContain("Test message");
  });

  it("renders slot content instead of text prop when slot is used", () => {
    const w = mount(InfoNotice, {
      localVue,
      slots: { default: "<strong>Custom HTML</strong>" },
    });
    expect(w.find("strong").text()).toBe("Custom HTML");
  });

  it("applies text-muted class by default (info variant)", () => {
    const w = mount(InfoNotice, { localVue, propsData: { text: "Info" } });
    expect(w.find(".info-notice").classes()).toContain("text-muted");
  });

  it("applies text-warning class for warning variant", () => {
    const w = mount(InfoNotice, {
      localVue,
      propsData: { text: "Warning", variant: "warning" },
    });
    expect(w.find(".info-notice").classes()).toContain("text-warning");
  });

  it("renders as small text by default", () => {
    const w = mount(InfoNotice, { localVue, propsData: { text: "Small" } });
    expect(w.find("small").exists()).toBe(true);
  });
});
