import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RelocationIntakeBanner from "@/components/rules/RelocationIntakeBanner.vue";

/**
 * RelocationIntakeBanner requirements (the open-time intake prompt):
 *
 * 1. When open proposals exist for the open component's SRG (by
 *    technology token), an info banner says "N requirements are
 *    proposed for the TOKEN SRG" with a View-backlog affordance.
 * 2. Zero markers (or no derivable token) renders NOTHING — the banner
 *    is a notification indicator, absence is the meaning.
 */
describe("RelocationIntakeBanner", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return mount(RelocationIntakeBanner, {
      localVue,
      propsData: { count: 3, token: "CTR", ...props },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  it("announces the open-proposal count for the SRG", () => {
    wrapper = createWrapper();
    const text = wrapper.text().replace(/\s+/g, " ");
    expect(text).toContain("3 requirements are proposed for the CTR SRG");
  });

  it("uses singular phrasing for one proposal", () => {
    wrapper = createWrapper({ count: 1 });
    expect(wrapper.text().replace(/\s+/g, " ")).toContain(
      "1 requirement is proposed for the CTR SRG",
    );
  });

  it("emits view-backlog from the affordance", async () => {
    wrapper = createWrapper();
    await wrapper.find('[data-test="view-backlog"]').trigger("click");
    expect(wrapper.emitted("view-backlog")).toBeTruthy();
  });

  it("renders nothing when the count is zero", () => {
    wrapper = createWrapper({ count: 0 });
    expect(wrapper.find('[data-test="view-backlog"]').exists()).toBe(false);
    expect(wrapper.text().trim()).toBe("");
  });

  it("renders nothing without a technology token", () => {
    wrapper = createWrapper({ token: null });
    expect(wrapper.text().trim()).toBe("");
  });
});
