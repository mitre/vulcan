<template>
  <div v-if="activePills.length > 0" data-test="active-filter-pills" class="active-filter-pills">
    <span
      v-for="pill in activePills"
      :key="pill.key"
      data-test="filter-pill"
      class="active-filter-pill"
    >
      {{ pill.label }}
      <b-icon
        icon="x"
        data-test="pill-dismiss"
        class="pill-dismiss"
        @click="$emit('remove-filter', pill.key)"
      />
    </span>
    <span
      data-test="clear-all-filters"
      class="text-primary clickable small"
      @click="$emit('clear-all')"
    >
      clear all
    </span>
  </div>
</template>

<script>
const FILTER_LABELS = {
  acFilterChecked: "Configurable",
  aimFilterChecked: "Inherently Meets",
  adnmFilterChecked: "Does Not Meet",
  naFilterChecked: "Not Applicable",
  nydFilterChecked: "Not Yet Determined",
  nurFilterChecked: "Not Under Review",
  urFilterChecked: "Under Review",
  lckFilterChecked: "Locked",
  openCommentsOnly: "Open Comments",
};

const FILTER_KEYS = Object.keys(FILTER_LABELS);

export default {
  name: "ActiveFilterPills",
  props: {
    filters: {
      type: Object,
      required: true,
    },
  },
  computed: {
    activePills() {
      const pills = [];
      FILTER_KEYS.forEach((key) => {
        if (this.filters[key]) {
          pills.push({ key, label: FILTER_LABELS[key] });
        }
      });
      if (this.filters.search) {
        pills.push({ key: "search", label: `"${this.filters.search}"` });
      }
      return pills;
    },
  },
};
</script>

<style scoped>
.active-filter-pills {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.25rem;
  padding: 0.25rem 0;
}

.active-filter-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.125rem 0.5rem;
  font-size: 0.75rem;
  background-color: var(--vulcan-primary-tint);
  color: var(--vulcan-primary);
  border: 1px solid var(--vulcan-primary);
  border-radius: 1rem;
}

.pill-dismiss {
  cursor: pointer;
  opacity: 0.7;
}

.pill-dismiss:hover {
  opacity: 1;
}
</style>
