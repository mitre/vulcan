import { ref, computed } from "vue";

/**
 * Default filter state, built from the page's statuses vocabulary.
 *
 * `statusFilters` is a map keyed by status value (vocabulary order) — the
 * composable never hardcodes a status name, so STIG pages get five entries
 * and SRG pages three from the same code. Review filters and display
 * toggles are kind-free named keys.
 *
 * Additive model: unchecked = no filter (show all). Per NNG, Baymard,
 * Carbon Design System: check to narrow, not uncheck to hide.
 *
 * @param {Array<string>} statuses - the page's status vocabulary
 */
export function getDefaultFilters(statuses) {
  const statusFilters = {};
  for (const status of statuses) {
    statusFilters[status] = false;
  }
  return {
    search: "",
    statusFilters,
    // Review filters — same additive model
    nurFilterChecked: false,
    urFilterChecked: false,
    lckFilterChecked: false,
    // Display options (these are toggles, not filters — keep enabled defaults)
    nestSatisfiedRulesChecked: true,
    showSRGIdChecked: false,
    sortBySRGIdChecked: true,
    openCommentsOnly: false,
  };
}

/**
 * Composable for managing rule filter state.
 *
 * @param {Ref<Array>} rules - Reactive ref containing array of rule objects
 * @param {number} componentId - Component ID (for potential persistence)
 * @param {Array<string>} statuses - the page's status vocabulary
 * @returns {Object} Filter state and methods
 */
export function useRuleFilters(rules, componentId, statuses) {
  // State
  const filters = ref(getDefaultFilters(statuses));

  // Computed: Rule status counts, keyed by status value
  const counts = computed(() => {
    const statusCounts = {};
    for (const status of statuses) {
      statusCounts[status] = 0;
    }
    let nur = 0,
      ur = 0,
      lck = 0;

    for (const rule of rules.value) {
      if (rule.status in statusCounts) statusCounts[rule.status]++;

      // Review counts
      if (rule.locked) lck++;
      else if (rule.review_requestor_id) ur++;
      else nur++;
    }

    return { statusCounts, nur, ur, lck };
  });

  const anyStatusFilterActive = computed(() => {
    return Object.values(filters.value.statusFilters).some(Boolean);
  });

  const anyReviewFilterActive = computed(() => {
    return (
      filters.value.nurFilterChecked ||
      filters.value.urFilterChecked ||
      filters.value.lckFilterChecked
    );
  });

  // Computed: Filtered rules based on current filter state
  // Additive model: no filters checked = show all (per NNG/Baymard/Carbon)
  const filteredRules = computed(() => {
    return rules.value.filter((rule) => {
      // Status filter — skip when no status filters are active (show all).
      // A rule whose status is outside the vocabulary is never status-filtered.
      if (anyStatusFilterActive.value) {
        if (
          rule.status in filters.value.statusFilters &&
          !filters.value.statusFilters[rule.status]
        ) {
          return false;
        }
      }

      // Review filter — skip when no review filters are active (show all)
      if (anyReviewFilterActive.value) {
        if (rule.locked) {
          if (!filters.value.lckFilterChecked) return false;
        } else if (rule.review_requestor_id) {
          if (!filters.value.urFilterChecked) return false;
        } else if (!filters.value.nurFilterChecked) {
          return false;
        }
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
    return Object.values(filters.value.statusFilters).every(Boolean);
  });

  // Computed: Are all review filters enabled?
  const allReviewFiltersEnabled = computed(() => {
    return (
      filters.value.nurFilterChecked &&
      filters.value.urFilterChecked &&
      filters.value.lckFilterChecked
    );
  });

  const activeFilterCount = computed(() => {
    const f = filters.value;
    let count = Object.values(f.statusFilters).filter(Boolean).length;
    if (f.nurFilterChecked) count++;
    if (f.urFilterChecked) count++;
    if (f.lckFilterChecked) count++;
    if (f.search) count++;
    if (f.openCommentsOnly) count++;
    return count;
  });

  // Methods — a filter name is either a status value (statusFilters key)
  // or a kind-free named key. Status values can never collide with the
  // named keys, so the lookup order is safe.
  function toggleFilter(filterName) {
    if (filterName in filters.value.statusFilters) {
      filters.value.statusFilters[filterName] = !filters.value.statusFilters[filterName];
    } else if (filterName in filters.value) {
      filters.value[filterName] = !filters.value[filterName];
    }
  }

  function setFilter(filterName, value) {
    if (filterName in filters.value.statusFilters) {
      filters.value.statusFilters[filterName] = value;
    } else if (filterName in filters.value) {
      filters.value[filterName] = value;
    }
  }

  function resetFilters() {
    filters.value = getDefaultFilters(statuses);
  }

  return {
    // State
    filters,

    // Computed
    counts,
    filteredRules,
    allStatusFiltersEnabled,
    allReviewFiltersEnabled,
    activeFilterCount,

    // Methods
    toggleFilter,
    setFilter,
    resetFilters,
  };
}
