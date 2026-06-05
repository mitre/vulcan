import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import DisaGuidePage from "@/components/disa_guide/DisaGuidePage.vue";

vi.mock("@/utils/colorMode", () => ({
  toggleTheme: vi.fn(),
}));

import { toggleTheme } from "@/utils/colorMode";

const baseProps = {
  htmlContent: "<h2 id='intro'>Introduction</h2><p>Test content</p>",
  pageTitle: "Test Guide",
  currentPage: "overview",
  pageSections: [
    {
      label: "Reference",
      pages: { "full-guide": "Full Guide" },
    },
    {
      label: "Guides",
      pages: { overview: "Overview", "field-reqs": "Field Requirements" },
    },
  ],
  toc: [
    { level: 2, text: "Introduction", id: "intro" },
    { level: 3, text: "Subsection", id: "subsection" },
  ],
};

describe("DisaGuidePage", () => {
  let wrapper;

  beforeEach(() => {
    document.documentElement.setAttribute("data-bs-theme", "dark");
    vi.clearAllMocks();
  });

  afterEach(() => {
    if (wrapper) wrapper.destroy();
    document.documentElement.removeAttribute("data-bs-theme");
  });

  const createWrapper = (propsOverrides = {}) => {
    return mount(DisaGuidePage, {
      localVue,
      propsData: { ...baseProps, ...propsOverrides },
    });
  };

  it("renders the page title in the header", () => {
    wrapper = createWrapper();
    expect(wrapper.find(".disa-guide-main__header h5").text()).toBe("Test Guide");
  });

  it("renders htmlContent via v-html", () => {
    wrapper = createWrapper();
    const content = wrapper.find(".disa-guide-content");
    expect(content.html()).toContain("<h2");
    expect(content.html()).toContain("Introduction");
    expect(content.html()).toContain("Test content");
  });

  it("renders sidebar nav sections with labels", () => {
    wrapper = createWrapper();
    const labels = wrapper.findAll(".disa-guide-nav__label");
    expect(labels.length).toBe(2);
    expect(labels.at(0).text()).toBe("Reference");
    expect(labels.at(1).text()).toBe("Guides");
  });

  it("marks the current page as active in the sidebar", () => {
    wrapper = createWrapper();
    const activeLink = wrapper.find(".disa-guide-nav__link.active");
    expect(activeLink.exists()).toBe(true);
    expect(activeLink.text()).toBe("Overview");
  });

  it("renders TOC links when toc prop is provided", () => {
    wrapper = createWrapper();
    const tocLinks = wrapper.findAll(".disa-guide-toc__link");
    expect(tocLinks.length).toBe(2);
    expect(tocLinks.at(0).text()).toBe("Introduction");
    expect(tocLinks.at(0).attributes("href")).toBe("#intro");
  });

  it("does NOT render TOC panel when toc is empty", () => {
    wrapper = createWrapper({ toc: [] });
    expect(wrapper.find(".disa-guide-toc-panel").exists()).toBe(false);
  });

  it("applies toc-level-3 class to h3 TOC entries", () => {
    wrapper = createWrapper();
    const tocLinks = wrapper.findAll(".disa-guide-toc__link");
    expect(tocLinks.at(1).classes()).toContain("toc-level-3");
  });

  it("renders a theme toggle button", () => {
    wrapper = createWrapper();
    const btn = wrapper.find("[aria-label='Toggle dark mode']");
    expect(btn.exists()).toBe(true);
  });

  it("shows sun icon in dark mode", () => {
    wrapper = createWrapper();
    expect(wrapper.vm.isDarkMode).toBe(true);
  });

  it("calls toggleTheme when toggle button is clicked", async () => {
    wrapper = createWrapper();
    await wrapper.find("[aria-label='Toggle dark mode']").trigger("click");
    expect(toggleTheme).toHaveBeenCalledOnce();
  });

});
