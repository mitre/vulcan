/**
 * REQUIREMENTS — vocabulary-driven filter model (kind-aware):
 *
 * Status filters are a `statusFilters` map keyed by the page's statuses
 * vocabulary — never named per-status booleans. STIG pages get five
 * entries, SRG pages three; the composable never hardcodes a status.
 * Review filters (not-under-review / under-review / locked) and display
 * toggles are kind-free and keep their named keys. Additive model
 * throughout: unchecked = no filter (show all).
 */
import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { ref } from "vue";
import { useRuleFilters, getDefaultFilters } from "@/composables/useRuleFilters";

const STIG_STATUSES = [
  "Not Yet Determined",
  "Applicable - Configurable",
  "Applicable - Inherently Meets",
  "Applicable - Does Not Meet",
  "Not Applicable",
];

const SRG_STATUSES = ["Not Yet Determined", "Applicable", "Not Applicable"];

describe("useRuleFilters", () => {
  const mockRules = ref([
    {
      id: 1,
      rule_id: "CNTR-00-000010",
      status: "Applicable - Configurable",
      locked: false,
      review_requestor_id: null,
    },
    {
      id: 2,
      rule_id: "CNTR-00-000020",
      status: "Applicable - Configurable",
      locked: true,
      review_requestor_id: null,
    },
    {
      id: 3,
      rule_id: "CNTR-00-000030",
      status: "Applicable - Inherently Meets",
      locked: false,
      review_requestor_id: null,
    },
    {
      id: 4,
      rule_id: "CNTR-00-000040",
      status: "Applicable - Does Not Meet",
      locked: false,
      review_requestor_id: 5,
    },
    {
      id: 5,
      rule_id: "CNTR-00-000050",
      status: "Not Applicable",
      locked: false,
      review_requestor_id: null,
    },
    {
      id: 6,
      rule_id: "CNTR-00-000060",
      status: "Not Yet Determined",
      locked: false,
      review_requestor_id: null,
    },
  ]);

  const componentId = 41;
  const make = (rules = mockRules, statuses = STIG_STATUSES) =>
    useRuleFilters(rules, componentId, statuses);

  beforeEach(() => {
    localStorage.clear();
    vi.clearAllMocks();
  });

  afterEach(() => {
    localStorage.clear();
  });

  describe("getDefaultFilters(statuses)", () => {
    it("builds statusFilters from the vocabulary, all unchecked, in vocabulary order", () => {
      const defaults = getDefaultFilters(STIG_STATUSES);
      expect(Object.keys(defaults.statusFilters)).toEqual(STIG_STATUSES);
      expect(Object.values(defaults.statusFilters)).toEqual([false, false, false, false, false]);
    });

    it("builds the SRG shape from the SRG vocabulary — no STIG keys anywhere", () => {
      const defaults = getDefaultFilters(SRG_STATUSES);
      expect(Object.keys(defaults.statusFilters)).toEqual(SRG_STATUSES);
      expect(JSON.stringify(defaults)).not.toContain("Applicable - Configurable");
      expect(defaults.acFilterChecked).toBeUndefined();
      expect(defaults.nydFilterChecked).toBeUndefined();
    });

    it("keeps kind-free review filters and display toggles with their named keys", () => {
      const defaults = getDefaultFilters(STIG_STATUSES);
      expect(defaults.nurFilterChecked).toBe(false);
      expect(defaults.urFilterChecked).toBe(false);
      expect(defaults.lckFilterChecked).toBe(false);
      expect(defaults.nestSatisfiedRulesChecked).toBe(true);
      expect(defaults.showSRGIdChecked).toBe(false);
      expect(defaults.sortBySRGIdChecked).toBe(true);
      expect(defaults.openCommentsOnly).toBe(false);
      expect(defaults.search).toBe("");
    });
  });

  describe("initialization", () => {
    it("initializes with all status filters unchecked (additive model — no filter = show all)", () => {
      const { filters } = make();
      STIG_STATUSES.forEach((status) => {
        expect(filters.value.statusFilters[status]).toBe(false);
      });
    });

    it("initializes with all review filters unchecked (additive model)", () => {
      const { filters } = make();
      expect(filters.value.nurFilterChecked).toBe(false);
      expect(filters.value.urFilterChecked).toBe(false);
      expect(filters.value.lckFilterChecked).toBe(false);
    });

    it("initializes with display options (nest + sort by SRG enabled, show SRG ID disabled)", () => {
      const { filters } = make();
      expect(filters.value.nestSatisfiedRulesChecked).toBe(true);
      expect(filters.value.sortBySRGIdChecked).toBe(true);
      expect(filters.value.showSRGIdChecked).toBe(false);
    });

    it("initializes with empty search", () => {
      const { filters } = make();
      expect(filters.value.search).toBe("");
    });
  });

  describe("counts", () => {
    it("computes status counts keyed by status value", () => {
      const { counts } = make();
      expect(counts.value.statusCounts).toEqual({
        "Not Yet Determined": 1,
        "Applicable - Configurable": 2,
        "Applicable - Inherently Meets": 1,
        "Applicable - Does Not Meet": 1,
        "Not Applicable": 1,
      });
    });

    it("computes review counts correctly", () => {
      const { counts } = make();
      expect(counts.value.nur).toBe(4);
      expect(counts.value.ur).toBe(1);
      expect(counts.value.lck).toBe(1);
    });

    it("updates counts when rules change", () => {
      const rules = ref([
        {
          id: 1,
          rule_id: "X-1",
          status: "Not Applicable",
          locked: false,
          review_requestor_id: null,
        },
      ]);
      const { counts } = make(rules);
      expect(counts.value.statusCounts["Not Applicable"]).toBe(1);
      rules.value = [
        ...rules.value,
        {
          id: 2,
          rule_id: "X-2",
          status: "Not Applicable",
          locked: false,
          review_requestor_id: null,
        },
      ];
      expect(counts.value.statusCounts["Not Applicable"]).toBe(2);
    });

    it("counts SRG statuses under the SRG vocabulary", () => {
      const srgRules = ref([
        { id: 1, rule_id: "S-1", status: "Applicable", locked: false, review_requestor_id: null },
        {
          id: 2,
          rule_id: "S-2",
          status: "Not Yet Determined",
          locked: false,
          review_requestor_id: null,
        },
      ]);
      const { counts } = make(srgRules, SRG_STATUSES);
      expect(counts.value.statusCounts).toEqual({
        "Not Yet Determined": 1,
        Applicable: 1,
        "Not Applicable": 0,
      });
    });
  });

  describe("toggleFilter / setFilter", () => {
    it("toggles a status filter by its status value", () => {
      const { filters, toggleFilter } = make();
      toggleFilter("Applicable - Configurable");
      expect(filters.value.statusFilters["Applicable - Configurable"]).toBe(true);
      toggleFilter("Applicable - Configurable");
      expect(filters.value.statusFilters["Applicable - Configurable"]).toBe(false);
    });

    it("toggles a named (kind-free) filter", () => {
      const { filters, toggleFilter } = make();
      toggleFilter("nestSatisfiedRulesChecked");
      expect(filters.value.nestSatisfiedRulesChecked).toBe(false);
    });

    it("sets a status filter and a named filter to specific values", () => {
      const { filters, setFilter } = make();
      setFilter("Not Applicable", true);
      expect(filters.value.statusFilters["Not Applicable"]).toBe(true);
      setFilter("search", "CNTR");
      expect(filters.value.search).toBe("CNTR");
    });
  });

  describe("resetFilters", () => {
    it("resets all filters to defaults (all unchecked)", () => {
      const { filters, toggleFilter, resetFilters } = make();
      toggleFilter("Applicable - Configurable");
      toggleFilter("lckFilterChecked");
      resetFilters();
      expect(filters.value.statusFilters["Applicable - Configurable"]).toBe(false);
      expect(filters.value.lckFilterChecked).toBe(false);
      expect(Object.keys(filters.value.statusFilters)).toEqual(STIG_STATUSES);
    });
  });

  describe("filteredRules (additive model)", () => {
    it("returns all rules when nothing is checked", () => {
      const { filteredRules } = make();
      expect(filteredRules.value.length).toBe(6);
    });

    it("filters by status (check one status to show only it)", () => {
      const { filteredRules, setFilter } = make();
      setFilter("Applicable - Configurable", true);
      expect(filteredRules.value.map((r) => r.id)).toEqual([1, 2]);
    });

    it("filters by review status (check locked to show only locked)", () => {
      const { filteredRules, setFilter } = make();
      setFilter("lckFilterChecked", true);
      expect(filteredRules.value.map((r) => r.id)).toEqual([2]);
    });

    it("filters by review status (check under review to show only UR)", () => {
      const { filteredRules, setFilter } = make();
      setFilter("urFilterChecked", true);
      expect(filteredRules.value.map((r) => r.id)).toEqual([4]);
    });

    it("filters by search term (rule_id), case insensitive", () => {
      const { filteredRules, setFilter } = make();
      setFilter("search", "cntr-00-000030");
      expect(filteredRules.value.map((r) => r.id)).toEqual([3]);
    });

    it("combines status and search filters", () => {
      const { filteredRules, setFilter } = make();
      setFilter("Applicable - Configurable", true);
      setFilter("search", "CNTR-00-000020");
      expect(filteredRules.value.map((r) => r.id)).toEqual([2]);
    });

    it("a rule whose status is outside the vocabulary is never filtered out by status filters", () => {
      const rules = ref([
        { id: 9, rule_id: "ODD-1", status: "Mystery", locked: false, review_requestor_id: null },
        {
          id: 10,
          rule_id: "ODD-2",
          status: "Not Applicable",
          locked: false,
          review_requestor_id: null,
        },
      ]);
      const { filteredRules, setFilter } = make(rules);
      setFilter("Not Applicable", true);
      expect(filteredRules.value.map((r) => r.id)).toEqual([9, 10]);
    });
  });

  describe("allStatusFiltersEnabled / activeFilterCount", () => {
    it("allStatusFiltersEnabled is true only when every vocabulary status is checked", () => {
      const { filters, allStatusFiltersEnabled, setFilter } = make();
      expect(allStatusFiltersEnabled.value).toBe(false);
      STIG_STATUSES.forEach((s) => setFilter(s, true));
      expect(allStatusFiltersEnabled.value).toBe(true);
      expect(filters.value.statusFilters["Not Applicable"]).toBe(true);
    });

    it("activeFilterCount counts checked status filters, review filters, search, and openCommentsOnly", () => {
      const { activeFilterCount, setFilter } = make();
      expect(activeFilterCount.value).toBe(0);
      setFilter("Applicable - Configurable", true);
      setFilter("lckFilterChecked", true);
      setFilter("search", "x");
      setFilter("openCommentsOnly", true);
      expect(activeFilterCount.value).toBe(4);
    });
  });

  describe("SRG vocabulary leak regression", () => {
    it("SRG statusFilters carry exactly the three SRG statuses — no STIG-only strings anywhere in state", () => {
      const srgRules = ref([
        { id: 1, rule_id: "S-1", status: "Applicable", locked: false, review_requestor_id: null },
      ]);
      const { filters, counts } = make(srgRules, SRG_STATUSES);
      expect(Object.keys(filters.value.statusFilters)).toEqual(SRG_STATUSES);
      const serialized = JSON.stringify(filters.value) + JSON.stringify(counts.value);
      ["Applicable - Configurable", "Inherently Meets", "Does Not Meet"].forEach((leak) => {
        expect(serialized).not.toContain(leak);
      });
    });

    it("SRG filtering works end-to-end on the SRG vocabulary", () => {
      const srgRules = ref([
        { id: 1, rule_id: "S-1", status: "Applicable", locked: false, review_requestor_id: null },
        {
          id: 2,
          rule_id: "S-2",
          status: "Not Applicable",
          locked: false,
          review_requestor_id: null,
        },
      ]);
      const { filteredRules, setFilter } = make(srgRules, SRG_STATUSES);
      setFilter("Applicable", true);
      expect(filteredRules.value.map((r) => r.id)).toEqual([1]);
    });
  });
});
