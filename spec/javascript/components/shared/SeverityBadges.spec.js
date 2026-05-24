import { mount } from "@vue/test-utils";
import SeverityBadges from "../../../../app/javascript/components/shared/SeverityBadges.vue";

describe("SeverityBadges", () => {
  it("renders CAT I badge with count when high > 0", () => {
    const wrapper = mount(SeverityBadges, {
      propsData: { counts: { high: 34, medium: 230, low: 22 } },
    });
    const catI = wrapper.find('[data-testid="cat-high"]');
    expect(catI.exists()).toBe(true);
    expect(catI.text()).toContain("CAT I");
    expect(catI.text()).toContain("34");
  });

  it("renders CAT II badge with count when medium > 0", () => {
    const wrapper = mount(SeverityBadges, {
      propsData: { counts: { high: 0, medium: 128, low: 0 } },
    });
    const catII = wrapper.find('[data-testid="cat-medium"]');
    expect(catII.exists()).toBe(true);
    expect(catII.text()).toContain("CAT II");
    expect(catII.text()).toContain("128");
  });

  it("renders CAT III badge with count when low > 0", () => {
    const wrapper = mount(SeverityBadges, {
      propsData: { counts: { high: 0, medium: 0, low: 10 } },
    });
    const catIII = wrapper.find('[data-testid="cat-low"]');
    expect(catIII.exists()).toBe(true);
    expect(catIII.text()).toContain("CAT III");
    expect(catIII.text()).toContain("10");
  });

  it("hides badges with zero count", () => {
    const wrapper = mount(SeverityBadges, {
      propsData: { counts: { high: 5, medium: 0, low: 0 } },
    });
    expect(wrapper.find('[data-testid="cat-high"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="cat-medium"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="cat-low"]').exists()).toBe(false);
  });

  it("renders nothing when counts is null", () => {
    const wrapper = mount(SeverityBadges, {
      propsData: { counts: null },
    });
    expect(wrapper.findAll('[data-testid^="cat-"]').length).toBe(0);
  });

  it("uses inline layout (not stacked)", () => {
    const wrapper = mount(SeverityBadges, {
      propsData: { counts: { high: 1, medium: 2, low: 3 } },
    });
    const container = wrapper.find(".severity-badges");
    expect(container.exists()).toBe(true);
    expect(container.classes()).toContain("d-flex");
  });

  it("does not use b-badge variant='light'", () => {
    const wrapper = mount(SeverityBadges, {
      propsData: { counts: { high: 10, medium: 20, low: 5 } },
    });
    const html = wrapper.html();
    expect(html).not.toContain('variant="light"');
    expect(html).not.toContain("badge-light");
  });
});
