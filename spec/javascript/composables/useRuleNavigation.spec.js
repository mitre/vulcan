import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { ref } from "vue";
import { useRuleNavigation } from "@/composables/useRuleNavigation";

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
 * This composable is used by BOTH the sidebar header (search + pills)
 * and the sidebar body (rule list) via the consumer component.
 */
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

  beforeEach(() => {
    localStorage.clear();
  });

  afterEach(() => {
    localStorage.clear();
  });

  it("returns all rules when no filters are active (additive model)", () => {
    const rules = createRules();
    const { filteredRules } = useRuleNavigation(rules, "TEST", 41);
    expect(filteredRules.value.length).toBe(2);
  });

  it("filters by search text", () => {
    const rules = createRules();
    const { filteredRules, filters } = useRuleNavigation(rules, "TEST", 41);
    filters.value.search = "001";
    expect(filteredRules.value.length).toBe(1);
    expect(filteredRules.value[0].rule_id).toBe("001");
  });

  it("hasActiveFilters is false when no filters are checked", () => {
    const rules = createRules();
    const { hasActiveFilters } = useRuleNavigation(rules, "TEST", 41);
    expect(hasActiveFilters.value).toBe(false);
  });

  it("hasActiveFilters is true when a status filter is checked", () => {
    const rules = createRules();
    const { hasActiveFilters, filters } = useRuleNavigation(rules, "TEST", 41);
    filters.value.acFilterChecked = true;
    expect(hasActiveFilters.value).toBe(true);
  });

  it("clearFilters resets all filter state to defaults", () => {
    const rules = createRules();
    const { filters, clearFilters } = useRuleNavigation(rules, "TEST", 41);
    filters.value.acFilterChecked = true;
    filters.value.search = "test";
    clearFilters();
    expect(filters.value.acFilterChecked).toBe(false);
    expect(filters.value.search).toBe("");
  });

  it("removeFilter clears a specific filter key", () => {
    const rules = createRules();
    const { filters, removeFilter } = useRuleNavigation(rules, "TEST", 41);
    filters.value.acFilterChecked = true;
    filters.value.naFilterChecked = true;
    removeFilter("acFilterChecked");
    expect(filters.value.acFilterChecked).toBe(false);
    expect(filters.value.naFilterChecked).toBe(true);
  });

  it("removeFilter clears search when key is 'search'", () => {
    const rules = createRules();
    const { filters, removeFilter } = useRuleNavigation(rules, "TEST", 41);
    filters.value.search = "test";
    removeFilter("search");
    expect(filters.value.search).toBe("");
  });

  it("accepts external filters and uses them instead of local", () => {
    const rules = createRules();
    const externalFilters = ref({
      search: "",
      acFilterChecked: true,
      aimFilterChecked: false,
      adnmFilterChecked: false,
      naFilterChecked: false,
      nydFilterChecked: false,
      nurFilterChecked: false,
      urFilterChecked: false,
      lckFilterChecked: false,
      nestSatisfiedRulesChecked: true,
      showSRGIdChecked: false,
      sortBySRGIdChecked: true,
      openCommentsOnly: false,
    });
    const { filteredRules } = useRuleNavigation(rules, "TEST", 41, externalFilters);
    expect(filteredRules.value.length).toBe(1);
    expect(filteredRules.value[0].status).toBe("Applicable - Configurable");
  });
});
