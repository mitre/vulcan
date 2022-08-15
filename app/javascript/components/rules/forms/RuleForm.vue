<template>
  <div>
    <b-form>
      <!-- status -->
      <template v-if="fields.displayed.includes('status')">
        <b-form-group :id="`ruleEditor-status-group-${mod}`">
          <label :for="`ruleEditor-status-${mod}`">
            Status
            <i
              v-if="tooltips['status']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['status']"
            />
          </label>
          <b-form-select
            :id="`ruleEditor-status-${mod}`"
            :value="status_text"
            :class="inputClass('status')"
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
      </template>

      <!-- status_justification -->
      <template v-if="fields.displayed.includes('status_justification')">
        <b-form-group :id="`ruleEditor-status_justification-group-${mod}`">
          <label :for="`ruleEditor-status_justification-${mod}`">
            Status Justification
            <i
              v-if="tooltips['status_justification']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['status_justification']"
            />
          </label>
          <b-form-textarea
            :id="`ruleEditor-status_justification-${mod}`"
            :value="rule.status_justification"
            :class="inputClass('status_justification')"
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
            <i
              v-if="tooltips['title']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['title']"
            />
          </label>
          <b-form-textarea
            :id="`ruleEditor-title-${mod}`"
            :value="rule.title"
            :class="inputClass('title')"
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
          <i
            v-if="tooltips['version']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['version']"
          />
        </label>
        <b-form-input
          :id="`ruleEditor-version-${mod}`"
          :value="rule.version"
          :class="inputClass('version')"
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
          <i
            v-if="tooltips['artifact_description']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['artifact_description']"
          />
        </label>
        <b-form-textarea
          :id="`ruleEditor-artifact_description-${mod}`"
          :value="rule.artifact_description"
          :class="inputClass('artifact_description')"
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
        <!-- checks -->
        <CheckForm
          v-if="rule.status == 'Applicable - Configurable' && rule.checks_attributes.length >= 1"
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
            <i
              v-if="tooltips['fix_id']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['fix_id']"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-fix_id-${mod}`"
            :value="rule.fix_id"
            :class="inputClass('fix_id')"
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
            <i
              v-if="tooltips['fixtext_fixref']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['fixtext_fixref']"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-fixtext_fixref-${mod}`"
            :value="rule.fixtext_fixref"
            :class="inputClass('fixtext_fixref')"
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
          <i
            v-if="tooltips['fixtext']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['fixtext']"
          />
        </label>
        <b-form-textarea
          :id="`ruleEditor-fixtext-${mod}`"
          :value="rule.satisfied_by.length > 0 ? rule.satisfied_by[0].fixtext : rule.fixtext"
          :class="inputClass('fixtext')"
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
        <!-- rule_severity -->
        <b-form-group
          v-if="fields.displayed.includes('rule_severity')"
          :id="`ruleEditor-rule_severity-group-${mod}`"
          class="col-6"
        >
          <label :for="`ruleEditor-rule_severity-${mod}`">
            Severity
            <i
              v-if="tooltips['rule_severity']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['rule_severity']"
            />
          </label>
          <b-form-select
            :id="`ruleEditor-rule_severity-${mod}`"
            :value="rule.rule_severity"
            :class="inputClass('rule_severity')"
            :options="severities"
            :disabled="disabled || fields.disabled.includes('rule_severity')"
            @input="$root.$emit('update:rule', { ...rule, rule_severity: $event })"
          >
            <template v-if="!Array.isArray(severities) && !severities[rule.rule_severity]" #first>
              <b-form-select-option :value="rule.rule_severity" disabled>{{
                rule.rule_severity
              }}</b-form-select-option>
            </template>
          </b-form-select>
          <b-form-valid-feedback v-if="hasValidFeedback('rule_severity')">
            {{ validFeedback["rule_severity"] }}
          </b-form-valid-feedback>
          <b-form-invalid-feedback v-if="hasInvalidFeedback('rule_severity')">
            {{ invalidFeedback["rule_severity"] }}
          </b-form-invalid-feedback>
        </b-form-group>

        <!-- rule_weight -->
        <b-form-group
          v-if="fields.displayed.includes('rule_weight')"
          :id="`ruleEditor-rule_weight-group-${mod}`"
          class="col-6"
        >
          <label :for="`ruleEditor-rule_weight-${mod}`">
            Rule Weight
            <i
              v-if="tooltips['rule_weight']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['rule_weight']"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-rule_weight-${mod}`"
            :value="rule.rule_weight"
            :class="inputClass('rule_weight')"
            placeholder=""
            :disabled="disabled || fields.disabled.includes('rule_weight').disabled"
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
            <i
              v-if="tooltips['ident']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['ident']"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-ident-${mod}`"
            :value="rule.ident"
            :class="inputClass('ident')"
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
            <i
              v-if="tooltips['ident_system']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['ident_system']"
            />
          </label>
          <b-form-input
            :id="`ruleEditor-ident_system-${mod}`"
            :value="rule.ident_system"
            :class="inputClass('ident_system')"
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
          <i
            v-if="tooltips['vendor_comments']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['vendor_comments']"
          />
        </label>
        <b-form-textarea
          :id="`ruleEditor-vendor_comments-${mod}`"
          :value="rule.vendor_comments"
          :class="inputClass('vendor_comments')"
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
import DisaRuleDescriptionForm from "./DisaRuleDescriptionForm";
import AdditionalQuestions from "./AdditionalQuestions";
import CheckForm from "./CheckForm";

export default {
  name: "RuleForm",
  components: { DisaRuleDescriptionForm, CheckForm, AdditionalQuestions },
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
    severities: {
      type: [Array, Object],
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
    status_text: function () {
      return this.rule.satisfied_by.length > 0 ? "Applicable - Configurable" : this.rule.status;
    },
    tooltips: function () {
      return {
        status: null,
        status_justification: ["Applicable - Configurable", "Not Yet Determined"].includes(
          this.rule.status
        )
          ? null
          : "Explain the rationale behind selecting one of the above statuses",
        title: "Describe the vulnerability for this control",
        version: null,
        rule_severity:
          "Unknown: severity not defined, Info: rule is informational only, CAT III (Low): not a serious problem, CAT II (Medium): fairly serious problem, CAT I (High): a grave or critical problem",
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

<style scoped></style>
