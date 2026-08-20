import { ref, computed } from "vue";
import { registryDefaults, countsAsActiveFilter } from "../constants/ruleFilterRegistry";

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
  // Every key, label, default, persistence flag and kind applicability lives
  // in the registry. Restating any of them here is what let the four
  // definition sites drift apart.
  return {
    search: "",
    ...registryDefaults(statuses),
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

  // NOTE: this composable owns filter STATE only. Deriving the visible rule
  // list belongs to useRuleNavigation, which the pages wire to this same
  // state ref. A second pipeline used to live here — unconsumed, and
  // matching search against rule_id alone while the live one matched the
  // broader search text — so the two silently disagreed. One pipeline.

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

  // Which keys narrow the list is declared in the registry, not restated
  // here — that judgement previously lived in two places that disagreed.
  const activeFilterCount = computed(() => {
    const f = filters.value;
    let count = Object.values(f.statusFilters).filter(Boolean).length;
    if (f.search) count++;
    Object.entries(f).forEach(([key, value]) => {
      if (key === "statusFilters" || key === "search") return;
      if (value === true && countsAsActiveFilter(key)) count++;
    });
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
    allStatusFiltersEnabled,
    allReviewFiltersEnabled,
    activeFilterCount,

    // Methods
    toggleFilter,
    setFilter,
    resetFilters,
  };
}
