<template>
  <div class="filter-bar d-flex flex-wrap justify-content-between">
    <!-- Status Group -->
    <FilterGroup
      v-if="showStatus"
      title="Status"
      :items="statusItems"
      :disabled="disabledStatus"
      @update:items="onGroupUpdate"
      @reset="onStatusReset"
    />

    <!-- Display Group -->
    <FilterGroup
      v-if="showDisplay"
      title="Display"
      :items="displayItems"
      :disabled="disabledDisplay"
      @update:items="onGroupUpdate"
      @reset="onDisplayReset"
    />

    <!-- Review Group (last - toggles on/off between modes) -->
    <FilterGroup
      v-if="showReview"
      title="Review"
      :items="reviewItems"
      :disabled="disabledReview"
      @update:items="onGroupUpdate"
      @reset="onReviewReset"
    />
  </div>
</template>

<script>
import FilterGroup from "./FilterGroup.vue";
import { getDefaultFilters } from "../../composables/useRuleFilters";

export default {
  name: "FilterBar",
  components: { FilterGroup },
  props: {
    filters: {
      type: Object,
      required: true,
    },
    counts: {
      type: Object,
      default: () => ({}),
    },
    showStatus: {
      type: Boolean,
      default: true,
    },
    showReview: {
      type: Boolean,
      default: true,
    },
    showDisplay: {
      type: Boolean,
      default: true,
    },
    disabledStatus: {
      type: Boolean,
      default: false,
    },
    disabledReview: {
      type: Boolean,
      default: false,
    },
    disabledDisplay: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    // Derived from the vocabulary-keyed statusFilters map — the bar renders
    // whatever statuses the page's kind provides, in vocabulary order.
    statusItems() {
      const statusCounts = this.counts.statusCounts || {};
      return Object.entries(this.filters.statusFilters).map(([status, checked]) => ({
        key: status,
        label: status,
        count: statusCounts[status],
        checked,
      }));
    },
    reviewItems() {
      return [
        {
          key: "nurFilterChecked",
          label: "Not Under Review",
          count: this.counts.nur,
          checked: this.filters.nurFilterChecked,
        },
        {
          key: "urFilterChecked",
          label: "Under Review",
          count: this.counts.ur,
          checked: this.filters.urFilterChecked,
        },
        {
          key: "lckFilterChecked",
          label: "Locked",
          count: this.counts.lck,
          checked: this.filters.lckFilterChecked,
        },
      ];
    },
    displayItems() {
      return [
        {
          key: "nestSatisfiedRulesChecked",
          label: "Nest Satisfied",
          checked: this.filters.nestSatisfiedRulesChecked,
        },
        {
          key: "showSRGIdChecked",
          label: "SRG ID",
          checked: this.filters.showSRGIdChecked,
        },
        {
          key: "sortBySRGIdChecked",
          label: "Sort SRG",
          checked: this.filters.sortBySRGIdChecked,
        },
        {
          key: "openCommentsOnly",
          label: "Open Comments Only",
          checked: this.filters.openCommentsOnly,
        },
      ];
    },
  },
  methods: {
    // An item key is either a status value (statusFilters key) or a
    // kind-free named key — status values can never collide with the
    // named keys, so routing by membership is safe.
    emitUpdatedFilters(updates) {
      const statusUpdates = {};
      const namedUpdates = {};
      Object.entries(updates).forEach(([key, value]) => {
        if (key in this.filters.statusFilters) {
          statusUpdates[key] = value;
        } else {
          namedUpdates[key] = value;
        }
      });
      const newFilters = {
        ...this.filters,
        ...namedUpdates,
        statusFilters: { ...this.filters.statusFilters, ...statusUpdates },
      };
      this.$emit("update:filters", newFilters);
    },
    onGroupUpdate(items) {
      const updates = {};
      items.forEach((item) => {
        updates[item.key] = item.checked;
      });
      this.emitUpdatedFilters(updates);
    },
    onStatusReset() {
      const updates = {};
      Object.keys(this.filters.statusFilters).forEach((status) => {
        updates[status] = false;
      });
      this.emitUpdatedFilters(updates);
    },
    onReviewReset() {
      const defaults = getDefaultFilters(Object.keys(this.filters.statusFilters));
      this.emitUpdatedFilters({
        nurFilterChecked: defaults.nurFilterChecked,
        urFilterChecked: defaults.urFilterChecked,
        lckFilterChecked: defaults.lckFilterChecked,
      });
    },
    onDisplayReset() {
      const defaults = getDefaultFilters(Object.keys(this.filters.statusFilters));
      this.emitUpdatedFilters({
        nestSatisfiedRulesChecked: defaults.nestSatisfiedRulesChecked,
        showSRGIdChecked: defaults.showSRGIdChecked,
        sortBySRGIdChecked: defaults.sortBySRGIdChecked,
        openCommentsOnly: defaults.openCommentsOnly,
      });
    },
  },
};
</script>

<style scoped>
.filter-bar {
  gap: 0.75rem;
  align-items: stretch; /* Unify heights */
  background-color: var(--vulcan-gray-100);
  border: 1px solid var(--vulcan-gray-300);
  border-radius: 0.375rem;
  padding: 0.75rem;
}

.filter-bar > * {
  flex: 1; /* Equal width distribution */
}

@media (max-width: 767.98px) {
  .filter-bar {
    flex-direction: column;
  }

  .filter-bar > * {
    width: 100%;
    flex: none;
  }
}
</style>
