<template>
  <b-modal
    :visible="visible"
    :title="terms.nonConcurTitle"
    @change="$emit('update:visible', $event)"
    @show="rationale = ''"
  >
    <p>
      Non-concur with the proposal to move <strong>{{ sourceDisplayedName }}</strong> into this
      component. The proposal is retained with your rationale — the source author sees it in the
      backlog, and the requirement can be proposed again later.
    </p>
    <b-form-group
      label="Rationale"
      description="Why this requirement does not belong here — shown to the source author"
    >
      <b-form-textarea
        v-model="rationale"
        rows="3"
        placeholder="Covered by an existing requirement in this SRG..."
        data-test="decline-rationale-input"
      />
    </b-form-group>
    <template #modal-footer>
      <b-button variant="outline-secondary" @click="$emit('update:visible', false)">
        Cancel
      </b-button>
      <b-button
        variant="danger"
        :disabled="!rationale.trim()"
        data-test="confirm-decline"
        @click="$emit('decline', rationale.trim())"
      >
        {{ terms.nonConcur }}
      </b-button>
    </template>
  </b-modal>
</template>

<script>
import { RELOCATION_TERM } from "../../constants/terminology";

/**
 * DeclineRelocationModal - collects the required rationale for
 * non-concurring with a relocation proposal. The rationale is the
 * message back to the source author, so confirm stays disabled until it
 * is non-blank. Presentational: the caller owns the API call and
 * toasting. The field clears on every open. Display verbs come from the
 * centralized RELOCATION_TERM table (DISA-standard concur/non-concur).
 *
 * Props:
 *   - visible: Boolean (use with .sync)
 *   - sourceDisplayedName: String - the proposal being declined
 *
 * Emits:
 *   - decline: String - the trimmed rationale
 *   - update:visible: Boolean
 */
export default {
  name: "DeclineRelocationModal",
  props: {
    visible: {
      type: Boolean,
      default: false,
    },
    sourceDisplayedName: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      rationale: "",
      terms: RELOCATION_TERM,
    };
  },
};
</script>
