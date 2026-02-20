<template>
  <div v-if="check._destroy != true">
    <!-- system -->
    <RuleFormGroup
      v-slot="{ inputId, isDisabled }"
      v-bind="formGroupProps"
      field-name="system"
      label="System"
      :tooltip="tooltips['system']"
      id-prefix="ruleEditor-check"
    >
      <b-form-input
        :id="inputId"
        :value="check.system"
        :input-class="inputClass('system')"
        placeholder=""
        :disabled="isDisabled"
        @input="$root.$emit('update:check', rule, { ...check, system: $event }, index)"
      />
    </RuleFormGroup>

    <!-- content_ref_name -->
    <RuleFormGroup
      v-slot="{ inputId, isDisabled }"
      v-bind="formGroupProps"
      field-name="content_ref_name"
      label="Reference Name"
      :tooltip="tooltips['content_ref_name']"
      id-prefix="ruleEditor-check"
    >
      <b-form-input
        :id="inputId"
        :value="check.content_ref_name"
        :input-class="inputClass('content_ref_name')"
        placeholder=""
        :disabled="isDisabled"
        @input="$root.$emit('update:check', rule, { ...check, content_ref_name: $event }, index)"
      />
    </RuleFormGroup>

    <!-- content_ref_href -->
    <RuleFormGroup
      v-slot="{ inputId, isDisabled }"
      v-bind="formGroupProps"
      field-name="content_ref_href"
      label="Reference Link"
      :tooltip="tooltips['content_ref_href']"
      id-prefix="ruleEditor-check"
    >
      <b-form-input
        :id="inputId"
        :value="check.content_ref_href"
        :input-class="inputClass('content_ref_href')"
        placeholder=""
        :disabled="isDisabled"
        @input="$root.$emit('update:check', rule, { ...check, content_ref_href: $event }, index)"
      />
    </RuleFormGroup>

    <!-- content -->
    <RuleFormGroup
      v-slot="{ inputId, isDisabled }"
      v-bind="formGroupProps"
      field-name="content"
      label="Check"
      :tooltip="tooltips['content']"
      id-prefix="ruleEditor-check"
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
    >
      <MarkdownTextarea
        :id="inputId"
        :value="check.content"
        :input-class="inputClass('content')"
        placeholder=""
        :disabled="isDisabled"
        rows="1"
        max-rows="99"
        @input="$root.$emit('update:check', rule, { ...check, content: $event }, index)"
      />
    </RuleFormGroup>
  </div>
</template>

<script>
import FormFeedbackMixinVue from "../../../mixins/FormFeedbackMixin.vue";
import MarkdownTextarea from "../../shared/MarkdownTextarea.vue";
import RuleFormGroup from "../../shared/RuleFormGroup.vue";

export default {
  name: "CheckForm",
  components: { MarkdownTextarea, RuleFormGroup },
  mixins: [FormFeedbackMixinVue],
  // `rule` and `index` are necessary if edits are to be made
  props: {
    rule: {
      type: Object,
    },
    index: {
      type: Number,
      default: -1,
    },
    disabled: {
      type: Boolean,
      required: true,
    },
    lockedSections: {
      type: Object,
      default: () => ({}),
    },
    canManageSectionLocks: {
      type: Boolean,
      default: false,
    },
    fieldStateClassFn: {
      type: Function,
      default: () => () => "",
    },
    fields: {
      type: Object,
      default: () => {
        return {
          displayed: ["system", "content_ref_name", "content_ref_href", "content"],
          disabled: [],
        };
      },
    },
  },
  computed: {
    check: function () {
      const targetRule =
        this.rule.satisfied_by && this.rule.satisfied_by.length > 0
          ? this.rule.satisfied_by[0]
          : this.rule;

      return targetRule && targetRule.checks_attributes && targetRule.checks_attributes.length > 0
        ? targetRule.checks_attributes[0]
        : {};
    },
    tooltips: function () {
      // Rules with satisfied_by behave like Applicable - Configurable
      // Note: satisfied_by may be undefined for STIG rules, so we check for its existence first
      const isConfigurable =
        (this.rule.satisfied_by && this.rule.satisfied_by.length > 0) ||
        this.rule.status === "Applicable - Configurable";
      return {
        system: null,
        content_ref_name: null,
        content_ref_href: null,
        content: isConfigurable
          ? "Describe how to validate that the remediation has been properly implemented"
          : [
                "Applicable - Does Not Meet",
                "Applicable - Inherently Meets",
                "Not Applicable",
              ].includes(this.rule.status)
            ? null
            : "Describe how to check for the presence of the vulnerability",
      };
    },
    formGroupProps() {
      return {
        fields: this.fields,
        fieldStateClassFn: this.fieldStateClassFn,
        disabled: this.disabled,
        lockedSections: this.lockedSections,
        canManageSectionLocks: this.canManageSectionLocks,
        validFeedback: this.validFeedback || {},
        invalidFeedback: this.invalidFeedback || {},
      };
    },
  },
};
</script>

<style scoped></style>
