<template>
  <b-modal
    :visible="visible"
    title="Mark for relocation"
    @change="$emit('update:visible', $event)"
    @show="token = ''"
  >
    <p>
      Mark <strong>{{ ruleDisplayName }}</strong> for relocation to another family. The pending
      marker feeds the destination family's backlog; the requirement itself does not change until
      the move is executed.
    </p>
    <b-form-group
      label="Destination family technology token"
      description="The family's technology token — for example CTR, GPOS, or DB"
    >
      <b-form-input
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
        :disabled="!token"
        data-test="confirm-mark"
        @click="$emit('mark', token)"
      >
        Mark for relocation
      </b-button>
    </template>
  </b-modal>
</template>

<script>
/**
 * MarkRelocationModal - collects the destination family token for a
 * relocation marker. Emits mark with the uppercased token; the caller
 * owns the API call and toasting. The input clears on every open.
 *
 * Props:
 *   - visible: Boolean (use with .sync)
 *   - ruleDisplayName: String - the requirement being marked
 *
 * Emits:
 *   - mark: String - the destination technology token
 *   - update:visible: Boolean
 */
export default {
  name: "MarkRelocationModal",
  props: {
    visible: {
      type: Boolean,
      default: false,
    },
    ruleDisplayName: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      token: "",
    };
  },
};
</script>
