<template>
  <div data-testid="source-srg-picker">
    <b-form-group
      label="Select the source Security Requirements Guides"
      description="Every selected source contributes its requirements to the new component"
    >
      <vue-multiselect
        :value="selectedSrgs"
        :options="eligibleSrgs"
        :multiple="true"
        label="displayed"
        track-by="id"
        :searchable="true"
        :allow-empty="true"
        :close-on-select="false"
        :disabled="!documentType"
        placeholder="Search for source SRGs..."
        @input="setSelection($event)"
      />
    </b-form-group>

    <b-form-group
      v-if="selectedSrgs.length"
      label="Primary source"
      description="The primary drives display and version-currency defaults; all sources contribute requirements equally"
    >
      <b-form-radio-group :checked="value.primaryId" stacked @input="setPrimary($event)">
        <b-form-radio
          v-for="srg in selectedSrgs"
          :key="srg.id"
          :value="srg.id"
          :data-testid="`primary-radio-${srg.id}`"
        >
          {{ srg.displayed }}
        </b-form-radio>
      </b-form-radio-group>
    </b-form-group>
  </div>
</template>

<script>
/**
 * SourceSrgPicker - the multi-parent source picker for the creation flow.
 *
 * Offers ONLY parents eligible for the chosen profile (core SRGs
 * for srg, derived for stig — the AuthoringProfile registry policy),
 * so eligibility is enforced by construction; the backend validation
 * remains the enforcement layer. The author declares 1..N sources and
 * designates exactly one primary — defaulting to the first selection,
 * changeable until create. Removing the primary source reassigns the
 * primary to the first remaining selection.
 *
 * Usage:
 *   <SourceSrgPicker v-model="sourceSelection" :srgs="srgs" :document-type="document_type" />
 *
 * Props:
 *   - srgs: Array of catalog SRGs ({ id, title, version, core, ... })
 *   - documentType: String|null - gates and filters the offered list
 *   - value: { sourceIds: Array<Number>, primaryId: Number|null }
 *
 * Emits:
 *   - input: the complete new { sourceIds, primaryId } state
 */
import { isEligibleParent } from "../../constants/authoringProfiles";
import VueMultiselect from "vue-multiselect";
import "vue-multiselect/dist/vue-multiselect.min.css";

export default {
  name: "SourceSrgPicker",
  components: {
    VueMultiselect,
  },
  props: {
    srgs: {
      type: Array,
      required: true,
    },
    documentType: {
      type: String,
      default: null,
    },
    value: {
      type: Object,
      default: () => ({ sourceIds: [], primaryId: null }),
    },
  },
  computed: {
    eligibleSrgs: function () {
      return this.srgs
        .filter((srg) => isEligibleParent(srg, this.documentType))
        .map((srg) => ({ ...srg, displayed: srg.displayed || `${srg.title} (${srg.version})` }));
    },
    selectedSrgs: function () {
      return this.value.sourceIds
        .map((id) => this.eligibleSrgs.find((srg) => srg.id === id))
        .filter(Boolean);
    },
  },
  methods: {
    setSelection: function (selection) {
      const sourceIds = selection.map((srg) => srg.id);
      // The primary follows the selection: default to the first pick,
      // survive additions, move to the first remaining source when its
      // own row is deselected, clear when nothing is selected.
      const primaryId = sourceIds.includes(this.value.primaryId)
        ? this.value.primaryId
        : (sourceIds[0] ?? null);
      this.$emit("input", { sourceIds, primaryId });
    },
    setPrimary: function (primaryId) {
      this.$emit("input", { sourceIds: [...this.value.sourceIds], primaryId });
    },
  },
};
</script>
