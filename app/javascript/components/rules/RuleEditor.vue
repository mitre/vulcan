<template>
  <div class="d-flex flex-column h-100">
    <!-- Actions Toolbar — pinned above scroll region -->
    <div data-test="rule-toolbar-pinned" class="flex-shrink-0">
      <RuleActionsToolbar
        :rule="rule"
        :effective-permissions="effectivePermissions"
        :read-only="readOnly"
        :document-type="documentType"
        :pending-relocation="pendingRelocation"
        :view-only-page="viewOnlyPage"
        @open-relocation-modal="$emit('open-relocation-modal')"
        @clone="$emit('clone')"
        @delete="$emit('delete')"
        @save="$emit('save', $event)"
        @comment="$emit('comment', $event)"
        @open-review-modal="$emit('open-review-modal')"
        @open-related-modal="$emit('open-related-modal')"
        @open-composer="$emit('open-composer', $event)"
        @lock="$emit('lock', $event)"
        @unlock="$emit('unlock', $event)"
        @toggle-panel="$emit('toggle-panel', $event)"
      />
    </div>

    <!-- Tabs + content — scrollable region -->
    <div data-test="rule-content-scrollable" class="flex-grow-1 overflow-auto">
      <b-tabs>
        <b-tab title="Documentation" class="pt-3" active>
          <!-- Advanced Fields Toggle (always visible) -->
          <div class="mb-3 d-flex align-items-center justify-content-between">
            <div data-testid="advanced-fields-toggle">
              <b-form-checkbox
                v-model="localAdvancedFields"
                name="advanced-fields-toggle"
                class="d-inline-block"
                switch
                size="sm"
                @change="onAdvancedFieldsToggle"
              >
                <small class="font-weight-bold">Advanced Fields</small>
              </b-form-checkbox>
              <small class="text-muted d-block ml-4" data-testid="advanced-fields-helper">
                Most users <strong>do not need</strong> to modify advanced fields.
              </small>
            </div>
            <div data-testid="autosave-toggle" class="text-right">
              <b-form-checkbox
                :checked="autosaveEnabled"
                :disabled="autosaveDisabledReason !== null"
                switch
                size="sm"
                @change="$emit('toggle-autosave')"
              >
                <small :class="autosaveColorClass"> Auto-save {{ autosaveLabel }} </small>
              </b-form-checkbox>
              <small
                v-if="autosaveDirty && autosaveEnabled && !autosaveDisabledReason"
                class="text-warning d-block"
              >
                Unsaved changes...
              </small>
            </div>
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
              Advanced fields provide additional control over
              {{ advancedNoun }} metadata. Most users do not need to modify these fields.
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
            :document-type="documentType"
            :advanced-mode="localAdvancedFields"
            :additional_questions="additional_questions"
            :effective-permissions="effectivePermissions"
            @toggle-section-lock="$emit('toggle-section-lock', $event)"
            @open-composer="$emit('open-composer', $event)"
            @view-comments="$emit('view-comments', $event)"
          />
        </b-tab>
        <!-- InSpec is Rule-only content — authored SRG rows carry no
             inspec keys (the backend omits them), so the tabs are
             absent for SRG-kind rather than empty. -->
        <b-tab v-if="!isSrg" title="Test Script" lazy>
          <InspecControlEditor :rule="rule" field="inspec_control_body" :read-only="readOnly" />
        </b-tab>
        <b-tab v-if="!isSrg" title="Generated Control (Read-Only)" lazy>
          <InspecControlEditor :rule="rule" field="inspec_control_file" :read-only="true" />
        </b-tab>
      </b-tabs>
    </div>
  </div>
</template>

<script>
import UnifiedRuleForm from "./forms/UnifiedRuleForm.vue";
import InspecControlEditor from "./InspecControlEditor.vue";
import RuleActionsToolbar from "./RuleActionsToolbar.vue";
import { ruleTerm } from "../../constants/terminology";

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
    documentType: {
      type: String,
      default: "stig",
    },
    // The open requirement's pending relocation record, or null.
    pendingRelocation: {
      type: Object,
      default: null,
    },
    // True on the read-only component view page — passed through to the
    // toolbar so read-only tooltips can state the true reason (mode vs
    // role) and point at the editor.
    viewOnlyPage: {
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
    autosaveEnabled: {
      type: Boolean,
      default: false,
    },
    autosaveDirty: {
      type: Boolean,
      default: false,
    },
  },
  data: function () {
    return {
      showConfirmModal: false,
      localAdvancedFields: this.advanced_fields,
    };
  },
  computed: {
    isSrg() {
      return this.documentType === "srg";
    },
    advancedNoun() {
      return ruleTerm(this.documentType).singular.toLowerCase();
    },
    autosaveDisabledReason() {
      if (this.readOnly) return "view";
      if (this.rule.locked) return "locked";
      if (this.rule.review_requestor_id) return "review";
      return null;
    },
    autosaveLabel() {
      const reason = this.autosaveDisabledReason;
      if (reason === "locked") return "(locked)";
      if (reason === "review") return "(under review)";
      if (reason === "view") return "OFF";
      return this.autosaveEnabled ? "ON" : "OFF";
    },
    autosaveColorClass() {
      if (this.autosaveDisabledReason) return "text-muted";
      return this.autosaveEnabled ? "text-success font-weight-bold" : "text-muted";
    },
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
        // Enabling: v-model already toggled to true — reset immediately
        // and show confirmation. Only set true after user confirms.
        this.$nextTick(() => {
          this.localAdvancedFields = false;
        });
        this.showConfirmModal = true;
      } else {
        // Disabling: apply immediately (no confirmation needed)
        this.$emit("toggle-advanced-fields", false);
      }
    },
    confirmEnableAdvanced() {
      this.showConfirmModal = false;
      this.localAdvancedFields = true;
      this.$emit("toggle-advanced-fields", true);
    },
    cancelEnableAdvanced() {
      this.showConfirmModal = false;
      // Checkbox stays off — user canceled
    },
  },
};
</script>

<style scoped></style>
