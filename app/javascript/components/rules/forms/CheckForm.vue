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

    <!-- content — Check Text. Primary user-facing field of the "Check"
         section, so it owns the SectionCommentIcon (visual order, not
         data-structure order, drives where the icon lives). -->
    <RuleFormGroup
      v-slot="{ inputId, isDisabled }"
      v-bind="formGroupPropsWithCommentIcon"
      field-name="content"
      label="Check"
      :tooltip="tooltips['content']"
      id-prefix="ruleEditor-check"
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
      v-on="commentIconListeners"
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
import { toRef } from "vue";
import { useFormFeedback } from "../../../composables/useFormFeedback";
import { useCommentIconHost } from "../../../composables/useCommentIconHost";
import { ruleArray } from "../../../utils/ruleArray";
import MarkdownTextarea from "../../shared/MarkdownTextarea.vue";
import RuleFormGroup from "../../shared/RuleFormGroup.vue";

// Statuses whose check-content field carries no tooltip.
const CONTENT_TOOLTIP_EXEMPT_STATUSES = Object.freeze({
  "Applicable - Does Not Meet": true,
  "Applicable - Inherently Meets": true,
  "Not Applicable": true,
});

export default {
  name: "CheckForm",
  components: { MarkdownTextarea, RuleFormGroup },
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
    showSectionLocks: {
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
    validFeedback: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    invalidFeedback: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  setup(props, { emit }) {
    const { commentIconListeners, commentIconProps } = useCommentIconHost({
      rule: toRef(props, "rule"),
      emit,
    });
    const { inputClass } = useFormFeedback(props);
    return { commentIconListeners, commentIconProps, inputClass };
  },
  computed: {
    check: function () {
      const targetRule = ruleArray(this.rule, "satisfied_by")[0] || this.rule;

      return ruleArray(targetRule, "checks_attributes")[0] || {};
    },
    tooltips: function () {
      // Rules with satisfied_by behave like Applicable - Configurable
      const isConfigurable =
        ruleArray(this.rule, "satisfied_by").length > 0 ||
        this.rule.status === "Applicable - Configurable";
      // Status-KEYED data lookup: statuses outside the map (any vocabulary)
      // fall to the default check-content text.
      const contentTooltipExempt = Object.hasOwn(CONTENT_TOOLTIP_EXEMPT_STATUSES, this.rule.status);
      return {
        system: null,
        content_ref_name: null,
        content_ref_href: null,
        content: isConfigurable
          ? "Describe how to validate that the remediation has been properly implemented"
          : contentTooltipExempt
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
        showSectionLocks: this.showSectionLocks,
        validFeedback: this.validFeedback || {},
        invalidFeedback: this.invalidFeedback || {},
      };
    },
    formGroupPropsWithCommentIcon() {
      return { ...this.formGroupProps, ...this.commentIconProps };
    },
  },
};
</script>

<style scoped></style>
