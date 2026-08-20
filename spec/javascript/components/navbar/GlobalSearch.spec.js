import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import GlobalSearch from "@/components/navbar/GlobalSearch.vue";

vi.mock("@/api/searchApi", () => ({
  globalSearch: vi.fn(() => Promise.resolve({ data: {} })),
}));

describe("GlobalSearch", () => {
  let wrapper;

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  // Accessibility: a placeholder is not an accessible name (it isn't reliably
  // announced and disappears on input). The search field must carry an
  // explicit accessible name.
  it("gives the search input an accessible name via aria-label", () => {
    wrapper = mount(GlobalSearch, {
      localVue,
      stubs: { BPopover: true },
    });

    const input = wrapper.find("input#srg-id-search");
    expect(input.exists()).toBe(true);
    expect(input.attributes("aria-label")).toBeTruthy();
  });
});
