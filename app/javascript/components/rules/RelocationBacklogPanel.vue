<template>
  <div class="px-3 py-2" data-testid="relocation-backlog-panel">
    <b-form-group label="Family" label-class="font-weight-bold">
      <FilterDropdown
        :value="selectedToken"
        :options="tokenOptions"
        aria-label="Filter backlog by family technology token"
        placeholder="Choose a family..."
        @input="selectedToken = $event"
      />
    </b-form-group>

    <p v-if="selectedToken" class="mb-2">
      <strong>{{ filteredMarkers.length }}</strong>
      {{ filteredMarkers.length === 1 ? "requirement is" : "requirements are" }} marked for the
      {{ selectedToken }} family
    </p>

    <div v-if="filteredMarkers.length === 0" class="text-muted">
      No requirements are marked for relocation<span v-if="selectedToken">
        to the {{ selectedToken }} family</span
      >.
    </div>

    <div
      v-for="marker in filteredMarkers"
      :key="marker.id"
      class="d-flex align-items-center justify-content-between border-bottom py-2"
      data-test="relocation-row"
    >
      <div>
        <div class="font-weight-bold">{{ marker.source_displayed_name }}</div>
        <small class="text-muted">
          {{ marker.component_name }}
          <span v-if="marker.requested_by_name"> · marked by {{ marker.requested_by_name }}</span>
          → {{ marker.target_technology_token }}
        </small>
      </div>
      <!-- Disabled-not-hidden: the wrapping span carries the tooltip
           because disabled buttons swallow pointer events. -->
      <span
        v-b-tooltip.hover
        :title="unmarkDisabledReason(marker) || ''"
        :data-test="`unmark-tip-${marker.id}`"
      >
        <b-button
          variant="outline-danger"
          size="sm"
          :disabled="!!unmarkDisabledReason(marker)"
          :data-test="`unmark-${marker.id}`"
          @click="$emit('unmark', marker.id)"
        >
          <b-icon icon="x-circle" /> Un-mark
        </b-button>
      </span>
    </div>
  </div>
</template>

<script>
/**
 * RelocationBacklogPanel - the standing per-family relocation backlog.
 *
 * Lists pending markers (across components) for a family technology
 * token; the explicit token filter offers every distinct pending token,
 * defaulting to the open component's family, so the interim
 * prefix-derived family key never hides a marker. Un-mark emits the
 * record id; rows the session cannot act on render the button disabled
 * with an explanatory tooltip — never hidden.
 *
 * Props:
 *   - markers: Array of pending relocation rows (backlog API shape)
 *   - componentId: Number - the open component (its rows are actionable)
 *   - initialToken: String|null - default family filter
 *   - canAuthor: Boolean - author role on the open component
 *
 * Emits:
 *   - unmark: Number - the relocation record id to destroy
 */
import FilterDropdown from "../shared/FilterDropdown.vue";

export default {
  name: "RelocationBacklogPanel",
  components: {
    FilterDropdown,
  },
  props: {
    markers: {
      type: Array,
      required: true,
    },
    componentId: {
      type: Number,
      required: true,
    },
    initialToken: {
      type: String,
      default: null,
    },
    canAuthor: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      selectedToken: this.initialToken,
    };
  },
  computed: {
    tokenOptions() {
      const tokens = [...new Set(this.markers.map((m) => m.target_technology_token))].sort();
      return tokens.map((token) => ({ value: token, text: token }));
    },
    filteredMarkers() {
      if (!this.selectedToken) return [];
      return this.markers.filter((m) => m.target_technology_token === this.selectedToken);
    },
  },
  methods: {
    unmarkDisabledReason(marker) {
      if (marker.component_id !== this.componentId) {
        return "Un-mark from that component's editor";
      }
      if (!this.canAuthor) {
        return "Requires author role on this component";
      }
      return null;
    },
  },
};
</script>
