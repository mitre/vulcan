<template>
  <b-modal
    :visible="visible"
    :title="modalTitle"
    centered
    modal-class="confirm-delete-modal"
    @hidden="onHidden"
  >
    <!-- Custom header with warning icon -->
    <template #modal-header="{ close }">
      <div class="d-flex align-items-center w-100">
        <b-icon icon="exclamation-triangle-fill" variant="warning" font-scale="1.5" class="mr-2" />
        <h5 class="mb-0 flex-grow-1">{{ modalTitle }}</h5>
        <b-button-close @click="close" />
      </div>
    </template>
    <!-- Loading State -->
    <div v-if="isDeleting" class="text-center py-4">
      <b-spinner variant="danger" class="mb-3" />
      <p class="mb-0">{{ displayDeletingMessage }}</p>
    </div>

    <!-- Confirmation State -->
    <div v-else>
      <p class="mb-2">{{ displayConfirmMessage }}</p>
      <p v-if="itemName" class="mb-0 font-weight-bold">"{{ itemName }}"</p>
      <p v-if="warningMessage" class="text-muted mt-3 mb-0">
        <small><b-icon icon="info-circle" class="mr-1" />{{ warningMessage }}</small>
      </p>
    </div>

    <!-- Footer -->
    <template #modal-footer>
      <b-button
        variant="outline-secondary"
        :disabled="isDeleting"
        data-testid="cancel-delete-btn"
        @click="onCancel"
      >
        Cancel
      </b-button>
      <b-button
        variant="danger"
        :disabled="isDeleting"
        data-testid="confirm-delete-btn"
        @click="onConfirm"
      >
        <b-spinner v-if="isDeleting" small class="mr-1" />
        {{ isDeleting ? "Removing..." : confirmButtonText }}
      </b-button>
    </template>
  </b-modal>
</template>

<script>
/**
 * ConfirmDeleteModal - Reusable delete confirmation modal with loading state
 *
 * Usage:
 *   <ConfirmDeleteModal
 *     v-model="showDeleteModal"
 *     :item-name="project.name"
 *     item-type="project"
 *     :is-deleting="isDeleting"
 *     @confirm="handleDelete"
 *     @cancel="handleCancel"
 *   />
 *
 * Props:
 *   - visible: Boolean (use v-model)
 *   - itemName: Name of item being deleted (displayed in modal)
 *   - itemType: Type of item (project, component, etc.) for messaging
 *   - isDeleting: Boolean - shows loading state
 *   - title: Optional custom title
 *   - confirmMessage: Optional custom confirmation message
 *   - warningMessage: Optional warning text (shown in red)
 *   - confirmButtonText: Optional custom button text (default: "Remove")
 *   - deletingMessage: Optional custom deleting message
 *
 * Emits:
 *   - confirm: User confirmed deletion
 *   - cancel: User cancelled
 *   - update:visible: For v-model support
 */
export default {
  name: "ConfirmDeleteModal",
  model: {
    prop: "visible",
    event: "update:visible",
  },
  props: {
    visible: {
      type: Boolean,
      default: false,
    },
    itemName: {
      type: String,
      default: "",
    },
    itemType: {
      type: String,
      default: "item",
    },
    isDeleting: {
      type: Boolean,
      default: false,
    },
    title: {
      type: String,
      default: null,
    },
    confirmMessage: {
      type: String,
      default: null,
    },
    warningMessage: {
      type: String,
      default: null,
    },
    confirmButtonText: {
      type: String,
      default: "Remove",
    },
    deletingMessage: {
      type: String,
      default: null,
    },
  },
  computed: {
    modalTitle() {
      return this.title || `Remove ${this.capitalizedItemType}`;
    },
    capitalizedItemType() {
      return this.itemType.charAt(0).toUpperCase() + this.itemType.slice(1);
    },
    defaultConfirmMessage() {
      return `Are you sure you want to remove this ${this.itemType}? This action cannot be undone.`;
    },
    displayConfirmMessage() {
      return this.confirmMessage || this.defaultConfirmMessage;
    },
    displayDeletingMessage() {
      return this.deletingMessage || `Removing ${this.itemType}...`;
    },
  },
  methods: {
    onCancel() {
      this.$emit("cancel");
      this.$emit("update:visible", false);
    },
    onConfirm() {
      this.$emit("confirm");
    },
    onHidden() {
      // Only emit cancel if not in deleting state (prevents closing during delete)
      if (!this.isDeleting) {
        this.$emit("cancel");
        this.$emit("update:visible", false);
      }
    },
  },
};
</script>

<style>
/* Warning border for delete confirmation modal */
.confirm-delete-modal .modal-content {
  border: 2px solid var(--warning) !important;
  border-radius: 0.5rem;
}
</style>
