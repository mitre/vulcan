<template>
  <div class="px-3 py-2" data-testid="relocation-backlog-panel">
    <b-form-group label="Destination SRG" label-class="font-weight-bold">
      <FilterDropdown
        :value="selectedToken"
        :options="tokenOptions"
        aria-label="Filter backlog by destination SRG abbreviation"
        placeholder="Choose an SRG..."
        @input="selectedToken = $event"
      />
    </b-form-group>

    <p v-if="selectedToken" class="mb-2">
      <strong>{{ openMarkers.length }}</strong>
      {{ openMarkers.length === 1 ? "requirement is" : "requirements are" }}
      {{ terms.proposed }} for the {{ selectedToken }} SRG
    </p>

    <div v-if="openMarkers.length === 0 && declinedMarkers.length === 0" class="text-muted">
      No requirements are {{ terms.proposed }} for relocation<span v-if="selectedToken">
        to the {{ selectedToken }} SRG</span
      >.
    </div>

    <div
      v-for="marker in openMarkers"
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
      <!-- Disabled-not-hidden: the wrapping spans carry the tooltips
           because disabled buttons swallow pointer events. -->
      <div class="d-flex">
        <span
          v-b-tooltip.hover
          :title="adjudicateDisabledReason(marker) || ''"
          :data-test="`adjudicate-tip-${marker.id}`"
        >
          <b-button
            variant="primary"
            size="sm"
            class="mr-1"
            :disabled="!!adjudicateDisabledReason(marker)"
            :data-test="`accept-${marker.id}`"
            @click="$emit('accept-request', marker)"
          >
            <b-icon icon="box-arrow-in-right" /> {{ terms.concur }}
          </b-button>
          <b-button
            variant="outline-danger"
            size="sm"
            class="mr-1"
            :disabled="!!adjudicateDisabledReason(marker)"
            :data-test="`decline-${marker.id}`"
            @click="$emit('decline-request', marker)"
          >
            <b-icon icon="x-octagon" /> {{ terms.nonConcur }}
          </b-button>
        </span>
        <span
          v-b-tooltip.hover
          :title="unmarkDisabledReason(marker) || ''"
          :data-test="`unmark-tip-${marker.id}`"
        >
          <b-button
            variant="outline-secondary"
            size="sm"
            :disabled="!!unmarkDisabledReason(marker)"
            :data-test="`unmark-${marker.id}`"
            @click="$emit('unmark', marker.id)"
          >
            <b-icon icon="x-circle" /> {{ terms.withdraw }}
          </b-button>
        </span>
      </div>
    </div>

    <!-- Retained declines: terminal history for the source author —
         state, rationale, and decliner; no actions exist for them. -->
    <template v-if="declinedMarkers.length > 0">
      <p class="mt-3 mb-1 font-weight-bold">{{ terms.nonConcurredHeading }}</p>
      <div
        v-for="marker in declinedMarkers"
        :key="marker.id"
        class="border-bottom py-2"
        :data-test="`declined-row-${marker.id}`"
      >
        <div class="d-flex align-items-center">
          <span class="font-weight-bold mr-2">{{ marker.source_displayed_name }}</span>
          <b-badge variant="secondary">{{ terms.nonConcurred }}</b-badge>
        </div>
        <small class="text-muted d-block">
          {{ marker.adjudication_rationale }}
          <span v-if="marker.declined_by_name">— {{ marker.declined_by_name }}</span>
        </small>
      </div>
    </template>
  </div>
</template>

<script>
/**
 * RelocationBacklogPanel - the standing per-SRG relocation backlog.
 *
 * Lists proposals for a destination SRG (by technology token), across
 * components; the explicit token filter offers every distinct token,
 * defaulting to the open component's SRG, so the interim prefix-derived
 * token never hides a row. OPEN proposals carry the adjudication
 * affordances: Concur and Non-concur emit the full marker (the caller
 * runs dry-run and confirm), Withdraw emits the record id (source-side
 * withdrawal). Display verbs come from the centralized RELOCATION_TERM
 * table. Actions the session cannot take render disabled with an
 * explanatory tooltip — never hidden. Only what the client knows is
 * disabled here; the server adjudicates the rest (source-SRG coverage,
 * open state) through the dry-run preview. Non-concurred proposals are
 * retained history: state, rationale, and decliner — no actions exist
 * for them.
 *
 * Props:
 *   - markers: Array of backlog rows (open proposals + retained declines)
 *   - componentId: Number - the open component (receives accepted moves;
 *     its own rows are withdrawable, not adjudicable)
 *   - initialToken: String|null - default destination SRG filter
 *   - canAuthor: Boolean - author role on the open component
 *   - componentReleased: Boolean - released components cannot receive
 *   - viewOnlyPage: Boolean - rendered on the read-only component view
 *     page, where adjudication lives in the editor. Checked LAST so the
 *     editor-pointing tooltip only shows when the page mode is the sole
 *     barrier — self-rows, missing role, and released components keep
 *     their own reason (opening the editor would not cure them)
 *
 * Emits:
 *   - unmark: Number - the relocation record id to withdraw
 *   - accept-request: Object - the marker to dry-run and confirm
 *   - decline-request: Object - the marker to decline with rationale
 */
import FilterDropdown from "../shared/FilterDropdown.vue";
import { RELOCATION_TERM } from "../../constants/terminology";

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
    componentReleased: {
      type: Boolean,
      default: false,
    },
    viewOnlyPage: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      selectedToken: this.initialToken,
      terms: RELOCATION_TERM,
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
    openMarkers() {
      return this.filteredMarkers.filter((m) => !m.declined_at);
    },
    declinedMarkers() {
      return this.filteredMarkers.filter((m) => m.declined_at);
    },
  },
  methods: {
    unmarkDisabledReason(marker) {
      if (marker.component_id !== this.componentId) {
        return this.terms.otherComponentWithdrawReason;
      }
      if (!this.canAuthor) {
        return this.terms.requiresAuthorReason;
      }
      if (this.viewOnlyPage) {
        return this.terms.editorWithdrawReason;
      }
      return null;
    },
    adjudicateDisabledReason(marker) {
      if (marker.component_id === this.componentId) {
        return this.terms.selfRowReason;
      }
      if (!this.canAuthor) {
        return this.terms.requiresAuthorReason;
      }
      if (this.componentReleased) {
        return this.terms.releasedReason;
      }
      if (this.viewOnlyPage) {
        return this.terms.editorAdjudicateReason;
      }
      return null;
    },
  },
};
</script>
