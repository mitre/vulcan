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
            :checked="project.visibility === 'discoverable'"
            switch
            size="sm"
            @change="$emit('toggle-visibility', $event)"
          >
            <small>{{ project.visibility === 'discoverable' ? 'Discoverable' : 'Hidden' }}</small>
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

        <!-- Download Dropdown -->
        <b-dropdown
          right
          text="Download"
          variant="outline-secondary"
          size="sm"
          data-testid="download-dropdown"
        >
          <b-dropdown-item @click="$emit('download', 'disa_excel')">
            DISA Excel Export
          </b-dropdown-item>
          <b-dropdown-item @click="$emit('download', 'excel')">
            Excel Export
          </b-dropdown-item>
          <b-dropdown-item @click="$emit('download', 'inspec')">
            InSpec Profile
          </b-dropdown-item>
          <b-dropdown-item @click="$emit('download', 'xccdf')">
            XCCDF Export
          </b-dropdown-item>
        </b-dropdown>
      </div>

      <!-- Right: Panel Toggles -->
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
            <b-icon icon="clock-history" /> History
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
  computed: {
    isAdmin() {
      return this.effectivePermissions === "admin";
    },
  },
  methods: {
    isPanelActive(panel) {
      return this.activePanel === panel;
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
