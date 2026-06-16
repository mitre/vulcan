<template>
  <b-icon
    v-b-tooltip.hover.html="text"
    icon="info-circle"
    class="info-tooltip text-muted ml-1"
    aria-hidden="true"
    :font-scale="size"
  />
</template>

<script>
export default {
  name: "InfoTooltip",
  props: {
    text: { type: String, required: true },
    size: { type: [Number, String], default: 0.85 },
  },
};
</script>

<style scoped>
.info-tooltip {
  cursor: help;
  opacity: 0.6;
}

.info-tooltip:hover {
  opacity: 1;
}
</style>
