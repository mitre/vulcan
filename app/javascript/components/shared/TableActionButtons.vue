<template>
  <div class="d-inline-flex align-items-center" style="gap: 0.35rem">
    <b-button
      v-if="hasEditListener"
      v-b-tooltip.hover="disabled ? disabledTooltip : 'Edit'"
      data-testid="action-edit"
      size="sm"
      variant="outline-secondary"
      :aria-label="'Edit ' + itemName"
      :title="disabled ? disabledTooltip : 'Edit'"
      :disabled="disabled"
      @click="$emit('edit')"
    >
      <b-icon icon="pencil" aria-hidden="true" />
    </b-button>
    <b-button
      v-if="hasDeleteListener"
      v-b-tooltip.hover="disabled ? disabledTooltip : 'Remove'"
      data-testid="action-delete"
      size="sm"
      variant="outline-danger"
      :aria-label="'Remove ' + itemName"
      :title="disabled ? disabledTooltip : 'Remove'"
      :disabled="disabled"
      @click="$emit('delete')"
    >
      <b-icon icon="trash" aria-hidden="true" />
    </b-button>
  </div>
</template>

<script>
export default {
  name: "TableActionButtons",
  props: {
    itemName: { type: String, default: "" },
    disabled: { type: Boolean, default: false },
    disabledTooltip: { type: String, default: "" },
  },
  computed: {
    hasEditListener() {
      return !!(this.$listeners && this.$listeners.edit);
    },
    hasDeleteListener() {
      return !!(this.$listeners && this.$listeners.delete);
    },
  },
};
</script>
