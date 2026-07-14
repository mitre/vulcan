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
