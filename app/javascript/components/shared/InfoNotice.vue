<template>
  <small :class="['info-notice', variantClass]">
    <b-icon icon="info-circle" class="mr-1" aria-hidden="true" />
    <slot>{{ text }}</slot>
  </small>
</template>

<script>
export default {
  name: "InfoNotice",
  props: {
    text: { type: String, default: "" },
    variant: {
      type: String,
      default: "info",
      validator: (v) => ["info", "warning"].includes(v),
    },
  },
  computed: {
    variantClass() {
      return this.variant === "warning" ? "text-warning" : "text-muted";
    },
  },
};
</script>
