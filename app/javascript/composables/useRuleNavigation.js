import { ref, computed, watch, onMounted } from "vue";
import { getDefaultFilters } from "./useRuleFilters";
import { searchTextForRule } from "../utils/searchHighlight";

/**
 * Composable for sidebar navigation: filtering, sorting, searching rules.
 *
 * Extracted from RuleNavigator to enable the PanelLayout header/body slot pattern.
 * Both the pinned header (search bar, pills) and scrollable body (rule list) access
 * the same filter state through this composable.
 *
 * @param {Ref<Array>} rules - All rules for the component
 * @param {string} projectPrefix - Component prefix (e.g., "RHEL-09")
 * @param {number} componentId - Component ID (for localStorage key)
 * @param {Ref<Object>} [externalFilters] - Optional external filter state (from parent)
 */
export function useRuleNavigation(rules, projectPrefix, componentId, externalFilters = null) {
  const localFilters = ref(getDefaultFilters());

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
    const anyStatus =
      f.acFilterChecked ||
      f.aimFilterChecked ||
      f.adnmFilterChecked ||
      f.naFilterChecked ||
      f.nydFilterChecked;
    const anyReview = f.nurFilterChecked || f.urFilterChecked || f.lckFilterChecked;
    const hasSearch = f.search.length > 0;
    return anyStatus || anyReview || hasSearch || f.openCommentsOnly;
  });

  function doesRuleHaveFilteredStatus(rule) {
    return (
      (!filters.value.acFilterChecked &&
        !filters.value.aimFilterChecked &&
        !filters.value.adnmFilterChecked &&
        !filters.value.naFilterChecked &&
        !filters.value.nydFilterChecked) ||
      (filters.value.acFilterChecked && rule.status == "Applicable - Configurable") ||
      (filters.value.aimFilterChecked && rule.status == "Applicable - Inherently Meets") ||
      (filters.value.adnmFilterChecked && rule.status == "Applicable - Does Not Meet") ||
      (filters.value.naFilterChecked && rule.status == "Not Applicable") ||
      (filters.value.nydFilterChecked && rule.status == "Not Yet Determined")
    );
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
    if (rule.satisfies && rule.satisfies.length > 0) {
      for (const sat of rule.satisfies) {
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
      sortedRules.sort((a, b) => a.version.localeCompare(b.version));
    }

    const downcaseSearch = filters.value.search.toLowerCase();
    let result = sortedRules.filter((rule) => {
      return (
        searchTextForRule(projectPrefix, rule).includes(downcaseSearch) &&
        doesRuleHaveFilteredStatus(rule) &&
        doesRuleHaveFilteredReviewStatus(rule) &&
        (filters.value.nestSatisfiedRulesChecked ? rule.satisfied_by.length === 0 : true) &&
        (!filters.value.openCommentsOnly || ruleOpen(rule) > 0)
      );
    });

    if (filters.value.nestSatisfiedRulesChecked) {
      const parents = result.filter((rule) => rule.satisfies.length > 0);
      const leaves = result.filter((rule) => rule.satisfies.length === 0);
      result = [...parents, ...leaves];
    }

    return result;
  });

  function clearFilters() {
    const defaults = getDefaultFilters();
    Object.keys(defaults).forEach((key) => {
      filters.value[key] = defaults[key];
    });
  }

  function removeFilter(key) {
    if (key === "search") {
      filters.value.search = "";
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
      const restorableKeys = [
        "search",
        "acFilterChecked",
        "aimFilterChecked",
        "adnmFilterChecked",
        "naFilterChecked",
        "nydFilterChecked",
        "nurFilterChecked",
        "urFilterChecked",
        "lckFilterChecked",
        "showSRGIdChecked",
        "sortBySRGIdChecked",
        "nestSatisfiedRulesChecked",
      ];
      restorableKeys.forEach((key) => {
        if (key in parsed && key in filters.value) {
          filters.value[key] = parsed[key];
        }
      });
    } catch (e) {
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
