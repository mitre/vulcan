import { ref, computed, watch } from "vue";
import { ruleArray } from "../utils/ruleArray";
import { getDefaultFilters } from "./useRuleFilters";
import { persistedKeys } from "../constants/ruleFilterRegistry";
import { searchTextForRule } from "../utils/searchHighlight";

// LEGACY localStorage shim: saved filter state from the retired
// five-boolean shape maps onto the vocabulary-keyed statusFilters. This
// is user-state migration data (the old keys exist only in previously
// saved browser storage), not status control flow — remove once stale
// saves have aged out.
const LEGACY_SAVED_STATUS_KEYS = Object.freeze({
  acFilterChecked: "Applicable - Configurable",
  aimFilterChecked: "Applicable - Inherently Meets",
  adnmFilterChecked: "Applicable - Does Not Meet",
  naFilterChecked: "Not Applicable",
  nydFilterChecked: "Not Yet Determined",
});

// Which keys survive a reload is DECLARED in the registry, not restated
// here. This list was hand-maintained and silently omitted one toggle, so
// that toggle alone reset on every reload while its siblings persisted.

/**
 * Composable for sidebar navigation: filtering, sorting, searching rules.
 *
 * Enables the PanelLayout header/body slot pattern: both the pinned header
 * (search bar, pills) and scrollable body (rule list) access the same filter
 * state through this composable.
 *
 * Status filtering runs on the vocabulary-keyed `statusFilters` map — the
 * composable receives the page's statuses and never hardcodes a status.
 *
 * @param {Ref<Array>} rules - All rules for the component
 * @param {string} projectPrefix - Component prefix (e.g., "RHEL-09")
 * @param {number} componentId - Component ID (for localStorage key)
 * @param {Ref<Object>} [externalFilters] - Optional external filter state (from parent)
 * @param {Array<string>} statuses - the page's status vocabulary
 */
export function useRuleNavigation(rules, projectPrefix, componentId, externalFilters, statuses) {
  const localFilters = ref(getDefaultFilters(statuses));

  const filters = computed({
    get() {
      return externalFilters ? externalFilters.value : localFilters.value;
    },
    set(value) {
      if (!externalFilters) {
        localFilters.value = value;
      }
    },
  });

  const hasActiveFilters = computed(() => {
    const f = filters.value;
    const anyStatus = Object.values(f.statusFilters).some(Boolean);
    const anyReview = f.nurFilterChecked || f.urFilterChecked || f.lckFilterChecked;
    const hasSearch = f.search.length > 0;
    return anyStatus || anyReview || hasSearch || f.openCommentsOnly;
  });

  function doesRuleHaveFilteredStatus(rule) {
    const statusFilters = filters.value.statusFilters;
    const anyStatusActive = Object.values(statusFilters).some(Boolean);
    if (!anyStatusActive) return true;
    // A rule whose status is outside the vocabulary is never status-filtered.
    if (!(rule.status in statusFilters)) return true;
    return statusFilters[rule.status];
  }

  function doesRuleHaveFilteredReviewStatus(rule) {
    return (
      (!filters.value.nurFilterChecked &&
        !filters.value.urFilterChecked &&
        !filters.value.lckFilterChecked) ||
      (filters.value.nurFilterChecked && !rule.locked && !rule.review_requestor_id) ||
      (filters.value.urFilterChecked && !rule.locked && rule.review_requestor_id) ||
      (filters.value.lckFilterChecked && rule.locked)
    );
  }

  function ruleOpen(rule) {
    let count = (rule.comment_summary && rule.comment_summary.open) || 0;
    if (ruleArray(rule, "satisfies").length > 0) {
      for (const sat of ruleArray(rule, "satisfies")) {
        const child = rules.value.find((r) => r.id === sat.id);
        if (child && child.comment_summary) {
          count += child.comment_summary.open || 0;
        }
      }
    }
    return count;
  }

  const filteredRules = computed(() => {
    let sortedRules = [...rules.value];
    if (filters.value.sortBySRGIdChecked) {
      // Sort on the SAME value the sidebar displays: srg_id, which the
      // server answers once per document kind. Sorting on the row's own
      // version was a second derivation of one concept — it agreed with
      // the display only while the data happened to make it agree.
      //
      // Net-new authored requirements correspond to no SRG requirement —
      // the identifier is honestly null; sort them last (the backend's
      // canonical NULLs-last order), never crash the pipeline.
      sortedRules.sort((a, b) => {
        if (a.srg_id == null) return b.srg_id == null ? 0 : 1;
        if (b.srg_id == null) return -1;
        return a.srg_id.localeCompare(b.srg_id);
      });
    }

    const downcaseSearch = filters.value.search.toLowerCase();
    let result = sortedRules.filter((rule) => {
      return (
        searchTextForRule(projectPrefix, rule).includes(downcaseSearch) &&
        doesRuleHaveFilteredStatus(rule) &&
        doesRuleHaveFilteredReviewStatus(rule) &&
        (filters.value.nestSatisfiedRulesChecked
          ? ruleArray(rule, "satisfied_by").length === 0
          : true) &&
        (!filters.value.openCommentsOnly || ruleOpen(rule) > 0)
      );
    });

    if (filters.value.nestSatisfiedRulesChecked) {
      const parents = result.filter((rule) => ruleArray(rule, "satisfies").length > 0);
      const leaves = result.filter((rule) => ruleArray(rule, "satisfies").length === 0);
      result = [...parents, ...leaves];
    }

    return result;
  });

  function clearFilters() {
    const defaults = getDefaultFilters(statuses);
    Object.keys(defaults).forEach((key) => {
      filters.value[key] = defaults[key];
    });
  }

  function removeFilter(key) {
    if (key === "search") {
      filters.value.search = "";
    } else if (key in filters.value.statusFilters) {
      filters.value.statusFilters[key] = false;
    } else if (key in filters.value) {
      filters.value[key] = false;
    }
  }

  function onSearchUpdated(newSearch) {
    filters.value.search = newSearch;
  }

  // localStorage persistence
  watch(
    filters,
    () => {
      localStorage.setItem(`ruleNavigatorFilters-${componentId}`, JSON.stringify(filters.value));
      localStorage.setItem(`showSRGIdChecked-${componentId}`, filters.value.showSRGIdChecked);
    },
    { deep: true },
  );

  // Restore from localStorage on init
  const saved = localStorage.getItem(`ruleNavigatorFilters-${componentId}`);
  if (saved) {
    try {
      const parsed = JSON.parse(saved);
      for (const key of persistedKeys()) {
        if (key in parsed) {
          filters.value[key] = parsed[key];
        }
      }
      // New shape: only statuses in the current vocabulary restore.
      if (parsed.statusFilters) {
        for (const [status, checked] of Object.entries(parsed.statusFilters)) {
          if (status in filters.value.statusFilters) {
            filters.value.statusFilters[status] = checked;
          }
        }
      }
      // Legacy shape: migrate saved five-boolean keys onto the map.
      for (const [legacyKey, status] of Object.entries(LEGACY_SAVED_STATUS_KEYS)) {
        if (legacyKey in parsed && status in filters.value.statusFilters) {
          filters.value.statusFilters[status] = parsed[legacyKey];
        }
      }
    } catch {
      localStorage.removeItem(`ruleNavigatorFilters-${componentId}`);
    }
  }

  return {
    filters,
    filteredRules,
    hasActiveFilters,
    clearFilters,
    removeFilter,
    onSearchUpdated,
    ruleOpen,
  };
}
