<template>
  <FilterBar
    :filters="filters"
    :counts="counts"
    :show-status="showStatus"
    :show-review="showReview"
    :show-display="showDisplay"
    :disabled-status="disabledStatus"
    :disabled-review="disabledReview"
    :disabled-display="disabledDisplay"
    @update:filters="handleFiltersUpdate"
  />
</template>

<script>
import FilterBar from "../shared/FilterBar.vue";

export default {
  name: "RuleFilterBar",
  components: { FilterBar },
  props: {
    filters: {
      type: Object,
      required: true,
    },
    counts: {
      type: Object,
      required: true,
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
  methods: {
    handleFiltersUpdate(newFilters) {
      // Emit individual filter updates for backward compatibility
      Object.keys(newFilters).forEach((key) => {
        if (this.filters[key] !== newFilters[key]) {
          this.$emit("update:filter", key, newFilters[key]);
        }
      });
    },
  },
};
</script>
