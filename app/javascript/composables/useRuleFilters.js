import { ref, computed } from "vue";

/**
 * Default filter state - all status/review filters enabled, display options disabled
 */
function getDefaultFilters() {
  return {
    search: "",
    // Status filters
    acFilterChecked: true, // Applicable - Configurable
    aimFilterChecked: true, // Applicable - Inherently Meets
    adnmFilterChecked: true, // Applicable - Does Not Meet
    naFilterChecked: true, // Not Applicable
    nydFilterChecked: true, // Not Yet Determined
    // Review filters
    nurFilterChecked: true, // Not Under Review
    urFilterChecked: true, // Under Review
    lckFilterChecked: true, // Locked
    // Display options
    nestSatisfiedRulesChecked: false,
    showSRGIdChecked: false,
    sortBySRGIdChecked: false,
  };
}

/**
 * Status value to filter key mapping
 */
const STATUS_FILTER_MAP = {
  "Applicable - Configurable": "acFilterChecked",
  "Applicable - Inherently Meets": "aimFilterChecked",
  "Applicable - Does Not Meet": "adnmFilterChecked",
  "Not Applicable": "naFilterChecked",
  "Not Yet Determined": "nydFilterChecked",
};

/**
 * Composable for managing rule filter state.
 *
 * @param {Ref<Array>} rules - Reactive ref containing array of rule objects
 * @param {number} componentId - Component ID (for potential persistence)
 * @returns {Object} Filter state and methods
 */
export function useRuleFilters(rules, componentId) {
  // State
  const filters = ref(getDefaultFilters());

  // Computed: Rule status counts
  const counts = computed(() => {
    let ac = 0,
      aim = 0,
      adnm = 0,
      na = 0,
      nyd = 0;
    let nur = 0,
      ur = 0,
      lck = 0;

    for (const rule of rules.value) {
      // Status counts
      if (rule.status === "Applicable - Configurable") ac++;
      else if (rule.status === "Applicable - Inherently Meets") aim++;
      else if (rule.status === "Applicable - Does Not Meet") adnm++;
      else if (rule.status === "Not Applicable") na++;
      else if (rule.status === "Not Yet Determined") nyd++;

      // Review counts
      if (rule.locked) lck++;
      else if (rule.review_requestor_id) ur++;
      else nur++;
    }

    return { ac, aim, adnm, na, nyd, nur, ur, lck };
  });

  // Computed: Filtered rules based on current filter state
  const filteredRules = computed(() => {
    return rules.value.filter((rule) => {
      // Status filter
      const statusFilterKey = STATUS_FILTER_MAP[rule.status];
      if (statusFilterKey && !filters.value[statusFilterKey]) {
        return false;
      }

      // Review filter
      if (rule.locked) {
        if (!filters.value.lckFilterChecked) return false;
      } else if (rule.review_requestor_id) {
        if (!filters.value.urFilterChecked) return false;
      } else {
        if (!filters.value.nurFilterChecked) return false;
      }

      // Search filter
      if (filters.value.search) {
        const searchLower = filters.value.search.toLowerCase();
        const ruleIdLower = (rule.rule_id || "").toLowerCase();
        if (!ruleIdLower.includes(searchLower)) {
          return false;
        }
      }

      return true;
    });
  });

  // Computed: Are all status filters enabled?
  const allStatusFiltersEnabled = computed(() => {
    return (
      filters.value.acFilterChecked &&
      filters.value.aimFilterChecked &&
      filters.value.adnmFilterChecked &&
      filters.value.naFilterChecked &&
      filters.value.nydFilterChecked
    );
  });

  // Computed: Are all review filters enabled?
  const allReviewFiltersEnabled = computed(() => {
    return (
      filters.value.nurFilterChecked &&
      filters.value.urFilterChecked &&
      filters.value.lckFilterChecked
    );
  });

  // Methods
  function toggleFilter(filterName) {
    if (filterName in filters.value) {
      filters.value[filterName] = !filters.value[filterName];
    }
  }

  function setFilter(filterName, value) {
    if (filterName in filters.value) {
      filters.value[filterName] = value;
    }
  }

  function resetFilters() {
    filters.value = getDefaultFilters();
  }

  return {
    // State
    filters,

    // Computed
    counts,
    filteredRules,
    allStatusFiltersEnabled,
    allReviewFiltersEnabled,

    // Methods
    toggleFilter,
    setFilter,
    resetFilters,
  };
}
