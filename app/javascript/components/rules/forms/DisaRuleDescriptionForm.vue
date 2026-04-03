<template>
  <div v-if="description._destroy != true">
    <!-- documentable -->
    <RuleFormGroup
      v-bind="formGroupProps"
      field-name="documentable"
      label="Documentable"
      checkbox-mode
      id-prefix="ruleEditor-disa_rule_description"
      :tooltip="tooltips['documentable']"
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
    >
      <template #default="{ isDisabled }">
        <b-form-checkbox
          :checked="description.documentable"
          :disabled="isDisabled"
          @input="
            $root.$emit(
              'update:disaDescription',
              rule,
              { ...description, documentable: $event },
              index,
            )
          "
        >
          Documentable
          <b-icon
            v-if="tooltips['documentable']"
            v-b-tooltip.hover.html="tooltips['documentable']"
            icon="info-circle"
            aria-hidden="true"
          />
        </b-form-checkbox>
      </template>
    </RuleFormGroup>

    <!-- vuln_discussion -->
    <RuleFormGroup
      v-bind="formGroupProps"
      field-name="vuln_discussion"
      label="Vulnerability Discussion"
      id-prefix="ruleEditor-disa_rule_description"
      :tooltip="tooltips['vuln_discussion']"
      :custom-display-check="
        () => fields.displayed.includes('vuln_discussion') || rule.status == 'Not Yet Determined'
      "
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
    >
      <template #default="{ inputId, isDisabled }">
        <MarkdownTextarea
          :id="inputId"
          :value="description.vuln_discussion"
          :input-class="inputClass('vuln_discussion')"
          placeholder=""
          :disabled="isDisabled || rule.status == 'Not Yet Determined'"
          rows="1"
          max-rows="99"
          @input="
            $root.$emit(
              'update:disaDescription',
              rule,
              { ...description, vuln_discussion: $event },
              index,
            )
          "
        />
      </template>
    </RuleFormGroup>

    <!-- false_positives -->
    <RuleFormGroup
      v-bind="formGroupProps"
      field-name="false_positives"
      label="False Positives"
      id-prefix="ruleEditor-disa_rule_description"
      :tooltip="tooltips['false_positives']"
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
    >
      <template #default="{ inputId, isDisabled }">
        <MarkdownTextarea
          :id="inputId"
          :value="description.false_positives"
          :input-class="inputClass('false_positives')"
          placeholder=""
          :disabled="isDisabled"
          rows="1"
          max-rows="99"
          @input="
            $root.$emit(
              'update:disaDescription',
              rule,
              { ...description, false_positives: $event },
              index,
            )
          "
        />
      </template>
    </RuleFormGroup>

    <!-- false_negatives -->
    <RuleFormGroup
      v-bind="formGroupProps"
      field-name="false_negatives"
      label="False Negatives"
      id-prefix="ruleEditor-disa_rule_description"
      :tooltip="tooltips['false_negatives']"
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
    >
      <template #default="{ inputId, isDisabled }">
        <MarkdownTextarea
          :id="inputId"
          :value="description.false_negatives"
          :input-class="inputClass('false_negatives')"
          placeholder=""
          :disabled="isDisabled"
          rows="1"
          max-rows="99"
          @input="
            $root.$emit(
              'update:disaDescription',
              rule,
              { ...description, false_negatives: $event },
              index,
            )
          "
        />
      </template>
    </RuleFormGroup>

    <!-- mitigations available -->
    <RuleFormGroup
      v-bind="formGroupProps"
      field-name="mitigations_available"
      label="Mitigations Available"
      checkbox-mode
      id-prefix="ruleEditor-disa_rule_description"
      :tooltip="tooltips['mitigations_available']"
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
    >
      <template #default="{ inputId, isDisabled }">
        <b-form-checkbox
          :id="inputId"
          :checked="description.mitigations_available"
          :disabled="isDisabled"
          switch
          @input="
            $root.$emit(
              'update:disaDescription',
              rule,
              { ...description, mitigations_available: $event },
              index,
            )
          "
        >
          Mitigations Available
        </b-form-checkbox>
      </template>
    </RuleFormGroup>

    <!-- mitigations (only shown when mitigations_available is toggled on) -->
    <RuleFormGroup
      v-bind="formGroupProps"
      field-name="mitigations"
      label="Mitigations"
      id-prefix="ruleEditor-disa_rule_description"
      :tooltip="tooltips['mitigations']"
      :custom-display-check="
        () => fields.displayed.includes('mitigations') && description.mitigations_available
      "
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
    >
      <template #default="{ inputId, isDisabled }">
        <MarkdownTextarea
          :id="inputId"
          :value="description.mitigations"
          :input-class="inputClass('mitigations')"
          placeholder=""
          :disabled="isDisabled"
          rows="1"
          max-rows="99"
          @input="
            $root.$emit(
              'update:disaDescription',
              rule,
              { ...description, mitigations: $event },
              index,
            )
          "
        />
      </template>
    </RuleFormGroup>

    <!-- poam available -->
    <RuleFormGroup
      v-bind="formGroupProps"
      field-name="poam_available"
      label="POA&amp;M Available"
      checkbox-mode
      id-prefix="ruleEditor-disa_rule_description"
      :tooltip="tooltips['poam_available']"
      :custom-display-check="
        () => fields.displayed.includes('poam_available') && !description.mitigations_available
      "
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
    >
      <template #default="{ inputId, isDisabled }">
        <b-form-checkbox
          :id="inputId"
          :checked="description.poam_available"
          :disabled="isDisabled"
          switch
          @input="
            $root.$emit(
              'update:disaDescription',
              rule,
              { ...description, poam_available: $event },
              index,
            )
          "
        >
          POA&amp;M Available
        </b-form-checkbox>
      </template>
    </RuleFormGroup>

    <!-- poam -->
    <RuleFormGroup
      v-bind="formGroupProps"
      field-name="poam"
      label="POA&amp;M"
      id-prefix="ruleEditor-disa_rule_description"
      :tooltip="tooltips['poam']"
      :custom-display-check="
        () =>
          fields.displayed.includes('poam') &&
          description.poam_available &&
          !description.mitigations_available
      "
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
    >
      <template #default="{ inputId, isDisabled }">
        <MarkdownTextarea
          :id="inputId"
          :value="description.poam"
          :input-class="inputClass('poam')"
          placeholder=""
          :disabled="isDisabled"
          rows="1"
          max-rows="99"
          @input="
            $root.$emit('update:disaDescription', rule, { ...description, poam: $event }, index)
          "
        />
      </template>
    </RuleFormGroup>

    <!-- severity_override_guidance -->
    <RuleFormGroup
      v-bind="formGroupProps"
      field-name="severity_override_guidance"
      label="Severity Override Guidance"
      id-prefix="ruleEditor-disa_rule_description"
      :tooltip="tooltips['severity_override_guidance']"
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
    >
      <template #default="{ inputId, isDisabled }">
        <MarkdownTextarea
          :id="inputId"
          :value="description.severity_override_guidance"
          :input-class="inputClass('severity_override_guidance')"
          placeholder=""
          :disabled="isDisabled"
          rows="1"
          max-rows="99"
          @input="
            $root.$emit(
              'update:disaDescription',
              rule,
              { ...description, severity_override_guidance: $event },
              index,
            )
          "
        />
      </template>
    </RuleFormGroup>

    <!-- potential_impacts -->
    <RuleFormGroup
      v-bind="formGroupProps"
      field-name="potential_impacts"
      label="Potential Impacts"
      id-prefix="ruleEditor-disa_rule_description"
      :tooltip="tooltips['potential_impacts']"
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
    >
      <template #default="{ inputId, isDisabled }">
        <MarkdownTextarea
          :id="inputId"
          :value="description.potential_impacts"
          :input-class="inputClass('potential_impacts')"
          placeholder=""
          :disabled="isDisabled"
          rows="1"
          max-rows="99"
          @input="
            $root.$emit(
              'update:disaDescription',
              rule,
              { ...description, potential_impacts: $event },
              index,
            )
          "
        />
      </template>
    </RuleFormGroup>

    <!-- third_party_tools -->
    <RuleFormGroup
      v-bind="formGroupProps"
      field-name="third_party_tools"
      label="Third Party Tools"
      id-prefix="ruleEditor-disa_rule_description"
      :tooltip="tooltips['third_party_tools']"
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
    >
      <template #default="{ inputId, isDisabled }">
        <MarkdownTextarea
          :id="inputId"
          :value="description.third_party_tools"
          :input-class="inputClass('third_party_tools')"
          placeholder=""
          :disabled="isDisabled"
          rows="1"
          max-rows="99"
          @input="
            $root.$emit(
              'update:disaDescription',
              rule,
              { ...description, third_party_tools: $event },
              index,
            )
          "
        />
      </template>
    </RuleFormGroup>

    <!-- mitigation_control (only shown when mitigations_available is toggled on) -->
    <RuleFormGroup
      v-bind="formGroupProps"
      field-name="mitigation_control"
      label="Mitigation Control"
      id-prefix="ruleEditor-disa_rule_description"
      :tooltip="tooltips['mitigation_control']"
      :custom-display-check="
        () => fields.displayed.includes('mitigation_control') && description.mitigations_available
      "
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
    >
      <template #default="{ inputId, isDisabled }">
        <MarkdownTextarea
          :id="inputId"
          :value="description.mitigation_control"
          :input-class="inputClass('mitigation_control')"
          placeholder=""
          :disabled="isDisabled"
          rows="1"
          max-rows="99"
          @input="
            $root.$emit(
              'update:disaDescription',
              rule,
              { ...description, mitigation_control: $event },
              index,
            )
          "
        />
      </template>
    </RuleFormGroup>

    <!-- responsibility -->
    <RuleFormGroup
      v-bind="formGroupProps"
      field-name="responsibility"
      label="Responsibility"
      id-prefix="ruleEditor-disa_rule_description"
      :tooltip="tooltips['responsibility']"
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
    >
      <template #default="{ inputId, isDisabled }">
        <MarkdownTextarea
          :id="inputId"
          :value="description.responsibility"
          :input-class="inputClass('responsibility')"
          placeholder=""
          :disabled="isDisabled"
          rows="1"
          max-rows="99"
          @input="
            $root.$emit(
              'update:disaDescription',
              rule,
              { ...description, responsibility: $event },
              index,
            )
          "
        />
      </template>
    </RuleFormGroup>

    <!-- ia_controls -->
    <RuleFormGroup
      v-bind="formGroupProps"
      field-name="ia_controls"
      label="IA Controls"
      id-prefix="ruleEditor-disa_rule_description"
      :tooltip="tooltips['ia_controls']"
      @toggle-section-lock="$emit('toggle-section-lock', $event)"
    >
      <template #default="{ inputId, isDisabled }">
        <MarkdownTextarea
          :id="inputId"
          :value="description.ia_controls"
          :input-class="inputClass('ia_controls')"
          placeholder=""
          :disabled="isDisabled"
          rows="1"
          max-rows="99"
          @input="
            $root.$emit(
              'update:disaDescription',
              rule,
              { ...description, ia_controls: $event },
              index,
            )
          "
        />
      </template>
    </RuleFormGroup>
  </div>
</template>

<script>
import FormFeedbackMixinVue from "../../../mixins/FormFeedbackMixin.vue";
import MarkdownTextarea from "../../shared/MarkdownTextarea.vue";
import RuleFormGroup from "../../shared/RuleFormGroup.vue";
export default {
  name: "DisaRuleDescriptionForm",
  components: { MarkdownTextarea, RuleFormGroup },
  mixins: [FormFeedbackMixinVue],
  // `rule` and `index` are necessary if edits are to be made
  props: {
    description: {
      type: Object,
      required: true,
    },
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
          displayed: [
            "documentable",
            "vuln_discussion",
            "false_positives",
            "false_negatives",
            "mitigations_available",
            "mitigations",
            "poam_available",
            "poam",
            "severity_override_guidance",
            "potential_impacts",
            "third_party_tools",
            "mitigation_control",
            "responsibility",
            "ia_controls",
          ],
          disabled: [],
        };
      },
    },
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
    tooltips: function () {
      return {
        documentable:
          "DISA XCCDF metadata: indicates whether this finding should appear in the STIG checklist results. " +
          "When checked, assessors must document their finding for this requirement during evaluation.",
        vuln_discussion: "Discuss, in detail, the rationale for this control's vulnerability",
        false_positives: "List any likely false-positives associated with evaluating this control",
        false_negatives: "List any likely false-negatives associated with evaluating this control",
        mitigations_available:
          "Toggle ON if a compensating control or mitigation exists for this vulnerability. Mutually exclusive with POA&M.",
        mitigations: [
          "Not Yet Determined",
          "Applicable - Configurable",
          "Applicable - Inherently Meets",
          "Not Applicable",
        ].includes(this.rule.status)
          ? null
          : "Discuss how the system mitigates this vulnerability in the absence of a configuration that would eliminate it",
        poam_available:
          "Toggle ON if a Plan of Action & Milestones exists for this vulnerability. Only available when Mitigations is OFF.",
        poam:
          this.rule.status === "Applicable - Does Not Meet"
            ? "Discuss the action of the POA&M in place for this vulnerability, including the start date and end date of the action"
            : null,
        severity_override_guidance:
          "Guidance for when the severity of this finding may be adjusted based on operational context or compensating controls",
        potential_impacts:
          "List the potential operational impacts on a system when applying fix discussed in this control",
        third_party_tools:
          "List any third-party tools or technologies required to evaluate or implement this control",
        mitigation_control:
          "Identify the specific compensating control that mitigates this vulnerability",
        responsibility:
          "Identify the responsible party for implementing this control (e.g., System Administrator, Application Developer, Information Owner)",
        ia_controls:
          "The IA Control(s) applicable to this vulnerability — either a CCI number (e.g., CCI-000366) or a NIST 800-53 control (e.g., CM-6)",
      };
    },
  },
};
</script>

<style scoped></style>
