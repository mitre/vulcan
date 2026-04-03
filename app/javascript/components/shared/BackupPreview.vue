<template>
  <div data-testid="backup-preview">
    <!-- Warnings (top for visibility) -->
    <b-alert
      v-for="(warning, index) in warnings"
      :key="'warning-' + index"
      variant="warning"
      show
      data-testid="warning-alert"
    >
      {{ warning }}
    </b-alert>

    <!-- Stat cards -->
    <div class="d-flex flex-wrap mb-3 border rounded p-2 bg-light" data-testid="stat-cards">
      <div class="text-center px-3">
        <div class="h5 mb-0 font-weight-bold">{{ displayComponentCount }}</div>
        <small class="text-muted">Components</small>
      </div>
      <div class="text-center px-3 border-left">
        <div class="h5 mb-0 font-weight-bold">{{ displayRuleCount }}</div>
        <small class="text-muted">Rules</small>
      </div>
      <div class="text-center px-3 border-left">
        <div class="h5 mb-0 font-weight-bold">{{ summary.satisfactions_imported }}</div>
        <small class="text-muted">Satisfactions</small>
      </div>
      <div v-if="summary.reviews_imported" class="text-center px-3 border-left">
        <div class="h5 mb-0 font-weight-bold">{{ summary.reviews_imported }}</div>
        <small class="text-muted">Reviews</small>
      </div>
      <div v-if="summary.memberships_imported !== undefined" class="text-center px-3 border-left">
        <div class="h5 mb-0 font-weight-bold">{{ summary.memberships_imported }}</div>
        <small class="text-muted">Memberships</small>
      </div>
    </div>

    <!-- Component list -->
    <div v-if="componentDetails.length > 0" class="mb-3" data-testid="component-list">
      <h6 class="font-weight-bold mb-2">
        {{
          selectable
            ? "Select components to import:"
            : "Components (" + componentDetails.length + ")"
        }}
      </h6>
      <div class="component-list-scroll">
        <div
          v-for="(comp, index) in displayComponents"
          :key="index"
          class="d-flex align-items-center py-1 border-bottom"
          data-testid="component-row"
        >
          <!-- Selectable mode: checkbox -->
          <b-form-checkbox
            v-if="selectable"
            v-model="selections[index].selected"
            :data-testid="'component-checkbox-' + index"
            class="mr-2"
          />

          <!-- Read-only mode: folder icon -->
          <b-icon v-else icon="folder" class="mr-2 text-muted" />

          <!-- Component info -->
          <div class="flex-grow-1">
            <!-- Name row: editable input or static name + validation badge -->
            <div class="d-flex align-items-center">
              <template
                v-if="selectable && selections[index].conflict && selections[index].selected"
              >
                <b-form-input
                  :ref="'name-input-' + index"
                  v-model="selections[index].importName"
                  size="sm"
                  :data-testid="'component-name-input-' + index"
                  :state="validationState(index)"
                  class="d-inline-block"
                  style="width: 250px"
                />
                <b-badge
                  v-if="validationErrors[index] === 'name taken'"
                  variant="warning"
                  class="ml-2"
                  data-testid="status-name-taken"
                >
                  name taken
                </b-badge>
                <b-badge
                  v-else-if="validationErrors[index] === 'name required'"
                  variant="danger"
                  class="ml-2"
                  data-testid="status-name-required"
                >
                  name required
                </b-badge>
                <b-icon
                  v-else
                  icon="check-circle"
                  variant="success"
                  class="ml-2"
                  data-testid="status-ready"
                />
              </template>
              <template v-else>
                <span>{{ comp.name }}</span>
                <b-badge
                  v-if="!selectable && comp.conflict"
                  variant="warning"
                  class="ml-2"
                  data-testid="conflict-badge"
                >
                  conflict
                </b-badge>
              </template>
              <small class="text-muted ml-auto">{{ comp.rule_count }} rules</small>
            </div>
            <!-- Parent SRG (second line) -->
            <small v-if="comp.srg_title" class="text-muted" data-testid="parent-srg">
              Parent SRG: {{ comp.srg_title }} {{ comp.srg_version }}
            </small>
          </div>
        </div>
      </div>
    </div>

    <!-- SRG auto-import alert -->
    <b-alert
      v-if="summary.srg_details && summary.srg_details.length > 0"
      variant="info"
      show
      data-testid="srg-import-alert"
    >
      <b-icon icon="info-circle" class="mr-1" />
      <strong>
        {{ summary.srg_details.length }} base SRG{{ summary.srg_details.length > 1 ? "s" : "" }}
        will be auto-imported:
      </strong>
      <ul class="mb-0 mt-1">
        <li v-for="(srg, idx) in summary.srg_details" :key="idx">
          {{ srg.title }} ({{ srg.version }})
        </li>
      </ul>
    </b-alert>

    <!-- Summary table -->
    <table class="table table-sm table-bordered mb-0" data-testid="summary-table">
      <thead>
        <tr>
          <th>Item</th>
          <th class="text-right">Count</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>Rules</td>
          <td class="text-right font-weight-bold">{{ displayRuleCount }}</td>
        </tr>
        <tr>
          <td>Satisfactions</td>
          <td class="text-right font-weight-bold">{{ summary.satisfactions_imported }}</td>
        </tr>
        <tr>
          <td>Reviews</td>
          <td class="text-right font-weight-bold">{{ summary.reviews_imported }}</td>
        </tr>
        <tr v-if="summary.memberships_imported !== undefined">
          <td>Memberships</td>
          <td class="text-right font-weight-bold">{{ summary.memberships_imported }}</td>
        </tr>
        <tr v-if="summary.srgs_imported > 0" data-testid="srgs-imported-row">
          <td>SRGs to import</td>
          <td class="text-right font-weight-bold">{{ summary.srgs_imported }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script>
export default {
  name: "BackupPreview",
  props: {
    summary: {
      type: Object,
      required: true,
    },
    componentDetails: {
      type: Array,
      default: () => [],
    },
    warnings: {
      type: Array,
      default: () => [],
    },
    selectable: {
      type: Boolean,
      default: false,
    },
    existingNames: {
      type: Array,
      default: () => [],
    },
  },
  data() {
    return {
      selections: [],
    };
  },
  computed: {
    displayComponents() {
      return this.componentDetails;
    },
    existingNamesSet() {
      return new Set(this.existingNames.map((n) => n.toLowerCase()));
    },
    validationErrors() {
      if (!this.selectable) return {};
      const errors = {};
      const importNames = {};

      // First pass: collect all selected import names for duplicate detection
      this.selections.forEach((s, i) => {
        if (!s.selected || !s.conflict) return;
        const name = s.importName.trim().toLowerCase();
        if (!importNames[name]) importNames[name] = [];
        importNames[name].push(i);
      });

      // Second pass: validate each conflicting selection
      this.selections.forEach((s, i) => {
        if (!s.selected || !s.conflict) return;
        const trimmed = s.importName.trim();

        if (!trimmed) {
          errors[i] = "name required";
        } else if (this.existingNamesSet.has(trimmed.toLowerCase())) {
          errors[i] = "name taken";
        } else if (
          importNames[trimmed.toLowerCase()] &&
          importNames[trimmed.toLowerCase()].length > 1
        ) {
          errors[i] = "name taken";
        }
      });

      return errors;
    },
    hasUnresolvedConflicts() {
      return Object.keys(this.validationErrors).length > 0;
    },
    displayComponentCount() {
      if (this.selectable && this.selections.length > 0) {
        return this.selections.filter((s) => s.selected).length;
      }
      return this.componentDetails.length || this.summary.components_imported || 0;
    },
    displayRuleCount() {
      if (this.selectable && this.selections.length > 0) {
        return this.selections.filter((s) => s.selected).reduce((sum, s) => sum + s.ruleCount, 0);
      }
      return this.summary.rules_imported;
    },
    componentFilter() {
      if (!this.selectable || this.selections.length === 0) return null;
      const filter = {};
      this.selections
        .filter((s) => s.selected)
        .forEach((s) => {
          filter[s.name] = s.importName;
        });
      return filter;
    },
  },
  watch: {
    componentDetails: {
      immediate: true,
      handler(details) {
        if (!this.selectable || !details || !Array.isArray(details)) {
          this.selections = [];
          return;
        }
        this.selections = details.map((d) => ({
          name: d.name,
          importName: d.conflict ? `${d.name} (restored)` : d.name,
          ruleCount: d.rule_count,
          conflict: d.conflict || false,
          selected: true,
        }));

        // Auto-focus first conflicting input after render
        this.$nextTick(() => {
          const firstConflict = this.selections.findIndex((s) => s.conflict);
          if (firstConflict >= 0) {
            const ref = this.$refs[`name-input-${firstConflict}`];
            if (ref) {
              const el = Array.isArray(ref) ? ref[0] : ref;
              if (el && el.$el) {
                const input = el.$el.querySelector ? el.$el.querySelector("input") : el.$el;
                if (input && input.focus) input.focus();
              }
            }
          }
        });
      },
    },
    selections: {
      deep: true,
      handler() {
        if (!this.selectable) return;
        this.$emit("selection-change", {
          selectedCount: this.displayComponentCount,
          selectedRuleCount: this.displayRuleCount,
          componentFilter: this.componentFilter,
          hasUnresolvedConflicts: this.hasUnresolvedConflicts,
        });
      },
    },
  },
  methods: {
    validationState(index) {
      if (!this.validationErrors[index]) return null;
      return false; // Bootstrap-Vue: false = invalid (red border)
    },
  },
};
</script>

<style scoped>
.component-list-scroll {
  max-height: 300px;
  overflow-y: auto;
}
</style>
