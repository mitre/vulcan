<template>
  <div class="command-bar bg-light px-3 py-2">
    <div class="d-flex align-items-center justify-content-between flex-wrap">
      <!-- Left: Actions -->
      <div class="d-flex align-items-center">
        <!-- Visibility Toggle (admin only) -->
        <div
          v-if="isAdmin"
          class="mr-3"
          data-testid="visibility-toggle"
        >
          <b-form-checkbox
            v-model="localVisibility"
            switch
            size="sm"
            @change="onVisibilityToggle"
          >
            <small>{{ localVisibility ? 'Discoverable' : 'Hidden' }}</small>
          </b-form-checkbox>
        </div>

        <!-- New Component Button (admin only) -->
        <b-button
          v-if="isAdmin"
          variant="primary"
          size="sm"
          class="mr-2"
          data-testid="new-component-btn"
          @click="$emit('new-component')"
        >
          <b-icon icon="plus" /> New Component
        </b-button>

        <!-- Download Button -->
        <b-button
          variant="outline-secondary"
          size="sm"
          data-testid="download-btn"
          @click="$emit('download')"
        >
          <b-icon icon="download" /> Download
        </b-button>
      </div>

      <!-- Right: Panel Toggles + Members Button -->
      <div class="d-flex align-items-center">
        <b-button-group size="sm">
          <b-button
            :variant="isPanelActive('proj-details') ? 'secondary' : 'outline-secondary'"
            @click="$emit('toggle-panel', 'proj-details')"
          >
            <b-icon icon="info-circle" /> Details
          </b-button>
          <b-button
            :variant="isPanelActive('proj-metadata') ? 'secondary' : 'outline-secondary'"
            @click="$emit('toggle-panel', 'proj-metadata')"
          >
            <b-icon icon="tags" /> Metadata
          </b-button>
          <b-button
            :variant="isPanelActive('proj-history') ? 'secondary' : 'outline-secondary'"
            @click="$emit('toggle-panel', 'proj-history')"
          >
            <b-icon icon="clock-history" /> Activity
          </b-button>
          <b-button
            :variant="isPanelActive('proj-revision-history') ? 'secondary' : 'outline-secondary'"
            @click="$emit('toggle-panel', 'proj-revision-history')"
          >
            <b-icon icon="journal-text" /> Revisions
          </b-button>
          <b-button
            variant="outline-secondary"
            @click="$emit('open-members')"
          >
            <b-icon icon="people" /> Members
          </b-button>
        </b-button-group>
      </div>
    </div>
  </div>
</template>

<script>
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";

export default {
  name: "ProjectCommandBar",
  mixins: [RoleComparisonMixin],
  props: {
    project: {
      type: Object,
      required: true,
    },
    effectivePermissions: {
      type: String,
      required: true,
    },
    activePanel: {
      type: String,
      default: null,
    },
  },
  data() {
    return {
      // Local state for visibility toggle - syncs with prop
      localVisibility: this.project.visibility === "discoverable",
    };
  },
  computed: {
    isAdmin() {
      return this.effectivePermissions === "admin";
    },
  },
  watch: {
    // Sync local state when prop changes (after API success)
    "project.visibility"(newVal) {
      this.localVisibility = newVal === "discoverable";
    },
  },
  methods: {
    isPanelActive(panel) {
      return this.activePanel === panel;
    },
    onVisibilityToggle(newValue) {
      // Emit event for parent to show confirmation modal
      // Parent will call resetVisibilityToggle if cancelled
      this.$emit("toggle-visibility", newValue);
    },
    // Called by parent when user cancels the confirmation
    resetVisibilityToggle() {
      this.localVisibility = this.project.visibility === "discoverable";
    },
  },
};
</script>

<style scoped>
.command-bar {
  position: sticky;
  top: 0;
  z-index: 100;
  border-radius: 0.375rem;
  border: 1px solid #dee2e6;
}

.command-bar > div {
  gap: 0.5rem;
}
</style>
