import { describe, it, expect, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RelocationBacklogPanel from "@/components/rules/RelocationBacklogPanel.vue";
import FilterDropdown from "@/components/shared/FilterDropdown.vue";

/**
 * RelocationBacklogPanel requirements (per-family backlog):
 *
 * 1. Lists pending markers for the selected family token, across
 *    components, with the source's component-prefixed name.
 * 2. The token filter offers every distinct pending token (explicit
 *    filter — a mismatched prefix-derived default hides nothing) and
 *    defaults to the open component's family token.
 * 3. Un-mark emits the record id for rows of the OPEN component when
 *    the user can author; rows from other components and non-author
 *    sessions render the button DISABLED with an explanatory tooltip —
 *    disabled-not-hidden.
 * 4. Shows the family count line the open-time prompt links to.
 */
const MARKERS = [
  {
    id: 1,
    source_rule_id: 11,
    component_id: 5,
    target_technology_token: "CTR",
    source_displayed_name: "CNTR-00-000051",
    component_name: "Container SRG",
    requested_by_name: "Jane Doe",
  },
  {
    id: 2,
    source_rule_id: 22,
    component_id: 9,
    target_technology_token: "CTR",
    source_displayed_name: "WALK-00-000012",
    component_name: "Other SRG",
    requested_by_name: null,
  },
  {
    id: 3,
    source_rule_id: 33,
    component_id: 5,
    target_technology_token: "GPOS",
    source_displayed_name: "CNTR-00-000090",
    component_name: "Container SRG",
    requested_by_name: "Jane Doe",
  },
];

describe("RelocationBacklogPanel", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return mount(RelocationBacklogPanel, {
      localVue,
      propsData: {
        markers: MARKERS,
        componentId: 5,
        initialToken: "CTR",
        canAuthor: true,
        ...props,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  it("lists pending markers for the selected token with source identity", () => {
    wrapper = createWrapper();
    const rows = wrapper.findAll('[data-test="relocation-row"]');
    expect(rows.length).toBe(2);
    const text = wrapper.text().replace(/\s+/g, " ");
    expect(text).toContain("CNTR-00-000051");
    expect(text).toContain("WALK-00-000012");
    expect(text).not.toContain("CNTR-00-000090");
  });

  it("offers every distinct pending token in the filter and defaults to the family token", () => {
    wrapper = createWrapper();
    const dropdown = wrapper.findComponent(FilterDropdown);
    expect(dropdown.props("options").map((o) => o.value)).toEqual(["CTR", "GPOS"]);
    expect(dropdown.props("value")).toBe("CTR");
  });

  it("shows the family count line", () => {
    wrapper = createWrapper();
    expect(wrapper.text().replace(/\s+/g, " ")).toContain(
      "2 requirements are marked for the CTR family",
    );
  });

  it("emits unmark with the record id for an authorable row of the open component", async () => {
    wrapper = createWrapper();
    await wrapper.find('[data-test="unmark-1"]').trigger("click");
    expect(wrapper.emitted("unmark")).toEqual([[1]]);
  });

  it("disables (not hides) un-mark for rows from other components, with a tooltip", () => {
    wrapper = createWrapper();
    const other = wrapper.find('[data-test="unmark-2"]');
    expect(other.exists()).toBe(true);
    expect(other.attributes("disabled")).toBeDefined();
    expect(wrapper.find('[data-test="unmark-tip-2"]').attributes("title")).toContain(
      "that component's editor",
    );
  });

  it("disables (not hides) un-mark when the user cannot author", () => {
    wrapper = createWrapper({ canAuthor: false });
    const own = wrapper.find('[data-test="unmark-1"]');
    expect(own.exists()).toBe(true);
    expect(own.attributes("disabled")).toBeDefined();
    expect(wrapper.find('[data-test="unmark-tip-1"]').attributes("title")).toContain("author");
  });

  it("shows the empty state when no markers match the token", () => {
    wrapper = createWrapper({ markers: [], initialToken: null });
    expect(wrapper.text().replace(/\s+/g, " ")).toContain("No requirements are marked");
  });
});
