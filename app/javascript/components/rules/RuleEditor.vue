<template>
  <div>
    <!-- Actions Toolbar (above tabs — visible on all tabs) -->
    <RuleActionsToolbar
      :rule="rule"
      :effective-permissions="effectivePermissions"
      :read-only="readOnly"
      @clone="$emit('clone')"
      @delete="$emit('delete')"
      @save="$emit('save', $event)"
      @comment="$emit('comment', $event)"
      @open-review-modal="$emit('open-review-modal')"
      @open-related-modal="$emit('open-related-modal')"
      @lock="$emit('lock', $event)"
      @unlock="$emit('unlock', $event)"
      @toggle-panel="$emit('toggle-panel', $event)"
    />

    <b-tabs>
      <b-tab title="Documentation" class="pt-3" active>
        <!-- Advanced Fields Toggle (always visible) -->
        <div class="mb-3" data-testid="advanced-fields-toggle">
          <b-form-checkbox
            v-model="localAdvancedFields"
            name="advanced-fields-toggle"
            class="d-inline-block font-weight-bold"
            switch
            @change="onAdvancedFieldsToggle"
          >
            Advanced Fields
          </b-form-checkbox>
          <small class="text-muted d-block" data-testid="advanced-fields-helper">
            Most users <strong>do not need</strong> to modify advanced fields.
          </small>
        </div>

        <!-- Confirmation Modal for enabling advanced fields -->
        <b-modal
          v-model="showConfirmModal"
          title="Enable Advanced Fields?"
          data-testid="advanced-fields-confirm-modal"
          @ok="confirmEnableAdvanced"
          @cancel="cancelEnableAdvanced"
          @close="cancelEnableAdvanced"
        >
          <p>
            Advanced fields provide additional control over rule metadata. Most users do not need to
            modify these fields.
          </p>
          <p class="mb-0">Are you sure you want to enable advanced fields?</p>
          <template #modal-footer="{ ok, cancel }">
            <b-button
              variant="secondary"
              data-testid="advanced-fields-cancel-btn"
              @click="cancel()"
            >
              Cancel
            </b-button>
            <b-button variant="primary" data-testid="advanced-fields-confirm-btn" @click="ok()">
              Enable Advanced Fields
            </b-button>
          </template>
        </b-modal>

        <UnifiedRuleForm
          :rule="rule"
          :statuses="statuses"
          :read-only="readOnly"
          :advanced-mode="localAdvancedFields"
          :additional_questions="additional_questions"
          :effective-permissions="effectivePermissions"
          @toggle-section-lock="$emit('toggle-section-lock', $event)"
        />
      </b-tab>
      <b-tab title="Test Script" lazy>
        <InspecControlEditor :rule="rule" field="inspec_control_body" :read-only="readOnly" />
      </b-tab>
      <b-tab title="InSpec Control (Read-Only)" lazy>
        <InspecControlEditor :rule="rule" field="inspec_control_file" :read-only="true" />
      </b-tab>
    </b-tabs>
  </div>
</template>

<script>
import UnifiedRuleForm from "./forms/UnifiedRuleForm.vue";
import InspecControlEditor from "./InspecControlEditor.vue";
import RuleActionsToolbar from "./RuleActionsToolbar.vue";

export default {
  name: "RuleEditor",
  components: { UnifiedRuleForm, InspecControlEditor, RuleActionsToolbar },
  props: {
    rule: {
      type: Object,
      required: true,
    },
    statuses: {
      type: Array,
      required: true,
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
    effectivePermissions: {
      type: String,
      default: "",
    },
    advanced_fields: {
      type: Boolean,
      default: false,
    },
    additional_questions: {
      type: Array,
      default: () => [],
    },
  },
  data: function () {
    return {
      showConfirmModal: false,
      localAdvancedFields: this.advanced_fields,
    };
  },
  watch: {
    // Sync prop changes to local state (e.g., after API update)
    advanced_fields(newVal) {
      this.localAdvancedFields = newVal;
    },
  },
  methods: {
    onAdvancedFieldsToggle(newValue) {
      if (newValue) {
        // Enabling: show confirmation dialog (checkbox already toggled visually)
        this.showConfirmModal = true;
      } else {
        // Disabling: emit immediately (no confirmation needed)
        this.$emit("toggle-advanced-fields", false);
      }
    },
    confirmEnableAdvanced() {
      this.showConfirmModal = false;
      this.$emit("toggle-advanced-fields", true);
    },
    cancelEnableAdvanced() {
      this.showConfirmModal = false;
      // Reset checkbox to match prop (user canceled, so revert visual state)
      this.localAdvancedFields = this.advanced_fields;
    },
  },
};
</script>

<style scoped></style>
