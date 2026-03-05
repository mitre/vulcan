<template>
  <div>
    <b-form>
      <!-- ============================================================ -->
      <!-- SECTION 1: Policy Decision (Status + Severity)               -->
      <!-- User's first action: decide the status and severity          -->
      <!-- ============================================================ -->
      <div
        v-if="fields.displayed.includes('status') || fields.displayed.includes('rule_severity')"
        class="row"
      >
        <!-- status -->
        <RuleFormGroup
          v-bind="formGroupProps"
          field-name="status"
          label="Status"
          :tooltip="tooltips['status']"
          extra-class="col-md-8"
          @toggle-section-lock="$emit('toggle-section-lock', $event)"
        >
          <template #default="{ inputId, isDisabled }">
            <b-form-select
              :id="inputId"
              :value="status_text"
              :input-class="inputClass('status')"
              :options="statuses"
              :disabled="isDisabled"
              @input="$root.$emit('update:rule', { ...rule, status: $event })"
            />
          </template>
        </RuleFormGroup>

        <!-- rule_severity -->
        <RuleFormGroup
          v-bind="formGroupProps"
          field-name="rule_severity"
          label="Severity"
          :tooltip="tooltips['rule_severity']"
          extra-class="col-md-4"
          @toggle-section-lock="$emit('toggle-section-lock', $event)"
        >
          <template #default="{ inputId, isDisabled }">
            <b-form-select
              :id="inputId"
              :value="rule.rule_severity"
              :input-class="inputClass('rule_severity')"
              :options="severityOptions"
              :disabled="isDisabled"
              @input="$root.$emit('update:rule', { ...rule, rule_severity: $event })"
            />
          </template>
        </RuleFormGroup>
      </div>

      <!-- severity_override_guidance (only when severity changed from SRG default) -->
      <RuleFormGroup
        v-bind="formGroupProps"
        field-name="severity_override_guidance"
        label="Severity Override Guidance"
        tooltip="Explain why the severity was changed from the SRG default"
        @toggle-section-lock="$emit('toggle-section-lock', $event)"
      >
        <template #default="{ inputId, isDisabled }">
          <MarkdownTextarea
            :id="inputId"
            :value="
              rule.disa_rule_descriptions_attributes[0] &&
              rule.disa_rule_descriptions_attributes[0].severity_override_guidance
            "
            :input-class="inputClass('severity_override_guidance')"
            placeholder=""
            :disabled="isDisabled"
            rows="1"
            max-rows="99"
            @input="
              $root.$emit(
                'update:disaDescription',
                rule,
                {
                  ...rule.disa_rule_descriptions_attributes[0],
                  severity_override_guidance: $event,
                },
                0,
              )
            "
          />
        </template>
      </RuleFormGroup>

      <!-- ============================================================ -->
      <!-- SECTION 2: Reference Context (read-only SRG info)            -->
      <!-- User reads the SRG requirement context before writing        -->
      <!-- ============================================================ -->
      <div v-if="rule.nist_control_family || rule.ident" class="row" data-testid="ia-control-cci">
        <RuleFormGroup
          v-bind="formGroupProps"
          field-name="nist_control_family"
          label="IA Control"
          tooltip="The NIST control family (e.g. AC-2) mapped to this requirement"
          extra-class="col-md-6"
          read-only
          :custom-display-check="() => true"
        >
          <template #default="{ inputId }">
            <b-form-input
              :id="inputId"
              :value="rule.nist_control_family || '\u2014'"
              readonly
              class="bg-light"
            />
          </template>
        </RuleFormGroup>
        <RuleFormGroup
          v-bind="formGroupProps"
          field-name="cci"
          label="CCI"
          tooltip="The Common Control Indicator (CCI) mapped to this requirement"
          extra-class="col-md-6"
          read-only
          :custom-display-check="() => true"
        >
          <template #default="{ inputId }">
            <b-form-input :id="inputId" :value="rule.ident || '\u2014'" readonly class="bg-light" />
          </template>
        </RuleFormGroup>
      </div>

      <!-- ============================================================ -->
      <!-- SECTION 3: Content Authoring (Title → Vuln Discussion →      -->
      <!--            Check → Fix)                                      -->
      <!-- The core authoring workflow in logical order                  -->
      <!-- ============================================================ -->

      <!-- title -->
      <RuleFormGroup
        v-bind="formGroupProps"
        field-name="title"
        label="Title"
        :tooltip="tooltips['title']"
        @toggle-section-lock="$emit('toggle-section-lock', $event)"
      >
        <template #default="{ inputId, isDisabled }">
          <MarkdownTextarea
            :id="inputId"
            :value="rule.title"
            :input-class="inputClass('title')"
            placeholder=""
            :disabled="isDisabled"
            rows="1"
            max-rows="99"
            @input="$root.$emit('update:rule', { ...rule, title: $event })"
          />
        </template>
      </RuleFormGroup>

      <!-- DISA Rule Description (vuln discussion + advanced DISA metadata) -->
      <template v-if="disa_fields">
        <DisaRuleDescriptionForm
          v-if="rule.disa_rule_descriptions_attributes.length >= 1"
          :rule="rule"
          :index="0"
          :description="rule.disa_rule_descriptions_attributes[0]"
          :disabled="disabled"
          :locked-sections="lockedSections"
          :can-manage-section-locks="canManageSectionLocks"
          :show-section-locks="showSectionLocks"
          :field-state-class-fn="fieldStateClassFn"
          :fields="disa_fields"
          @toggle-section-lock="$emit('toggle-section-lock', $event)"
        />
      </template>

      <!-- Check -->
      <template v-if="check_fields">
        <CheckForm
          v-if="rule.checks_attributes.length >= 1"
          :rule="rule"
          :index="0"
          :disabled="disabled"
          :fields="check_fields"
          :locked-sections="lockedSections"
          :can-manage-section-locks="canManageSectionLocks"
          :show-section-locks="showSectionLocks"
          :field-state-class-fn="fieldStateClassFn"
          @toggle-section-lock="$emit('toggle-section-lock', $event)"
        />
      </template>

      <!-- fixtext -->
      <RuleFormGroup
        v-bind="formGroupProps"
        field-name="fixtext"
        label="Fix"
        :tooltip="tooltips['fixtext']"
        @toggle-section-lock="$emit('toggle-section-lock', $event)"
      >
        <template #default="{ inputId, isDisabled }">
          <MarkdownTextarea
            :id="inputId"
            :value="rule.satisfied_by.length > 0 ? rule.satisfied_by[0].fixtext : rule.fixtext"
            :input-class="inputClass('fixtext')"
            placeholder=""
            :disabled="isDisabled"
            rows="1"
            max-rows="99"
            @input="$root.$emit('update:rule', { ...rule, fixtext: $event })"
          />
        </template>
      </RuleFormGroup>

      <!-- ============================================================ -->
      <!-- SECTION 4: Justification & Evidence                          -->
      <!-- After authoring content, justify the status and provide proof -->
      <!-- ============================================================ -->

      <!-- status_justification -->
      <RuleFormGroup
        v-bind="formGroupProps"
        field-name="status_justification"
        label="Status Justification"
        :tooltip="tooltips['status_justification']"
        @toggle-section-lock="$emit('toggle-section-lock', $event)"
      >
        <template #default="{ inputId, isDisabled }">
          <MarkdownTextarea
            :id="inputId"
            :value="rule.status_justification"
            :input-class="inputClass('status_justification')"
            placeholder=""
            :disabled="isDisabled"
            rows="1"
            max-rows="99"
            @input="$root.$emit('update:rule', { ...rule, status_justification: $event })"
          />
        </template>
      </RuleFormGroup>

      <!-- artifact_description -->
      <RuleFormGroup
        v-bind="formGroupProps"
        field-name="artifact_description"
        label="Artifact Description"
        :tooltip="tooltips['artifact_description']"
        @toggle-section-lock="$emit('toggle-section-lock', $event)"
      >
        <template #default="{ inputId, isDisabled }">
          <MarkdownTextarea
            :id="inputId"
            :value="rule.artifact_description"
            :input-class="inputClass('artifact_description')"
            placeholder=""
            :disabled="isDisabled"
            rows="1"
            max-rows="99"
            @input="$root.$emit('update:rule', { ...rule, artifact_description: $event })"
          />
        </template>
      </RuleFormGroup>

      <!-- vendor_comments -->
      <RuleFormGroup
        v-bind="formGroupProps"
        field-name="vendor_comments"
        label="Vendor Comments"
        :tooltip="tooltips['vendor_comments']"
        @toggle-section-lock="$emit('toggle-section-lock', $event)"
      >
        <template #default="{ inputId, isDisabled }">
          <MarkdownTextarea
            :id="inputId"
            :value="rule.vendor_comments"
            :input-class="inputClass('vendor_comments')"
            placeholder=""
            :disabled="isDisabled"
            rows="1"
            max-rows="99"
            @input="$root.$emit('update:rule', { ...rule, vendor_comments: $event })"
          />
        </template>
      </RuleFormGroup>

      <!-- Additional Questions -->
      <AdditionalQuestions
        :additional_questions="additional_questions"
        :disabled="disabled && !force_enable_additional_questions"
        :rule="rule"
      />

      <!-- ============================================================ -->
      <!-- SECTION 5: XCCDF Metadata (Advanced — rarely edited)         -->
      <!-- Technical metadata that most users never touch                -->
      <!-- ============================================================ -->

      <!-- version -->
      <RuleFormGroup
        v-bind="formGroupProps"
        field-name="version"
        label="Version"
        :tooltip="tooltips['version']"
        @toggle-section-lock="$emit('toggle-section-lock', $event)"
      >
        <template #default="{ inputId, isDisabled }">
          <b-form-input
            :id="inputId"
            :value="rule.version"
            :input-class="inputClass('version')"
            placeholder=""
            :disabled="isDisabled"
            @input="$root.$emit('update:rule', { ...rule, version: $event })"
          />
        </template>
      </RuleFormGroup>

      <div class="row">
        <!-- fix_id -->
        <RuleFormGroup
          v-bind="formGroupProps"
          field-name="fix_id"
          label="Fix ID"
          :tooltip="tooltips['fix_id']"
          extra-class="col-6"
          @toggle-section-lock="$emit('toggle-section-lock', $event)"
        >
          <template #default="{ inputId, isDisabled }">
            <b-form-input
              :id="inputId"
              :value="rule.fix_id"
              :input-class="inputClass('fix_id')"
              placeholder=""
              :disabled="isDisabled"
              @input="$root.$emit('update:rule', { ...rule, fix_id: $event })"
            />
          </template>
        </RuleFormGroup>

        <!-- fixtext_fixref -->
        <RuleFormGroup
          v-bind="formGroupProps"
          field-name="fixtext_fixref"
          label="Fix Text Reference"
          :tooltip="tooltips['fixtext_fixref']"
          extra-class="col-6"
          @toggle-section-lock="$emit('toggle-section-lock', $event)"
        >
          <template #default="{ inputId, isDisabled }">
            <b-form-input
              :id="inputId"
              :value="rule.fixtext_fixref"
              :input-class="inputClass('fixtext_fixref')"
              placeholder=""
              :disabled="isDisabled"
              @input="$root.$emit('update:rule', { ...rule, fixtext_fixref: $event })"
            />
          </template>
        </RuleFormGroup>
      </div>

      <div class="row">
        <!-- rule_weight -->
        <RuleFormGroup
          v-bind="formGroupProps"
          field-name="rule_weight"
          label="Rule Weight"
          :tooltip="tooltips['rule_weight']"
          extra-class="col-6"
          @toggle-section-lock="$emit('toggle-section-lock', $event)"
        >
          <template #default="{ inputId, isDisabled }">
            <b-form-input
              :id="inputId"
              :value="rule.rule_weight"
              :input-class="inputClass('rule_weight')"
              placeholder=""
              :disabled="isDisabled"
              @input="$root.$emit('update:rule', { ...rule, rule_weight: $event })"
            />
          </template>
        </RuleFormGroup>
      </div>

      <div class="row">
        <!-- ident -->
        <RuleFormGroup
          v-bind="formGroupProps"
          field-name="ident"
          label="Identity"
          :tooltip="tooltips['ident']"
          extra-class="col-4"
          @toggle-section-lock="$emit('toggle-section-lock', $event)"
        >
          <template #default="{ inputId, isDisabled }">
            <b-form-input
              :id="inputId"
              :value="rule.ident"
              :input-class="inputClass('ident')"
              placeholder=""
              :disabled="isDisabled"
              @input="$root.$emit('update:rule', { ...rule, ident: $event })"
            />
          </template>
        </RuleFormGroup>

        <!-- ident_system -->
        <RuleFormGroup
          v-bind="formGroupProps"
          field-name="ident_system"
          label="Identity System"
          :tooltip="tooltips['ident_system']"
          extra-class="col-8"
          @toggle-section-lock="$emit('toggle-section-lock', $event)"
        >
          <template #default="{ inputId, isDisabled }">
            <b-form-input
              :id="inputId"
              :value="rule.ident_system"
              :input-class="inputClass('ident_system')"
              placeholder=""
              :disabled="isDisabled"
              @input="$root.$emit('update:rule', { ...rule, ident_system: $event })"
            />
          </template>
        </RuleFormGroup>
      </div>
    </b-form>
  </div>
</template>

<script>
import FormFeedbackMixinVue from "../../../mixins/FormFeedbackMixin.vue";
import MarkdownTextarea from "../../shared/MarkdownTextarea.vue";
import RuleFormGroup from "../../shared/RuleFormGroup.vue";
import DisaRuleDescriptionForm from "./DisaRuleDescriptionForm";
import AdditionalQuestions from "./AdditionalQuestions";
import CheckForm from "./CheckForm";
import { SEVERITY_OPTIONS } from "../../../constants/terminology";

export default {
  name: "RuleForm",
  components: {
    DisaRuleDescriptionForm,
    CheckForm,
    AdditionalQuestions,
    MarkdownTextarea,
    RuleFormGroup,
  },
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
    severityOptions: function () {
      return SEVERITY_OPTIONS;
    },
    status_text: function () {
      return this.rule.satisfied_by.length > 0 ? "Applicable - Configurable" : this.rule.status;
    },
    nydTooltip() {
      if (this.rule.status !== "Not Yet Determined") return null;
      return (
        "Fields are locked while status is <strong>Not Yet Determined</strong>. " +
        "Change the status to <em>Applicable \u2013 Configurable</em>, " +
        "<em>Applicable \u2013 Does Not Meet</em>, " +
        "<em>Applicable \u2013 Inherently Meets</em>, or " +
        "<em>Not Applicable</em> to unlock."
      );
    },
    tooltips: function () {
      return {
        status:
          "Applicable \u2013 Configurable: The product requires configuration or the application of policy settings to achieve compliance.<br><br>Applicable \u2013 Inherently Meets: The product is compliant in its initial state and cannot be subsequently reconfigured to a noncompliant state.<br><br> Applicable \u2013 Does Not Meet: There are no technical means to achieve compliance.<br><br> Not Applicable: The requirement addresses a capability or use case that the product does not support.",
        status_justification: ["Applicable - Configurable", "Not Yet Determined"].includes(
          this.rule.status,
        )
          ? null
          : "Explain the rationale behind selecting one of the above statuses",
        title: this.nydTooltip || "Describe the vulnerability for this control",
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
          this.nydTooltip ||
          (this.rule.status === "Applicable - Configurable"
            ? "Describe how to correctly configure the requirement to remediate the system vulnerability"
            : [
                  "Applicable - Does Not Meet",
                  "Applicable - Inherently Meets",
                  "Not Applicable",
                ].includes(this.rule.status)
              ? null
              : "Explain how to fix the vulnerability discussed"),
        ident:
          "Typically the Common Control Indicator (CCI) that maps to the vulnerability being discussed in this control",
        ident_system: null,
        vendor_comments:
          this.nydTooltip || "Provide context to a reviewing authority; not a published field",
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
