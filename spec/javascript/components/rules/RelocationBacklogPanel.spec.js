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
 * 5. Adjudication affordances on OPEN rows: Accept and Decline emit the
 *    full marker for rows the open component can receive (another
 *    component's requirement, author role, component not released);
 *    self-rows, non-author sessions, and released components render the
 *    buttons DISABLED with an explanatory tooltip — disabled-not-hidden.
 *    The server stays authoritative for everything else (family
 *    coverage, open state) via dry-run.
 * 6. DECLINED rows are retained history, not open markers: they render
 *    the declined state with the rationale and decliner, carry no
 *    action buttons, and stay out of the open-proposal count line.
 * 7. On the read-only view page (viewOnlyPage) actions stay visible but
 *    disabled; when the page mode is the ONLY barrier the tooltip names
 *    the path ("Open the editor to ..."). Intrinsic barriers keep their
 *    own reason — self-rows, missing author role, and released
 *    components are not cured by opening the editor.
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
    declined_at: null,
  },
  {
    id: 2,
    source_rule_id: 22,
    component_id: 9,
    target_technology_token: "CTR",
    source_displayed_name: "WALK-00-000012",
    component_name: "Other SRG",
    requested_by_name: null,
    declined_at: null,
  },
  {
    id: 3,
    source_rule_id: 33,
    component_id: 5,
    target_technology_token: "GPOS",
    source_displayed_name: "CNTR-00-000090",
    component_name: "Container SRG",
    requested_by_name: "Jane Doe",
    declined_at: null,
  },
  {
    id: 4,
    source_rule_id: 44,
    component_id: 9,
    target_technology_token: "CTR",
    source_displayed_name: "WALK-00-000044",
    component_name: "Other SRG",
    requested_by_name: "Jane Doe",
    declined_at: "2026-07-21 10:00:00 UTC",
    adjudication_rationale: "Covered by an existing requirement here.",
    declined_by_name: "Riley Receiver",
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

  it("emits accept-request and decline-request with the full marker for a receivable row", async () => {
    wrapper = createWrapper();
    await wrapper.find('[data-test="accept-2"]').trigger("click");
    await wrapper.find('[data-test="decline-2"]').trigger("click");
    expect(wrapper.emitted("accept-request")).toEqual([[MARKERS[1]]]);
    expect(wrapper.emitted("decline-request")).toEqual([[MARKERS[1]]]);
  });

  it("disables (not hides) adjudication for the open component's own rows, with a tooltip", () => {
    wrapper = createWrapper();
    const accept = wrapper.find('[data-test="accept-1"]');
    const decline = wrapper.find('[data-test="decline-1"]');
    expect(accept.exists()).toBe(true);
    expect(accept.attributes("disabled")).toBeDefined();
    expect(decline.attributes("disabled")).toBeDefined();
    expect(wrapper.find('[data-test="adjudicate-tip-1"]').attributes("title")).toContain(
      "already lives in this component",
    );
  });

  it("disables (not hides) adjudication when the user cannot author", () => {
    wrapper = createWrapper({ canAuthor: false });
    const accept = wrapper.find('[data-test="accept-2"]');
    expect(accept.exists()).toBe(true);
    expect(accept.attributes("disabled")).toBeDefined();
    expect(wrapper.find('[data-test="adjudicate-tip-2"]').attributes("title")).toContain("author");
  });

  it("disables (not hides) adjudication when the open component is released", () => {
    wrapper = createWrapper({ componentReleased: true });
    const accept = wrapper.find('[data-test="accept-2"]');
    expect(accept.exists()).toBe(true);
    expect(accept.attributes("disabled")).toBeDefined();
    expect(wrapper.find('[data-test="adjudicate-tip-2"]').attributes("title")).toContain(
      "Released",
    );
  });

  it("renders declined rows as retained history — rationale and decliner, no action buttons", () => {
    wrapper = createWrapper();
    const declinedRow = wrapper.find('[data-test="declined-row-4"]');
    expect(declinedRow.exists()).toBe(true);
    const text = declinedRow.text().replace(/\s+/g, " ");
    expect(text).toContain("WALK-00-000044");
    expect(text).toContain("Declined");
    expect(text).toContain("Covered by an existing requirement here.");
    expect(text).toContain("Riley Receiver");
    expect(wrapper.find('[data-test="accept-4"]').exists()).toBe(false);
    expect(wrapper.find('[data-test="decline-4"]').exists()).toBe(false);
    expect(wrapper.find('[data-test="unmark-4"]').exists()).toBe(false);
  });

  it("keeps declined rows out of the open-proposal count line", () => {
    wrapper = createWrapper();
    expect(wrapper.text().replace(/\s+/g, " ")).toContain(
      "2 requirements are marked for the CTR family",
    );
  });

  describe("on the read-only view page (viewOnlyPage)", () => {
    it("disables adjudication on receivable rows with the open-the-editor tooltip", () => {
      wrapper = createWrapper({ viewOnlyPage: true });
      const accept = wrapper.find('[data-test="accept-2"]');
      const decline = wrapper.find('[data-test="decline-2"]');
      expect(accept.exists()).toBe(true);
      expect(accept.attributes("disabled")).toBeDefined();
      expect(decline.attributes("disabled")).toBeDefined();
      expect(wrapper.find('[data-test="adjudicate-tip-2"]').attributes("title")).toBe(
        "Open the editor to accept or decline this proposal",
      );
    });

    it("disables un-mark on own rows with the open-the-editor tooltip", () => {
      wrapper = createWrapper({ viewOnlyPage: true });
      const own = wrapper.find('[data-test="unmark-1"]');
      expect(own.exists()).toBe(true);
      expect(own.attributes("disabled")).toBeDefined();
      expect(wrapper.find('[data-test="unmark-tip-1"]').attributes("title")).toBe(
        "Open the editor to withdraw this proposal",
      );
    });

    it("keeps the deeper reason when the editor would not help — role and released", () => {
      wrapper = createWrapper({ viewOnlyPage: true, canAuthor: false });
      expect(wrapper.find('[data-test="adjudicate-tip-2"]').attributes("title")).toContain(
        "author",
      );
      expect(wrapper.find('[data-test="unmark-tip-1"]').attributes("title")).toContain("author");
      wrapper.destroy();

      wrapper = createWrapper({ viewOnlyPage: true, componentReleased: true });
      expect(wrapper.find('[data-test="adjudicate-tip-2"]').attributes("title")).toContain(
        "Released",
      );
    });

    it("keeps the self-row reason on the open component's own rows", () => {
      wrapper = createWrapper({ viewOnlyPage: true });
      expect(wrapper.find('[data-test="adjudicate-tip-1"]').attributes("title")).toContain(
        "already lives in this component",
      );
    });
  });
});
