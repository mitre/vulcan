import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { nextTick, ref } from "vue";
import { useRuleNavigation } from "@/composables/useRuleNavigation";
import { getDefaultFilters } from "@/composables/useRuleFilters";

/**
 * useRuleNavigation requirements:
 *
 * Composable that encapsulates the sidebar navigation logic:
 * 1. Filters, sorts, and searches rules (the full pipeline)
 * 2. Tracks which filters are active (for count indicator + pills)
 * 3. Provides clearFilters / removeFilter for search bar + pills
 * 4. Manages localStorage persistence of filter state
 * 5. Computes filteredRules from the full pipeline
 *
 * Kind-awareness: status filtering runs on the vocabulary-keyed
 * `statusFilters` map — the composable receives the page's statuses and
 * never hardcodes a status name. Saved filter state from the legacy
 * five-boolean shape is migrated on restore (one clearly-marked shim).
 */
const STIG_STATUSES = [
  "Not Yet Determined",
  "Applicable - Configurable",
  "Applicable - Inherently Meets",
  "Applicable - Does Not Meet",
  "Not Applicable",
];

const SRG_STATUSES = ["Not Yet Determined", "Applicable", "Not Applicable"];

describe("useRuleNavigation", () => {
  const createRules = () =>
    ref([
      {
        id: 1,
        rule_id: "001",
        version: "SV-1",
        status: "Applicable - Configurable",
        satisfies: [],
        satisfied_by: [],
        locked: false,
        review_requestor_id: null,
        checks_attributes: [],
        disa_rule_descriptions_attributes: [],
        comment_summary: null,
      },
      {
        id: 2,
        rule_id: "002",
        version: "SV-2",
        status: "Not Yet Determined",
        satisfies: [],
        satisfied_by: [],
        locked: false,
        review_requestor_id: null,
        checks_attributes: [],
        disa_rule_descriptions_attributes: [],
        comment_summary: null,
      },
    ]);

  const nav = (rules, externalFilters = null, statuses = STIG_STATUSES) =>
    useRuleNavigation(rules, "TEST", 41, externalFilters, statuses);

  beforeEach(() => {
    localStorage.clear();
  });

  afterEach(() => {
    localStorage.clear();
  });

  it("returns all rules when no filters are active (additive model)", () => {
    const { filteredRules } = nav(createRules());
    expect(filteredRules.value.length).toBe(2);
  });

  it("filters by search text", () => {
    const { filteredRules, filters } = nav(createRules());
    filters.value.search = "001";
    expect(filteredRules.value.length).toBe(1);
    expect(filteredRules.value[0].rule_id).toBe("001");
  });

  it("filters by a checked status in the vocabulary map", () => {
    const { filteredRules, filters } = nav(createRules());
    filters.value.statusFilters["Not Yet Determined"] = true;
    expect(filteredRules.value.length).toBe(1);
    expect(filteredRules.value[0].status).toBe("Not Yet Determined");
  });

  it("hasActiveFilters is false when no filters are checked", () => {
    const { hasActiveFilters } = nav(createRules());
    expect(hasActiveFilters.value).toBe(false);
  });

  it("hasActiveFilters is true when a status filter is checked", () => {
    const { hasActiveFilters, filters } = nav(createRules());
    filters.value.statusFilters["Applicable - Configurable"] = true;
    expect(hasActiveFilters.value).toBe(true);
  });

  it("clearFilters resets all filter state to defaults", () => {
    const { filters, clearFilters } = nav(createRules());
    filters.value.statusFilters["Applicable - Configurable"] = true;
    filters.value.search = "test";
    clearFilters();
    expect(filters.value.statusFilters["Applicable - Configurable"]).toBe(false);
    expect(filters.value.search).toBe("");
  });

  it("removeFilter clears a status filter by its status value", () => {
    const { filters, removeFilter } = nav(createRules());
    filters.value.statusFilters["Applicable - Configurable"] = true;
    filters.value.statusFilters["Not Applicable"] = true;
    removeFilter("Applicable - Configurable");
    expect(filters.value.statusFilters["Applicable - Configurable"]).toBe(false);
    expect(filters.value.statusFilters["Not Applicable"]).toBe(true);
  });

  it("removeFilter clears a named (kind-free) filter key", () => {
    const { filters, removeFilter } = nav(createRules());
    filters.value.lckFilterChecked = true;
    removeFilter("lckFilterChecked");
    expect(filters.value.lckFilterChecked).toBe(false);
  });

  it("removeFilter clears search when key is 'search'", () => {
    const { filters, removeFilter } = nav(createRules());
    filters.value.search = "test";
    removeFilter("search");
    expect(filters.value.search).toBe("");
  });

  it("accepts external filters (new shape) and uses them instead of local", () => {
    const external = ref(getDefaultFilters(STIG_STATUSES));
    external.value.statusFilters["Applicable - Configurable"] = true;
    const { filteredRules } = nav(createRules(), external);
    expect(filteredRules.value.length).toBe(1);
    expect(filteredRules.value[0].status).toBe("Applicable - Configurable");
  });

  describe("localStorage persistence", () => {
    it("persists and restores the statusFilters map (new shape)", async () => {
      const first = nav(createRules());
      first.filters.value.statusFilters["Not Applicable"] = true;
      first.filters.value.search = "00";
      await nextTick(); // the persistence watcher flushes on the next tick
      // A second instance for the same component restores the saved state.
      const second = nav(createRules());
      expect(second.filters.value.statusFilters["Not Applicable"]).toBe(true);
      expect(second.filters.value.search).toBe("00");
    });

    it("restores EVERY display toggle, none silently excluded", async () => {
      // The allowlist used to be hand-maintained and omitted openCommentsOnly,
      // so that one toggle alone reset on reload while its siblings survived.
      // The registry now declares persistence, so an omission is impossible
      // without editing the declaration itself.
      const first = nav(createRules());
      first.filters.value.openCommentsOnly = true;
      first.filters.value.showSRGIdChecked = true;
      first.filters.value.sortBySRGIdChecked = false;
      first.filters.value.nestSatisfiedRulesChecked = false;
      await nextTick();

      const second = nav(createRules());
      expect(second.filters.value.openCommentsOnly).toBe(true);
      expect(second.filters.value.showSRGIdChecked).toBe(true);
      expect(second.filters.value.sortBySRGIdChecked).toBe(false);
      expect(second.filters.value.nestSatisfiedRulesChecked).toBe(false);
    });

    it("migrates the LEGACY five-boolean saved shape to statusFilters", () => {
      localStorage.setItem(
        "ruleNavigatorFilters-41",
        JSON.stringify({
          search: "leg",
          acFilterChecked: true,
          nydFilterChecked: true,
          aimFilterChecked: false,
          lckFilterChecked: true,
          showSRGIdChecked: true,
        }),
      );
      const { filters } = nav(createRules());
      expect(filters.value.statusFilters["Applicable - Configurable"]).toBe(true);
      expect(filters.value.statusFilters["Not Yet Determined"]).toBe(true);
      expect(filters.value.statusFilters["Applicable - Inherently Meets"]).toBe(false);
      expect(filters.value.lckFilterChecked).toBe(true);
      expect(filters.value.showSRGIdChecked).toBe(true);
      expect(filters.value.search).toBe("leg");
      expect(filters.value.acFilterChecked).toBeUndefined();
    });

    it("ignores saved statuses outside the current vocabulary (SRG page, stale STIG save)", () => {
      localStorage.setItem(
        "ruleNavigatorFilters-41",
        JSON.stringify({ statusFilters: { "Applicable - Configurable": true, Applicable: true } }),
      );
      const { filters } = nav(createRules(), null, SRG_STATUSES);
      expect(Object.keys(filters.value.statusFilters)).toEqual(SRG_STATUSES);
      expect(filters.value.statusFilters.Applicable).toBe(true);
    });
  });

  describe("SRG-ID sort reads the served identifier, not a second field", () => {
    // The sidebar DISPLAYS rule.srg_id and used to SORT on rule.version —
    // two fields for one concept, agreeing only because the data happened
    // to make them agree. The server now answers the question once and
    // serves it as srg_id; the client consumes that one field for both.
    const divergent = () =>
      ref([
        {
          id: 1,
          rule_id: "001",
          // Chosen so the two orderings DISAGREE: by version this row sorts
          // FIRST, by SRG identifier it sorts LAST. A fixture where both
          // agree would pass against either implementation and prove nothing.
          version: "SV-111",
          srg_id: "SRG-OS-000900",
          status: "Applicable - Configurable",
          satisfies: [],
          satisfied_by: [],
          locked: false,
          review_requestor_id: null,
          checks_attributes: [],
          disa_rule_descriptions_attributes: [],
          comment_summary: null,
        },
        {
          id: 2,
          rule_id: "002",
          version: "SV-999",
          srg_id: "SRG-OS-000100",
          status: "Applicable - Configurable",
          satisfies: [],
          satisfied_by: [],
          locked: false,
          review_requestor_id: null,
          checks_attributes: [],
          disa_rule_descriptions_attributes: [],
          comment_summary: null,
        },
      ]);

    it("orders by the SRG identifier when it disagrees with the row's own version", () => {
      const { filteredRules, filters } = nav(divergent());
      filters.value.sortBySRGIdChecked = true;
      // By srg_id: SRG-OS-000100 (id 2) before SRG-OS-000900 (id 1).
      // By version it would be the reverse: SV-111 before SV-999.
      expect(filteredRules.value.map((r) => r.id)).toEqual([2, 1]);
    });
  });

  describe("SRG-ID sort with a null identifier (net-new authored requirement)", () => {
    it("sorts without throwing and places null-identifier rows last", () => {
      // The null row is supplied FIRST so a pass proves the sort actually
      // moved it; if both rows lacked an identifier the comparator would
      // return 0 and the assertion would hold no matter what the code did.
      const srgRules = ref([
        {
          // A net-new authored requirement corresponds to no SRG
          // requirement — its identifier is honestly null and must never
          // crash the sort.
          id: 2,
          rule_id: "000004",
          version: null,
          srg_id: null,
          status: "Not Yet Determined",
          locked: false,
          review_requestor_id: null,
          comment_summary: null,
        },
        {
          id: 1,
          rule_id: "000001",
          version: "SRG-R-905001",
          srg_id: "SRG-R-905001",
          status: "Applicable",
          locked: false,
          review_requestor_id: null,
          comment_summary: null,
        },
      ]);
      const { filters, filteredRules } = nav(srgRules, null, SRG_STATUSES);
      filters.value.sortBySRGIdChecked = true;

      expect(filteredRules.value.map((r) => r.id)).toEqual([1, 2]);
    });
  });

  describe("filtering requirements relocated from the retired second pipeline", () => {
    // These requirements were covered against a duplicate filtering pipeline
    // that lived in useRuleFilters, was never consumed by any page, and
    // matched search differently from this one. The duplicate is gone; the
    // requirements it protected belong here, on the pipeline the pages
    // actually render from.
    const reviewRules = () =>
      ref([
        {
          id: 1,
          rule_id: "001",
          version: "SV-1",
          status: "Applicable - Configurable",
          satisfies: [],
          satisfied_by: [],
          locked: false,
          review_requestor_id: null,
          checks_attributes: [],
          disa_rule_descriptions_attributes: [],
          comment_summary: null,
        },
        {
          id: 2,
          rule_id: "002",
          version: "SV-2",
          status: "Applicable - Configurable",
          satisfies: [],
          satisfied_by: [],
          locked: true,
          review_requestor_id: null,
          checks_attributes: [],
          disa_rule_descriptions_attributes: [],
          comment_summary: null,
        },
        {
          id: 3,
          rule_id: "003",
          version: "SV-3",
          status: "Not Applicable",
          satisfies: [],
          satisfied_by: [],
          locked: false,
          review_requestor_id: 7,
          checks_attributes: [],
          disa_rule_descriptions_attributes: [],
          comment_summary: null,
        },
      ]);

    it("shows only locked rules when the locked review filter is checked", () => {
      const { filteredRules, filters } = nav(reviewRules());
      filters.value.lckFilterChecked = true;
      expect(filteredRules.value.map((r) => r.id)).toEqual([2]);
    });

    it("shows only under-review rules when that review filter is checked", () => {
      const { filteredRules, filters } = nav(reviewRules());
      filters.value.urFilterChecked = true;
      expect(filteredRules.value.map((r) => r.id)).toEqual([3]);
    });

    it("shows only not-under-review rules when that review filter is checked", () => {
      const { filteredRules, filters } = nav(reviewRules());
      filters.value.nurFilterChecked = true;
      expect(filteredRules.value.map((r) => r.id)).toEqual([1]);
    });

    it("combines a status filter with a search term", () => {
      const { filteredRules, filters } = nav(reviewRules());
      filters.value.statusFilters["Applicable - Configurable"] = true;
      filters.value.search = "TEST-002";
      expect(filteredRules.value.map((r) => r.id)).toEqual([2]);
    });

    it("never status-filters a rule whose status is outside the vocabulary", () => {
      const odd = ref([
        {
          id: 9,
          rule_id: "009",
          version: "SV-9",
          status: "Mystery",
          satisfies: [],
          satisfied_by: [],
          locked: false,
          review_requestor_id: null,
          checks_attributes: [],
          disa_rule_descriptions_attributes: [],
          comment_summary: null,
        },
        {
          id: 10,
          rule_id: "010",
          version: "SV-10",
          status: "Not Applicable",
          satisfies: [],
          satisfied_by: [],
          locked: false,
          review_requestor_id: null,
          checks_attributes: [],
          disa_rule_descriptions_attributes: [],
          comment_summary: null,
        },
      ]);
      const { filteredRules, filters } = nav(odd);
      filters.value.statusFilters["Not Applicable"] = true;
      // Order is the sort's business, not this requirement's: what matters
      // is that the out-of-vocabulary row survives the status filter.
      expect(filteredRules.value.map((r) => r.id).sort((a, b) => a - b)).toEqual([9, 10]);
    });
  });

  describe("SRG vocabulary leak regression", () => {
    it("SRG navigation state carries exactly the SRG statuses — no STIG-only strings", () => {
      // Authentic authored-row shape: NO satisfies/satisfied_by/checks keys —
      // the kind-shaped payload omits Rule-only associations entirely.
      const srgRules = ref([
        {
          id: 1,
          rule_id: "S-1",
          version: "SRG-OS-000001",
          status: "Applicable",
          locked: false,
          review_requestor_id: null,
          comment_summary: null,
        },
      ]);
      const { filters, filteredRules } = nav(srgRules, null, SRG_STATUSES);
      expect(Object.keys(filters.value.statusFilters)).toEqual(SRG_STATUSES);
      expect(JSON.stringify(filters.value)).not.toContain("Applicable - ");
      filters.value.statusFilters.Applicable = true;
      expect(filteredRules.value.length).toBe(1);
    });
  });
});
