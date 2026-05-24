<template>
  <div class="d-inline-flex align-items-center" style="gap: 0.35rem">
    <b-button
      v-if="hasEditListener"
      data-testid="action-edit"
      size="sm"
      variant="outline-secondary"
      :aria-label="'Edit ' + itemName"
      :disabled="disabled"
      @click="$emit('edit')"
    >
      <b-icon icon="pencil" aria-hidden="true" />
    </b-button>
    <b-button
      v-if="hasDeleteListener"
      data-testid="action-delete"
      size="sm"
      variant="outline-danger"
      :aria-label="'Remove ' + itemName"
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
