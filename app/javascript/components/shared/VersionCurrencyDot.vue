<template>
  <span class="d-inline-flex align-items-center">
    <a
      v-if="!isLatest && linkPath && latestId"
      :href="`${linkPath}/${latestId}`"
      data-testid="version-dot-link"
      class="d-inline-flex align-items-center text-decoration-none"
    >
      <span
        v-b-tooltip.hover
        :title="tooltip"
        class="version-currency-dot version-currency-dot--outdated"
        data-testid="version-dot"
      />
      <small v-if="showVersion" class="ml-1 text-muted">{{ latestVersion }}</small>
    </a>
    <template v-else>
      <span
        v-b-tooltip.hover
        :title="tooltip"
        class="version-currency-dot"
        :class="isLatest ? 'version-currency-dot--current' : 'version-currency-dot--outdated'"
        data-testid="version-dot"
      />
      <small v-if="showVersion && !isLatest" class="ml-1 text-muted">{{ latestVersion }}</small>
    </template>
  </span>
</template>

<script>
export default {
  name: "VersionCurrencyDot",
  props: {
    isLatest: { type: Boolean, required: true },
    latestVersion: { type: String, default: null },
    latestId: { type: Number, default: null },
    linkPath: { type: String, default: null },
    showVersion: { type: Boolean, default: false },
  },
  computed: {
    tooltip() {
      if (this.isLatest) return "Current version";
      if (this.latestVersion) {
        return `Newer version available (${this.latestVersion}) — click to view`;
      }
      return "Newer version available";
    },
  },
};
</script>

<style scoped>
.version-currency-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.version-currency-dot--current {
  background-color: var(--vulcan-success, #28a745);
}

.version-currency-dot--outdated {
  background-color: var(--vulcan-warning, #ffc107);
}
</style>
