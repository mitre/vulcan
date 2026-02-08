<template>
  <div>
    <b-form>
      <!-- Status and Severity row -->
      <div
        v-if="fields.displayed.includes('status') || fields.displayed.includes('rule_severity')"
        class="row"
      >
        <!-- status -->
        <b-form-group
          v-if="fields.displayed.includes('status')"
          :id="`ruleEditor-status-group-${mod}`"
          class="col-md-8"
        >
          <label :for="`ruleEditor-status-${mod}`">
            Status
            <b-icon
              v-if="tooltips['status']"
              v-b-tooltip.hover.html="tooltips['status']"
              icon="info-circle"
              aria-hidden="true"
            />
          </label>
          <b-form-select
            :id="`ruleEditor-status-${mod}`"
            :value="status_text"
            :input-class="inputClass('status')"
            :options="statuses"
            :disabled="disabled || fields.disabled.includes('status')"
            @input="$root.$emit('update:rule', { ...rule, status: $event })"
          />
          <b-form-valid-feedback v-if="hasValidFeedback('status')">
            {{ validFeedback["status"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('status')">
            {{ invalidFeedback["status"] }}
          </b-form-invalid-feedback>
        </b-form-group>

        <!-- rule_severity (moved here from below) -->
        <b-form-group
          v-if="fields.displayed.includes('rule_severity')"
          :id="`ruleEditor-rule_severity-top-group-${mod}`"
          class="col-md-4"
        >
          <label :for="`ruleEditor-rule_severity-top-${mod}`">
            Severity
            <b-icon
              v-if="tooltips['rule_severity']"
              v-b-tooltip.hover.html="tooltips['rule_severity']"
              icon="info-circle"
              aria-hidden="true"
            />
          </label>
          <b-form-select
            :id="`ruleEditor-rule_severity-top-${mod}`"
            :value="rule.rule_severity"
            :input-class="inputClass('rule_severity')"
            :options="severityOptions"
            :disabled="disabled || fields.disabled.includes('rule_severity')"
            @input="$root.$emit('update:rule', { ...rule, rule_severity: $event })"
          />
          <b-form-valid-feedback v-if="hasValidFeedback('rule_severity')">
            {{ validFeedback["rule_severity"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('rule_severity')">
            {{ invalidFeedback["rule_severity"] }}
          </b-form-invalid-feedback>
        </b-form-group>
      </div>

      <!-- severity_override_guidance (between severity and title for logical flow) -->
      <b-form-group
        v-if="fields.displayed.includes('severity_override_guidance')"
        :id="`ruleEditor-severity_override_guidance-group-${mod}`"
      >
        <label :for="`ruleEditor-severity_override_guidance-${mod}`">
          Severity Override Guidance
          <b-icon
            v-b-tooltip.hover.html="'Explain why the severity was changed from the SRG default'"
            icon="info-circle"
            aria-hidden="true"
          />
        </label>
        <MarkdownTextarea
          :id="`ruleEditor-severity_override_guidance-${mod}`"
          :value="
            rule.disa_rule_descriptions_attributes[0] &&
            rule.disa_rule_descriptions_attributes[0].severity_override_guidance
          "
          :input-class="inputClass('severity_override_guidance')"
          placeholder=""
          :disabled="disabled || fields.disabled.includes('severity_override_guidance')"
          rows="1"
          max-rows="99"
          @input="
            $root.$emit(
              'update:disaDescription',
              rule,
              { ...rule.disa_rule_descriptions_attributes[0], severity_override_guidance: $event },
              0,
            )
          "
        />
      </b-form-group>

      <!-- status_justification -->
      <template v-if="fields.displayed.includes('status_justification')">
        <b-form-group :id="`ruleEditor-status_justification-group-${mod}`">
          <label :for="`ruleEditor-status_justification-${mod}`">
            Status Justification
            <b-icon
              v-if="tooltips['status_justification']"
              v-b-tooltip.hover.html="tooltips['status_justification']"
              icon="info-circle"
              aria-hidden="true"
            />
          </label>
          <MarkdownTextarea
            :id="`ruleEditor-status_justification-${mod}`"
            :value="rule.status_justification"
            :input-class="inputClass('status_justification')"
            placeholder=""
            :disabled="disabled || fields.disabled.includes('status_justification')"
            rows="1"
            max-rows="99"
            @input="$root.$emit('update:rule', { ...rule, status_justification: $event })"
          />
          <b-form-valid-feedback v-if="hasValidFeedback('status_justification')">
            {{ validFeedback["status_justification"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('status_justification')">
            {{ invalidFeedback["status_justification"] }}
          </b-form-invalid-feedback>
        </b-form-group>
      </template>

      <template v-if="fields.displayed.includes('title')">
        <!-- title -->
        <b-form-group
          v-if="fields.displayed.includes('title')"
          :id="`ruleEditor-title-group-${mod}`"
        >
          <label :for="`ruleEditor-title-${mod}`">
            Title
            <b-icon
              v-if="tooltips['title']"
              v-b-tooltip.hover.html="tooltips['title']"
              icon="info-circle"
              aria-hidden="true"
            />
          </label>
          <MarkdownTextarea
            :id="`ruleEditor-title-${mod}`"
            :value="rule.title"
            :input-class="inputClass('title')"
            placeholder=""
            :disabled="disabled || fields.disabled.includes('title')"
            rows="1"
            max-rows="99"
            @input="$root.$emit('update:rule', { ...rule, title: $event })"
          />
          <b-form-valid-feedback v-if="hasValidFeedback('title')">
            {{ validFeedback["title"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('title')">
            {{ invalidFeedback["title"] }}
          </b-form-invalid-feedback>
        </b-form-group>
      </template>

      <!-- IA Control and CCI (always visible, read-only) -->
      <div v-if="rule.nist_control_family || rule.ident" class="row" data-testid="ia-control-cci">
        <b-form-group :id="`ruleEditor-ia_control-group-${mod}`" class="col-md-6">
          <label :for="`ruleEditor-ia_control-${mod}`">
            IA Control
            <b-icon
              v-b-tooltip.hover.html="
                'The NIST control family (e.g. AC-2) mapped to this requirement'
              "
              icon="info-circle"
              aria-hidden="true"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-ia_control-${mod}`"
            :value="rule.nist_control_family || '—'"
            readonly
            class="bg-light"
          />
        </b-form-group>
        <b-form-group :id="`ruleEditor-cci-group-${mod}`" class="col-md-6">
          <label :for="`ruleEditor-cci-${mod}`">
            CCI
            <b-icon
              v-b-tooltip.hover.html="
                'The Common Control Indicator (CCI) mapped to this requirement'
              "
              icon="info-circle"
              aria-hidden="true"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-cci-${mod}`"
            :value="rule.ident || '—'"
            readonly
            class="bg-light"
          />
        </b-form-group>
      </div>

      <template v-if="disa_fields">
        <!-- disa_rule_description -->
        <DisaRuleDescriptionForm
          v-if="rule.disa_rule_descriptions_attributes.length >= 1"
          :rule="rule"
          :index="0"
          :description="rule.disa_rule_descriptions_attributes[0]"
          :disabled="disabled"
          :fields="disa_fields"
        />
      </template>

      <!-- version -->
      <b-form-group
        v-if="fields.displayed.includes('version')"
        :id="`ruleEditor-version-group-${mod}`"
      >
        <label :for="`ruleEditor-version-${mod}`">
          Version
          <b-icon
            v-if="tooltips['version']"
            v-b-tooltip.hover.html="tooltips['version']"
            icon="info-circle"
            aria-hidden="true"
          />
        </label>
        <b-form-input
          :id="`ruleEditor-version-${mod}`"
          :value="rule.version"
          :input-class="inputClass('version')"
          placeholder=""
          :disabled="disabled || fields.disabled.includes('version')"
          @input="$root.$emit('update:rule', { ...rule, version: $event })"
        />
        <b-form-valid-feedback v-if="hasValidFeedback('version')">
          {{ validFeedback["version"] }}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('version')">
          {{ invalidFeedback["version"] }}
        </b-form-invalid-feedback>
      </b-form-group>

      <!-- artifact_description -->
      <b-form-group
        v-if="fields.displayed.includes('artifact_description')"
        :id="`ruleEditor-artifact_description-group-${mod}`"
      >
        <label :for="`ruleEditor-artifact_description-${mod}`">
          Artifact Description
          <b-icon
            v-if="tooltips['artifact_description']"
            v-b-tooltip.hover.html="tooltips['artifact_description']"
            icon="info-circle"
            aria-hidden="true"
          />
        </label>
        <MarkdownTextarea
          :id="`ruleEditor-artifact_description-${mod}`"
          :value="rule.artifact_description"
          :input-class="inputClass('artifact_description')"
          placeholder=""
          :disabled="disabled || fields.disabled.includes('artifact_description')"
          rows="1"
          max-rows="99"
          @input="$root.$emit('update:rule', { ...rule, artifact_description: $event })"
        />
        <b-form-valid-feedback v-if="hasValidFeedback('artifact_description')">
          {{ validFeedback["artifact_description"] }}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('artifact_description')">
          {{ invalidFeedback["artifact_description"] }}
        </b-form-invalid-feedback>
      </b-form-group>

      <template v-if="check_fields">
        <!-- checks: visibility controlled by check_fields config from composable -->
        <CheckForm
          v-if="rule.checks_attributes.length >= 1"
          :rule="rule"
          :index="0"
          :disabled="disabled"
          :fields="check_fields"
        />
      </template>

      <div class="row">
        <!-- fix_id -->
        <b-form-group
          v-if="fields.displayed.includes('fix_id')"
          :id="`ruleEditor-fix_id-group-${mod}`"
          class="col-6"
        >
          <label :for="`ruleEditor-fix_id-${mod}`">
            Fix ID
            <b-icon
              v-if="tooltips['fix_id']"
              v-b-tooltip.hover.html="tooltips['fix_id']"
              icon="info-circle"
              aria-hidden="true"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-fix_id-${mod}`"
            :value="rule.fix_id"
            :input-class="inputClass('fix_id')"
            placeholder=""
            :disabled="disabled || fields.disabled.includes('fix_id')"
            @input="$root.$emit('update:rule', { ...rule, fix_id: $event })"
          />
          <b-form-valid-feedback v-if="hasValidFeedback('fix_id')">
            {{ validFeedback["fix_id"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('fix_id')">
            {{ invalidFeedback["fix_id"] }}
          </b-form-invalid-feedback>
        </b-form-group>

        <!-- fixtext_fixref -->
        <b-form-group
          v-if="fields.displayed.includes('fixtext_fixref')"
          :id="`ruleEditor-fixtext_fixref-group-${mod}`"
          class="col-6"
        >
          <label :for="`ruleEditor-fixtext_fixref-${mod}`">
            Fix Text Reference
            <b-icon
              v-if="tooltips['fixtext_fixref']"
              v-b-tooltip.hover.html="tooltips['fixtext_fixref']"
              icon="info-circle"
              aria-hidden="true"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-fixtext_fixref-${mod}`"
            :value="rule.fixtext_fixref"
            :input-class="inputClass('fixtext_fixref')"
            placeholder=""
            :disabled="disabled || fields.disabled.includes('fixtext_fixref')"
            @input="$root.$emit('update:rule', { ...rule, fixtext_fixref: $event })"
          />
          <b-form-valid-feedback v-if="hasValidFeedback('fixtext_fixref')">
            {{ validFeedback["fixtext_fixref"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('fixtext_fixref')">
            {{ invalidFeedback["fixtext_fixref"] }}
          </b-form-invalid-feedback>
        </b-form-group>
      </div>

      <!-- fixtext -->
      <b-form-group
        v-if="fields.displayed.includes('fixtext')"
        :id="`ruleEditor-fixtext-group-${mod}`"
      >
        <label :for="`ruleEditor-fixtext-${mod}`">
          Fix
          <b-icon
            v-if="tooltips['fixtext']"
            v-b-tooltip.hover.html="tooltips['fixtext']"
            icon="info-circle"
            aria-hidden="true"
          />
        </label>
        <MarkdownTextarea
          :id="`ruleEditor-fixtext-${mod}`"
          :value="rule.satisfied_by.length > 0 ? rule.satisfied_by[0].fixtext : rule.fixtext"
          :input-class="inputClass('fixtext')"
          placeholder=""
          :disabled="disabled || fields.disabled.includes('fixtext')"
          rows="1"
          max-rows="99"
          @input="$root.$emit('update:rule', { ...rule, fixtext: $event })"
        />
        <b-form-valid-feedback v-if="hasValidFeedback('fixtext')">
          {{ validFeedback["fixtext"] }}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('fixtext')">
          {{ invalidFeedback["fixtext"] }}
        </b-form-invalid-feedback>
      </b-form-group>

      <div class="row">
        <!-- rule_weight -->
        <b-form-group
          v-if="fields.displayed.includes('rule_weight')"
          :id="`ruleEditor-rule_weight-group-${mod}`"
          class="col-6"
        >
          <label :for="`ruleEditor-rule_weight-${mod}`">
            Rule Weight
            <b-icon
              v-if="tooltips['rule_weight']"
              v-b-tooltip.hover.html="tooltips['rule_weight']"
              icon="info-circle"
              aria-hidden="true"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-rule_weight-${mod}`"
            :value="rule.rule_weight"
            :input-class="inputClass('rule_weight')"
            placeholder=""
            :disabled="disabled || fields.disabled.includes('rule_weight')"
            @input="$root.$emit('update:rule', { ...rule, rule_weight: $event })"
          />
          <b-form-valid-feedback v-if="hasValidFeedback('rule_weight')">
            {{ validFeedback["rule_weight"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('rule_weight')">
            {{ invalidFeedback["rule_weight"] }}
          </b-form-invalid-feedback>
        </b-form-group>
      </div>

      <div class="row">
        <!-- ident -->
        <b-form-group
          v-if="fields.displayed.includes('ident')"
          :id="`ruleEditor-ident-group-${mod}`"
          class="col-4"
        >
          <label :for="`ruleEditor-ident-${mod}`">
            Identity
            <b-icon
              v-if="tooltips['ident']"
              v-b-tooltip.hover.html="tooltips['ident']"
              icon="info-circle"
              aria-hidden="true"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-ident-${mod}`"
            :value="rule.ident"
            :input-class="inputClass('ident')"
            placeholder=""
            :disabled="disabled || fields.disabled.includes('ident')"
            @input="$root.$emit('update:rule', { ...rule, ident: $event })"
          />
          <b-form-valid-feedback v-if="hasValidFeedback('ident')">
            {{ validFeedback["ident"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('ident')">
            {{ invalidFeedback["ident"] }}
          </b-form-invalid-feedback>
        </b-form-group>

        <!-- ident_system -->
        <b-form-group
          v-if="fields.displayed.includes('ident_system')"
          :id="`ruleEditor-ident_system-group-${mod}`"
          class="col-8"
        >
          <label :for="`ruleEditor-ident_system-${mod}`">
            Identity System
            <b-icon
              v-if="tooltips['ident_system']"
              v-b-tooltip.hover.html="tooltips['ident_system']"
              icon="info-circle"
              aria-hidden="true"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-ident_system-${mod}`"
            :value="rule.ident_system"
            :input-class="inputClass('ident_system')"
            placeholder=""
            :disabled="disabled || fields.disabled.includes('ident_system')"
            @input="$root.$emit('update:rule', { ...rule, ident_system: $event })"
          />
          <b-form-valid-feedback v-if="hasValidFeedback('ident_system')">
            {{ validFeedback["ident_system"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('ident_system')">
            {{ invalidFeedback["ident_system"] }}
          </b-form-invalid-feedback>
        </b-form-group>
      </div>

      <!-- vendor_comments -->
      <b-form-group
        v-if="fields.displayed.includes('vendor_comments')"
        :id="`ruleEditor-vendor_comments-group-${mod}`"
      >
        <label :for="`ruleEditor-vendor_comments-${mod}`">
          Vendor Comments
          <b-icon
            v-if="tooltips['vendor_comments']"
            v-b-tooltip.hover.html="tooltips['vendor_comments']"
            icon="info-circle"
            aria-hidden="true"
          />
        </label>
        <MarkdownTextarea
          :id="`ruleEditor-vendor_comments-${mod}`"
          :value="rule.vendor_comments"
          :input-class="inputClass('vendor_comments')"
          placeholder=""
          :disabled="disabled || fields.disabled.includes('vendor_comments')"
          rows="1"
          max-rows="99"
          @input="$root.$emit('update:rule', { ...rule, vendor_comments: $event })"
        />
        <b-form-valid-feedback v-if="hasValidFeedback('vendor_comments')">
          {{ validFeedback["vendor_comments"] }}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('vendor_comments')">
          {{ invalidFeedback["vendor_comments"] }}
        </b-form-invalid-feedback>
      </b-form-group>

      <AdditionalQuestions
        :additional_questions="additional_questions"
        :disabled="disabled && !force_enable_additional_questions"
        :rule="rule"
      />
    </b-form>
  </div>
</template>

<script>
import FormFeedbackMixinVue from "../../../mixins/FormFeedbackMixin.vue";
import MarkdownTextarea from "../../shared/MarkdownTextarea.vue";
import DisaRuleDescriptionForm from "./DisaRuleDescriptionForm";
import AdditionalQuestions from "./AdditionalQuestions";
import CheckForm from "./CheckForm";
import { SEVERITY_OPTIONS } from "../../../constants/terminology";

export default {
  name: "RuleForm",
  components: { DisaRuleDescriptionForm, CheckForm, AdditionalQuestions, MarkdownTextarea },
  mixins: [FormFeedbackMixinVue],
  props: {
    rule: {
      type: Object,
      required: true,
    },
    statuses: {
      type: Array,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: true,
    },
    force_enable_additional_questions: {
      type: Boolean,
      default: false,
    },
    disa_fields: {
      type: Object,
    },
    check_fields: {
      type: Object,
    },
    additional_questions: {
      type: Array,
      default: () => [],
    },
    fields: {
      type: Object,
      default: () => {
        return {
          displayed: [
            "status",
            "status_justification",
            "title",
            "version",
            "rule_severity",
            "rule_weight",
            "artifact_description",
            "fix_id",
            "fixtext_fixref",
            "fixtext",
            "ident",
            "ident_system",
            "vendor_comments",
          ],
          disabled: [],
        };
      },
    },
  },
  data: function () {
    return {
      mod: Math.floor(Math.random() * 1000),
    };
  },
  computed: {
    severityOptions: function () {
      return SEVERITY_OPTIONS;
    },
    status_text: function () {
      return this.rule.satisfied_by.length > 0 ? "Applicable - Configurable" : this.rule.status;
    },
    tooltips: function () {
      return {
        status:
          "Applicable – Configurable: The product requires configuration or the application of policy settings to achieve compliance.<br><br>Applicable – Inherently Meets: The product is compliant in its initial state and cannot be subsequently reconfigured to a noncompliant state.<br><br> Applicable – Does Not Meet: There are no technical means to achieve compliance.<br><br> Not Applicable: The requirement addresses a capability or use case that the product does not support.",
        status_justification: ["Applicable - Configurable", "Not Yet Determined"].includes(
          this.rule.status,
        )
          ? null
          : "Explain the rationale behind selecting one of the above statuses",
        title: "Describe the vulnerability for this control",
        version: null,
        rule_severity:
          "CAT I (High): a grave or critical problem, CAT II (Medium): a fairly serious problem, CAT III (Low): a relatively minor problem",
        rule_weight: null,
        artifact_description:
          this.rule.status === "Not Applicable"
            ? "Provide evidence that the control is not applicable to the system - code files, documentation, screenshots, etc."
            : [
                  "Not Yet Determined",
                  "Applicable - Configurable",
                  "Applicable - Does Not Meet",
                ].includes(this.rule.status)
              ? null
              : "Provide evidence that the control is inherently met by the system - code files, documentation, screenshots, etc.",
        fix_id: null,
        fixtext_fixref: null,
        fixtext:
          this.rule.status === "Applicable - Configurable"
            ? "Describe how to correctly configure the requirement to remediate the system vulnerability"
            : [
                  "Applicable - Does Not Meet",
                  "Applicable - Inherently Meets",
                  "Not Applicable",
                ].includes(this.rule.status)
              ? null
              : "Explain how to fix the vulnerability discussed",
        ident:
          "Typically the Common Control Indicator (CCI) that maps to the vulnerability being discussed in this control",
        ident_system: null,
        vendor_comments: "Provide context to a reviewing authority; not a published field",
      };
    },
  },
};
</script>

<style>
.tooltip-inner {
  max-width: 300px;
}
</style>
