<template>
  <div id="scrolling-sidebar" ref="sidebar">
    <div class="mr-2">
      <RuleSearchBar
        ref="searchBar"
        :component-id="componentId"
        :project-prefix="projectPrefix"
        :rules="rules"
        :read-only="readOnly"
        :search-value="filters.search"
        @search-updated="onSearchUpdated"
        @clear-filters="clearFilters"
        @search-result-selected="onSearchResultSelected"
      />

      <ActiveFilterPills
        :filters="filters"
        @remove-filter="removeFilter"
        @clear-all="clearFilters"
      />

      <hr class="mt-2 mb-2" />

      <RuleList
        :filtered-rules="filteredRules"
        :all-rules="rules"
        :component-id="componentId"
        :project-prefix="projectPrefix"
        :read-only="readOnly"
        :nest-satisfied-rules-checked="filters.nestSatisfiedRulesChecked"
        :show-s-r-g-id-checked="filters.showSRGIdChecked"
        :has-active-filters="hasActiveFilters"
        @reset-filters="clearFilters"
      />
    </div>
  </div>
</template>

<script>
import RuleSearchBar from "./RuleSearchBar.vue";
import RuleList from "./RuleList.vue";
import ActiveFilterPills from "./ActiveFilterPills.vue";
import { getDefaultFilters } from "../../composables/useRuleFilters";
import { useRuleSelectionStore } from "../../stores/ruleSelection";
import { scrollToField, searchTextForRule } from "../../utils/searchHighlight";

export default {
  name: "RuleNavigator",
  components: { RuleSearchBar, RuleList, ActiveFilterPills },
  props: {
    effectivePermissions: {
      type: String,
      default: "",
    },
    componentId: {
      type: Number,
      required: true,
    },
    rules: {
      type: Array,
      required: true,
    },
    selectedRuleId: {
      type: Number,
      default: null,
    },
    projectPrefix: {
      type: String,
      required: true,
    },
    openRuleIds: {
      type: Array,
      default: () => [],
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
    externalFilters: {
      type: Object,
      default: null,
    },
  },
  setup() {
    const ruleStore = useRuleSelectionStore();
    return { ruleStore };
  },
  data() {
    return {
      localFilters: getDefaultFilters(),
    };
  },
  computed: {
    filters: {
      get() {
        return this.externalFilters || this.localFilters;
      },
      set(value) {
        if (!this.externalFilters) {
          this.localFilters = value;
        }
      },
    },
    filteredRules() {
      return this.filterRules(this.rules);
    },
    hasActiveFilters() {
      const f = this.filters;
      const anyStatus =
        f.acFilterChecked ||
        f.aimFilterChecked ||
        f.adnmFilterChecked ||
        f.naFilterChecked ||
        f.nydFilterChecked;
      const anyReview = f.nurFilterChecked || f.urFilterChecked || f.lckFilterChecked;
      const hasSearch = f.search.length > 0;
      return anyStatus || anyReview || hasSearch || f.openCommentsOnly;
    },
  },
  watch: {
    filters: {
      handler() {
        localStorage.setItem(
          `ruleNavigatorFilters-${this.componentId}`,
          JSON.stringify(this.filters),
        );
        localStorage.setItem(`showSRGIdChecked-${this.componentId}`, this.filters.showSRGIdChecked);
      },
      deep: true,
    },
  },
  mounted() {
    if (localStorage.getItem(`ruleNavigatorFilters-${this.componentId}`)) {
      try {
        const saved = JSON.parse(localStorage.getItem(`ruleNavigatorFilters-${this.componentId}`));
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
          if (key in saved) {
            this.filters[key] = saved[key];
          }
        });
        this.$nextTick(() => {
          if (this.$refs.searchBar) {
            this.$refs.searchBar.setSearchValue(this.filters.search);
          }
        });
      } catch (e) {
        localStorage.removeItem(`ruleNavigatorFilters-${this.componentId}`);
      }
    }
  },
  methods: {
    onSearchUpdated(newSearch) {
      this.filters.search = newSearch;
    },
    removeFilter(key) {
      if (key === "search") {
        this.filters.search = "";
        this.$nextTick(() => {
          if (this.$refs.searchBar) {
            this.$refs.searchBar.setSearchValue("");
          }
        });
      } else if (key in this.filters) {
        this.filters[key] = false;
      }
    },
    doesRuleHaveFilteredStatus(rule) {
      return (
        (!this.filters.acFilterChecked &&
          !this.filters.aimFilterChecked &&
          !this.filters.adnmFilterChecked &&
          !this.filters.naFilterChecked &&
          !this.filters.nydFilterChecked) ||
        (this.filters.acFilterChecked && rule.status == "Applicable - Configurable") ||
        (this.filters.aimFilterChecked && rule.status == "Applicable - Inherently Meets") ||
        (this.filters.adnmFilterChecked && rule.status == "Applicable - Does Not Meet") ||
        (this.filters.naFilterChecked && rule.status == "Not Applicable") ||
        (this.filters.nydFilterChecked && rule.status == "Not Yet Determined")
      );
    },
    doesRuleHaveFilteredReviewStatus(rule) {
      return (
        (!this.filters.nurFilterChecked &&
          !this.filters.urFilterChecked &&
          !this.filters.lckFilterChecked) ||
        (this.filters.nurFilterChecked && !rule.locked && !rule.review_requestor_id) ||
        (this.filters.urFilterChecked && !rule.locked && rule.review_requestor_id) ||
        (this.filters.lckFilterChecked && rule.locked)
      );
    },
    listSatisfiedRule(rule) {
      if (this.filters.nestSatisfiedRulesChecked) {
        return rule.satisfied_by.length === 0;
      }
      return true;
    },
    ruleOpen(rule) {
      let count = (rule.comment_summary && rule.comment_summary.open) || 0;
      if (rule.satisfies && rule.satisfies.length > 0) {
        for (const sat of rule.satisfies) {
          const child = this.rules.find((r) => r.id === sat.id);
          if (child && child.comment_summary) {
            count += child.comment_summary.open || 0;
          }
        }
      }
      return count;
    },
    filterRules(rules) {
      let sortedRules = [...rules];
      if (this.filters.sortBySRGIdChecked) {
        sortedRules.sort((a, b) => a.version.localeCompare(b.version));
      }

      const downcaseSearch = this.filters.search.toLowerCase();
      let filteredRules = sortedRules.filter((rule) => {
        return (
          searchTextForRule(this.projectPrefix, rule).includes(downcaseSearch) &&
          this.doesRuleHaveFilteredStatus(rule) &&
          this.doesRuleHaveFilteredReviewStatus(rule) &&
          this.listSatisfiedRule(rule) &&
          (!this.filters.openCommentsOnly || this.ruleOpen(rule) > 0)
        );
      });

      if (this.filters.nestSatisfiedRulesChecked) {
        const parents = filteredRules.filter((rule) => rule.satisfies.length > 0);
        const leaves = filteredRules.filter((rule) => rule.satisfies.length === 0);
        filteredRules = [...parents, ...leaves];
      }

      return filteredRules;
    },
    onSearchResultSelected(result) {
      const rule = this.rules.find((r) => r.id === result.id);
      if (rule) {
        if (!rule.histories) {
          this.$root.$emit("refresh:rule", rule.id);
        }
        this.ruleStore.selectRule(rule.id);
        if (result.matched_field) {
          this.$nextTick(() => {
            scrollToField(result.matched_field, result.searchQuery);
          });
        }
      }
    },
    clearFilters() {
      const defaults = getDefaultFilters();
      Object.keys(defaults).forEach((key) => {
        this.filters[key] = defaults[key];
      });
      this.$nextTick(() => {
        if (this.$refs.searchBar) {
          this.$refs.searchBar.setSearchValue("");
        }
      });
    },
  },
};
</script>

<style scoped>
#scrolling-sidebar {
  display: block;
  overflow-y: auto;
}

@media (max-width: 767.98px) {
  #scrolling-sidebar {
    max-height: 40vh !important;
  }
}
</style>

<style>
.search-field-highlight {
  animation: field-highlight-ring 2s ease-out;
}
@keyframes field-highlight-ring {
  0% {
    box-shadow: var(--vulcan-focus-ring-warning);
    border-radius: 4px;
  }
  100% {
    box-shadow: 0 0 0 0 transparent;
  }
}
.search-term-mark {
  background-color: var(--vulcan-warning-tint);
  color: var(--vulcan-warning-text);
  padding: 0 2px;
  border-radius: 2px;
  font-weight: 600;
}
</style>
