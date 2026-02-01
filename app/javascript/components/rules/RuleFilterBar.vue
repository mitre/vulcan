<template>
  <FilterBar
    :filters="filters"
    :counts="counts"
    :show-status="showStatus"
    :show-review="showReview"
    :show-display="showDisplay"
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
