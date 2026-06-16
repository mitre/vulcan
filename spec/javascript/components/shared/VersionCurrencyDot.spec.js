import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import VersionCurrencyDot from "@/components/shared/VersionCurrencyDot.vue";

describe("VersionCurrencyDot", () => {
  let wrapper;

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  it("renders green dot when isLatest=true", () => {
    wrapper = mount(VersionCurrencyDot, {
      localVue,
      propsData: { isLatest: true },
    });
    const dot = wrapper.find("[data-testid='version-dot']");
    expect(dot.exists()).toBe(true);
    expect(dot.attributes("title")).toContain("Current");
  });

  it("renders yellow dot when isLatest=false", () => {
    wrapper = mount(VersionCurrencyDot, {
      localVue,
      propsData: { isLatest: false, latestVersion: "V5R1", latestId: 42 },
    });
    const dot = wrapper.find("[data-testid='version-dot']");
    expect(dot.exists()).toBe(true);
    expect(dot.attributes("title")).toContain("Newer");
  });

  it("renders as a link when isLatest=false and linkPath is provided", () => {
    wrapper = mount(VersionCurrencyDot, {
      localVue,
      propsData: { isLatest: false, latestVersion: "V5R1", latestId: 42, linkPath: "/srgs" },
    });
    const link = wrapper.find("a[data-testid='version-dot-link']");
    expect(link.exists()).toBe(true);
    expect(link.attributes("href")).toBe("/srgs/42");
  });

  it("does NOT render a link when isLatest=true", () => {
    wrapper = mount(VersionCurrencyDot, {
      localVue,
      propsData: { isLatest: true },
    });
    expect(wrapper.find("a").exists()).toBe(false);
  });

  it("shows version text when showVersion=true", () => {
    wrapper = mount(VersionCurrencyDot, {
      localVue,
      propsData: { isLatest: false, latestVersion: "V5R1", showVersion: true },
    });
    expect(wrapper.text()).toContain("V5R1");
  });

  it("hides version text when showVersion=false (default)", () => {
    wrapper = mount(VersionCurrencyDot, {
      localVue,
      propsData: { isLatest: true },
    });
    expect(wrapper.text()).toBe("");
  });
});
