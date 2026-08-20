<template>
  <b-modal
    :visible="visible"
    :title="terms.propose"
    @change="$emit('update:visible', $event)"
    @show="reset"
  >
    <p>
      Propose relocating <strong>{{ ruleDisplayName }}</strong> to another SRG. Nothing changes here
      yet — the proposal appears in the destination SRG's relocation backlog, where that SRG's
      authors concur or non-concur. You can withdraw the proposal while it is open; if the receiver
      non-concurs, their rationale is retained in the backlog.
    </p>
    <b-form-group
      label="Destination SRG"
      :description="
        showTokenInput
          ? 'Enter the SRG\'s abbreviation — the short code its requirement IDs start with, such as CTR, GPOS, or DB'
          : 'SRGs you can see are listed by name; pick Other for one you cannot see or that is not in Vulcan yet'
      "
    >
      <FilterDropdown
        v-if="destinationOptions.length > 0"
        :value="picked"
        :options="pickerOptions"
        aria-label="Pick the destination SRG"
        placeholder="Choose the destination SRG..."
        class="mb-2"
        @input="picked = $event"
      />
      <b-form-input
        v-if="showTokenInput"
        v-model="token"
        placeholder="CTR"
        autocomplete="off"
        data-test="relocation-token-input"
        @input="token = $event.toUpperCase()"
      />
    </b-form-group>
    <template #modal-footer>
      <b-button variant="outline-secondary" @click="$emit('update:visible', false)">
        Cancel
      </b-button>
      <b-button
        variant="warning"
        :disabled="!effectiveToken"
        data-test="confirm-mark"
        @click="$emit('mark', effectiveToken)"
      >
        {{ terms.propose }}
      </b-button>
    </template>
  </b-modal>
</template>

<script>
import FilterDropdown from "../shared/FilterDropdown.vue";
import { RELOCATION_TERM } from "../../constants/terminology";

const OTHER_SRG = "__other__";

/**
 * MarkRelocationModal - proposes relocation to a destination SRG. The
 * picker lists the destinations the caller can see by SRG name
 * (released rows carry the next-release suffix — the proposal queues
 * for that SRG's next version); the Other-SRG option (and the empty
 * options case) reveals the free technology-token input, so proposing
 * to an SRG the caller cannot see stays possible without disclosure.
 * Emits mark with the uppercased token; the caller owns the API call
 * and toasting. Selection and input clear on every open. Display verbs
 * come from the centralized RELOCATION_TERM table.
 *
 * Props:
 *   - visible: Boolean (use with .sync)
 *   - ruleDisplayName: String - the requirement being proposed
 *   - destinationOptions: Array of { value, text } labelled options from
 *     useRelocations' destination vocabulary (the propose subset)
 *
 * Emits:
 *   - mark: String - the destination SRG's technology token
 *   - update:visible: Boolean
 */
export default {
  name: "MarkRelocationModal",
  components: {
    FilterDropdown,
  },
  props: {
    visible: {
      type: Boolean,
      default: false,
    },
    ruleDisplayName: {
      type: String,
      required: true,
    },
    destinationOptions: {
      type: Array,
      default: () => [],
    },
  },
  data() {
    return {
      picked: null,
      token: "",
      terms: RELOCATION_TERM,
    };
  },
  computed: {
    // Labelling and merging live in useRelocations' destination
    // vocabulary — this modal only appends its own Other entry.
    pickerOptions() {
      return [...this.destinationOptions, { value: OTHER_SRG, text: this.terms.otherSrgOption }];
    },
    showTokenInput() {
      return this.destinationOptions.length === 0 || this.picked === OTHER_SRG;
    },
    effectiveToken() {
      if (this.showTokenInput) return this.token || null;
      return this.picked;
    },
  },
  methods: {
    reset() {
      this.picked = null;
      this.token = "";
    },
  },
};
</script>
