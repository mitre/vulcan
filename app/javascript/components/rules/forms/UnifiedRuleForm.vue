<template>
  <div>
    <!-- Lock status badge -->
    <div v-if="lockStatusBadge" class="mb-2" data-testid="lock-status-badge">
      <b-badge :variant="lockStatusBadge.variant" class="px-2 py-1">
        <b-icon :icon="lockStatusBadge.icon" class="mr-1" />
        {{ lockStatusBadge.text }}
      </b-badge>
    </div>

    <!-- Field state legend (only when non-default states are active) -->
    <div
      v-if="activeFieldStates.length > 0"
      class="d-flex align-items-center mb-2 small text-muted"
      data-testid="field-state-legend"
    >
      <span class="mr-2">Field states:</span>
      <span
        v-if="activeFieldStates.includes('section-locked')"
        class="mr-3 d-inline-flex align-items-center"
      >
        <span
          class="d-inline-block mr-1"
          style="
            width: 12px;
            height: 12px;
            border-left: 3px solid #ffc107;
            background: rgba(255, 193, 7, 0.15);
          "
        />
        Section locked
      </span>
      <span
        v-if="activeFieldStates.includes('under-review')"
        class="mr-3 d-inline-flex align-items-center"
      >
        <span
          class="d-inline-block mr-1"
          style="
            width: 12px;
            height: 12px;
            border-left: 3px solid #17a2b8;
            background: rgba(23, 162, 184, 0.15);
          "
        />
        Under review
      </span>
      <span
        v-if="activeFieldStates.includes('whole-locked')"
        class="mr-3 d-inline-flex align-items-center"
      >
        <span
          class="d-inline-block mr-1"
          style="
            width: 12px;
            height: 12px;
            border-left: 3px solid #6c757d;
            background: rgba(108, 117, 125, 0.15);
          "
        />
        Locked
      </span>
    </div>

    <b-form>
      <RuleForm
        :rule="rule"
        :statuses="statuses"
        :disabled="isFormDisabled"
        :fields="ruleFormFields"
        :locked-sections="lockedSections"
        :can-manage-section-locks="canManageSectionLocks"
        :field-state-class-fn="fieldStateClass"
        :disa_fields="showDisaSection ? disaDescriptionFields : undefined"
        :check_fields="showChecksSection ? checkFormFields : undefined"
        :force_enable_additional_questions="forceEnableAdditionalQuestions"
        :additional_questions="additional_questions"
        @toggle-section-lock="onToggleSectionLock"
      />
    </b-form>

    <RuleSecurityRequirementsGuideInformation
      :nist_control_family="rule.nist_control_family"
      :srg_rule="rule.srg_rule_attributes"
      :cci="rule.ident"
      :srg_info="rule.srg_info"
    />

    <!-- Status hint -->
    <div v-if="effectiveStatus !== 'Applicable - Configurable'">
      <hr />
      <p>
        <small>Some fields are hidden due to the control's status.</small>
      </p>
    </div>
  </div>
</template>

<script>
import { computed } from "vue";
import RuleForm from "./RuleForm.vue";
import RuleSecurityRequirementsGuideInformation from "../RuleSecurityRequirementsGuideInformation.vue";
import { useRuleFormFields } from "../../../composables/useRuleFormFields";
import "../../../styles/field-states.css";

export default {
  name: "UnifiedRuleForm",
  components: {
    RuleForm,
    RuleSecurityRequirementsGuideInformation,
  },
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
    advancedMode: {
      type: Boolean,
      default: false,
    },
    additional_questions: {
      type: Array,
      default: () => [],
    },
    effectivePermissions: {
      type: String,
      default: "",
    },
  },
  setup(props) {
    // Use computed refs (not toRef) for Vue 2.7 reactivity safety
    const ruleRef = computed(() => props.rule);
    const advancedRef = computed(() => props.advancedMode);
    const readOnlyRef = computed(() => props.readOnly);

    const composable = useRuleFormFields(ruleRef, advancedRef, { readOnly: readOnlyRef });

    return {
      ...composable,
    };
  },
  data() {
    return {};
  },
  computed: {
    lockStatusBadge() {
      const r = this.rule;
      if (r.locked) {
        return { variant: "secondary", icon: "lock-fill", text: "Rule Locked" };
      }
      if (r.review_requestor_id) {
        return { variant: "info", icon: "eye", text: "Under Review" };
      }
      const sections = r.locked_fields ? Object.keys(r.locked_fields) : [];
      if (sections.length > 0) {
        const label = sections.length === 1 ? sections[0] : `${sections.length} sections`;
        return { variant: "warning", icon: "lock-fill", text: `${label} locked` };
      }
      return null;
    },
    lockedSections() {
      return this.rule.locked_fields || {};
    },
    canManageSectionLocks() {
      if (this.readOnly || this.rule.locked || this.rule.review_requestor_id) return false;
      return ["admin", "reviewer"].includes(this.effectivePermissions);
    },
  },
  methods: {
    onToggleSectionLock(section) {
      this.$emit("toggle-section-lock", section);
    },
  },
};
</script>
