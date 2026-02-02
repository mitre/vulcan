<template>
  <div class="filter-bar d-flex flex-wrap justify-content-between">
    <!-- Status Group -->
    <FilterGroup
      v-if="showStatus"
      title="Status"
      :items="statusItems"
      :disabled="disabledStatus"
      @update:items="onStatusUpdate"
      @reset="onStatusReset"
    />

    <!-- Display Group -->
    <FilterGroup
      v-if="showDisplay"
      title="Display"
      :items="displayItems"
      :disabled="disabledDisplay"
      @update:items="onDisplayUpdate"
      @reset="onDisplayReset"
    />

    <!-- Review Group (last - toggles on/off between modes) -->
    <FilterGroup
      v-if="showReview"
      title="Review"
      :items="reviewItems"
      :disabled="disabledReview"
      @update:items="onReviewUpdate"
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
    statusItems() {
      return [
        {
          key: "acFilterChecked",
          label: "Applicable - Configurable",
          count: this.counts.ac,
          checked: this.filters.acFilterChecked,
        },
        {
          key: "aimFilterChecked",
          label: "Applicable - Inherently Meets",
          count: this.counts.aim,
          checked: this.filters.aimFilterChecked,
        },
        {
          key: "adnmFilterChecked",
          label: "Applicable - Does Not Meet",
          count: this.counts.adnm,
          checked: this.filters.adnmFilterChecked,
        },
        {
          key: "naFilterChecked",
          label: "Not Applicable",
          count: this.counts.na,
          checked: this.filters.naFilterChecked,
        },
        {
          key: "nydFilterChecked",
          label: "Not Yet Determined",
          count: this.counts.nyd,
          checked: this.filters.nydFilterChecked,
        },
      ];
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
      ];
    },
  },
  methods: {
    emitUpdatedFilters(updates) {
      const newFilters = { ...this.filters, ...updates };
      this.$emit("update:filters", newFilters);
    },
    onStatusUpdate(items) {
      const updates = {};
      items.forEach((item) => {
        updates[item.key] = item.checked;
      });
      this.emitUpdatedFilters(updates);
    },
    onReviewUpdate(items) {
      const updates = {};
      items.forEach((item) => {
        updates[item.key] = item.checked;
      });
      this.emitUpdatedFilters(updates);
    },
    onDisplayUpdate(items) {
      const updates = {};
      items.forEach((item) => {
        updates[item.key] = item.checked;
      });
      this.emitUpdatedFilters(updates);
    },
    onStatusReset() {
      const defaults = getDefaultFilters();
      this.emitUpdatedFilters({
        acFilterChecked: defaults.acFilterChecked,
        aimFilterChecked: defaults.aimFilterChecked,
        adnmFilterChecked: defaults.adnmFilterChecked,
        naFilterChecked: defaults.naFilterChecked,
        nydFilterChecked: defaults.nydFilterChecked,
      });
    },
    onReviewReset() {
      const defaults = getDefaultFilters();
      this.emitUpdatedFilters({
        nurFilterChecked: defaults.nurFilterChecked,
        urFilterChecked: defaults.urFilterChecked,
        lckFilterChecked: defaults.lckFilterChecked,
      });
    },
    onDisplayReset() {
      const defaults = getDefaultFilters();
      this.emitUpdatedFilters({
        nestSatisfiedRulesChecked: defaults.nestSatisfiedRulesChecked,
        showSRGIdChecked: defaults.showSRGIdChecked,
        sortBySRGIdChecked: defaults.sortBySRGIdChecked,
      });
    },
  },
};
</script>

<style scoped>
.filter-bar {
  gap: 0.75rem;
  align-items: stretch; /* Unify heights */
  background-color: #f8f9fa;
  border: 1px solid #dee2e6;
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
