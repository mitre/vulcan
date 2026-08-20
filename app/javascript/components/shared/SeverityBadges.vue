<template>
  <div v-if="counts" class="severity-badges d-flex flex-wrap" style="gap: 0.35rem">
    <span v-if="counts.high > 0" data-testid="cat-high" class="severity-pill severity-pill--high">
      <span class="severity-label">CAT I</span>
      <span class="severity-count">{{ counts.high }}</span>
    </span>
    <span
      v-if="counts.medium > 0"
      data-testid="cat-medium"
      class="severity-pill severity-pill--medium"
    >
      <span class="severity-label">CAT II</span>
      <span class="severity-count">{{ counts.medium }}</span>
    </span>
    <span v-if="counts.low > 0" data-testid="cat-low" class="severity-pill severity-pill--low">
      <span class="severity-label">CAT III</span>
      <span class="severity-count">{{ counts.low }}</span>
    </span>
  </div>
</template>

<script>
export default {
  name: "SeverityBadges",
  props: {
    counts: {
      type: Object,
      default: null,
    },
  },
};
</script>

<style scoped>
.severity-pill {
  display: inline-flex;
  align-items: center;
  font-size: 0.8rem;
  font-weight: 600;
  border: 1px solid var(--vulcan-border-color, #dee2e6);
  border-radius: 0.25rem;
  padding: 0.15rem 0.4rem;
  line-height: 1.4;
}

.severity-label {
  margin-right: 0.3rem;
}

.severity-count {
  font-weight: 700;
  color: var(--vulcan-emphasis-color, #212529);
}

.severity-pill--high {
  border-color: var(--vulcan-danger, #dc3545);
}

.severity-pill--high .severity-label {
  color: var(--vulcan-danger, #dc3545);
}

.severity-pill--medium {
  border-color: var(--vulcan-warning, #ffc107);
}

.severity-pill--medium .severity-label {
  color: var(--vulcan-warning, #ffc107);
}

.severity-pill--low {
  border-color: var(--vulcan-success, #28a745);
}

.severity-pill--low .severity-label {
  color: var(--vulcan-success, #28a745);
}
</style>
