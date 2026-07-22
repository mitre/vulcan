<template>
  <b-modal
    :visible="visible"
    title="Accept relocation proposal"
    @change="$emit('update:visible', $event)"
  >
    <div v-if="loading" class="text-muted" data-test="preview-loading">
      <b-spinner small class="mr-1" /> Checking what this move would do...
    </div>

    <template v-else-if="preview">
      <template v-if="preview.valid">
        <p>
          Accepting moves <strong>{{ preview.source_displayed_name }}</strong> into
          <strong>{{ preview.target_component_name }}</strong> as requirement
          <strong>{{ preview.would_create.rule_id }}</strong
          >. The source requirement becomes history — its reviews stay frozen on the record.
        </p>
        <dl class="mb-0">
          <dt>Title</dt>
          <dd>{{ preview.would_create.title }}</dd>
          <dt>Status carried over</dt>
          <dd>{{ preview.would_create.status }}</dd>
        </dl>
      </template>
      <template v-else>
        <p>This proposal cannot be accepted into this component:</p>
        <ul data-test="preview-errors">
          <li v-for="error in preview.errors" :key="error">{{ error }}</li>
        </ul>
      </template>
    </template>

    <template #modal-footer>
      <b-button variant="outline-secondary" @click="$emit('update:visible', false)">
        Cancel
      </b-button>
      <b-button
        variant="warning"
        :disabled="!canConfirm"
        data-test="confirm-accept"
        @click="$emit('accept')"
      >
        Accept and move
      </b-button>
    </template>
  </b-modal>
</template>

<script>
/**
 * AcceptRelocationModal - the dry-run preview and explicit confirm for
 * accepting a relocation proposal. Presentational: the caller runs the
 * dry-run, passes the preview, owns the accept call and toasting. A
 * valid preview enables confirm; an invalid one renders every server
 * reason verbatim with confirm disabled — the server stays
 * authoritative.
 *
 * Props:
 *   - visible: Boolean (use with .sync)
 *   - marker: Object|null - the proposal row being adjudicated
 *   - preview: Object|null - the dry-run response body
 *   - loading: Boolean - dry-run in flight
 *
 * Emits:
 *   - accept (no payload - the caller holds the marker)
 *   - update:visible: Boolean
 */
export default {
  name: "AcceptRelocationModal",
  props: {
    visible: {
      type: Boolean,
      default: false,
    },
    marker: {
      type: Object,
      default: null,
    },
    preview: {
      type: Object,
      default: null,
    },
    loading: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    canConfirm() {
      return !this.loading && !!this.preview && this.preview.valid === true;
    },
  },
};
</script>
