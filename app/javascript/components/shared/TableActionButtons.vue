<template>
  <div class="d-inline-flex align-items-center" style="gap: 0.35rem">
    <b-button
      v-if="showEdit"
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
      v-if="showDelete"
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
    showEdit: { type: Boolean, default: false },
    showDelete: { type: Boolean, default: true },
  },
};
</script>
