<template>
  <div v-if="description._destroy != true">
    <!-- documentable -->
    <b-form-group v-if="fields.displayed.includes('documentable')">
      <b-form-checkbox
        :checked="description.documentable"
        :disabled="disabled || fields.disabled.includes('documentable')"
        @input="
          $root.$emit(
            'update:disaDescription',
            rule,
            { ...description, documentable: $event },
            index
          )
        "
      >
        Documentable
        <i
          v-if="tooltips['documentable']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['documentable']"
        />
      </b-form-checkbox>
    </b-form-group>

    <!-- vuln_discussion -->
    <b-form-group
      v-if="fields.displayed.includes('vuln_discussion') || rule.status == 'Not Yet Determined'"
      :id="`ruleEditor-disa_rule_description-vuln_discussion-group-${mod}`"
    >
      <label :for="`ruleEditor-disa_rule_description-vuln_discussion-${mod}`">
        Vulnerability Discussion
        <i
          v-if="tooltips['vuln_discussion']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['vuln_discussion']"
        />
      </label>
      <b-form-textarea
        :id="`ruleEditor-disa_rule_description-vuln_discussion-${mod}`"
        :value="description.vuln_discussion"
        :class="inputClass('vuln_discussion')"
        placeholder=""
        :disabled="
          disabled ||
          fields.disabled.includes('vuln_discussion') ||
          rule.status == 'Not Yet Determined'
        "
        rows="1"
        max-rows="99"
        @input="
          $root.$emit(
            'update:disaDescription',
            rule,
            { ...description, vuln_discussion: $event },
            index
          )
        "
      />
      <b-form-valid-feedback v-if="hasValidFeedback('vuln_discussion')">
        {{ validFeedback["vuln_discussion"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('vuln_discussion')">
        {{ invalidFeedback["vuln_discussion"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- false_positives -->
    <b-form-group
      v-if="fields.displayed.includes('false_positives')"
      :id="`ruleEditor-disa_rule_description-false_positives-group-${mod}`"
    >
      <label :for="`ruleEditor-disa_rule_description-false_positives-${mod}`">
        False Positives
        <i
          v-if="tooltips['false_positives']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['false_positives']"
        />
      </label>
      <b-form-textarea
        :id="`ruleEditor-disa_rule_description-false_positives-${mod}`"
        :value="description.false_positives"
        :class="inputClass('false_positives')"
        placeholder=""
        :disabled="disabled || fields.disabled.includes('false_positives')"
        rows="1"
        max-rows="99"
        @input="
          $root.$emit(
            'update:disaDescription',
            rule,
            { ...description, false_positives: $event },
            index
          )
        "
      />
      <b-form-valid-feedback v-if="hasValidFeedback('false_positives')">
        {{ validFeedback["false_positives"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('false_positives')">
        {{ invalidFeedback["false_positives"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- false_negatives -->
    <b-form-group
      v-if="fields.displayed.includes('false_negatives')"
      :id="`ruleEditor-disa_rule_description-false_negatives-group-${mod}`"
    >
      <label :for="`ruleEditor-disa_rule_description-false_negatives-${mod}`">
        False Negatives
        <i
          v-if="tooltips['false_negatives']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['false_negatives']"
        />
      </label>
      <b-form-textarea
        :id="`ruleEditor-disa_rule_description-false_negatives-${mod}`"
        :value="description.false_negatives"
        :class="inputClass('false_negatives')"
        placeholder=""
        :disabled="disabled || fields.disabled.includes('false_negatives')"
        rows="1"
        max-rows="99"
        @input="
          $root.$emit(
            'update:disaDescription',
            rule,
            { ...description, false_negatives: $event },
            index
          )
        "
      />
      <b-form-valid-feedback v-if="hasValidFeedback('false_negatives')">
        {{ validFeedback["false_negatives"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('false_negatives')">
        {{ invalidFeedback["false_negatives"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- mitigations available -->
    <b-form-group
      v-if="fields.displayed.includes('mitigations_available')"
      :id="`ruleEditor-disa_rule_description-mitigations-available-group-${mod}`"
    >
      <b-form-checkbox
        :id="`ruleEditor-disa_rule_description-mitigations-available-${mod}`"
        :checked="description.mitigations_available"
        switch
        @input="
          $root.$emit(
            'update:disaDescription',
            rule,
            { ...description, mitigations_available: $event },
            index
          )
        "
      >
        Mitigations Available
      </b-form-checkbox>
    </b-form-group>

    <!-- mitigations -->
    <b-form-group
      v-if="fields.displayed.includes('mitigations')"
      :id="`ruleEditor-disa_rule_description-mitigations-group-${mod}`"
    >
      <label :for="`ruleEditor-disa_rule_description-mitigations-${mod}`">
        Mitigations
        <i
          v-if="tooltips['mitigations']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['mitigations']"
        />
      </label>
      <b-form-textarea
        :id="`ruleEditor-disa_rule_description-mitigations-${mod}`"
        :value="description.mitigations"
        :class="inputClass('mitigations')"
        placeholder=""
        :disabled="disabled || fields.disabled.includes('mitigations')"
        rows="1"
        max-rows="99"
        @input="
          $root.$emit(
            'update:disaDescription',
            rule,
            { ...description, mitigations: $event },
            index
          )
        "
      />
      <b-form-valid-feedback v-if="hasValidFeedback('mitigations')">
        {{ validFeedback["mitigations"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('mitigations')">
        {{ invalidFeedback["mitigations"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- poam available -->
    <b-form-group
      v-if="fields.displayed.includes('poam_available') && !description.mitigations_available"
      :id="`ruleEditor-disa_rule_description-poam-available-group-${mod}`"
    >
      <b-form-checkbox
        :id="`ruleEditor-disa_rule_description-poam-available-${mod}`"
        :checked="description.poam_available"
        switch
        @input="
          $root.$emit(
            'update:disaDescription',
            rule,
            { ...description, poam_available: $event },
            index
          )
        "
      >
        POA&amp;M Available
      </b-form-checkbox>
    </b-form-group>

    <!-- poam -->
    <b-form-group
      v-if="fields.displayed.includes('poam') && description.poam_available"
      :id="`ruleEditor-disa_rule_description-poam-group-${mod}`"
    >
      <label :for="`ruleEditor-disa_rule_description-poam-${mod}`">
        POA&amp;M
        <i
          v-if="tooltips['poam']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['poam']"
        />
      </label>
      <b-form-textarea
        :id="`ruleEditor-disa_rule_description-poam-${mod}`"
        :value="description.poam"
        :class="inputClass('poam')"
        placeholder=""
        :disabled="disabled || fields.disabled.includes('poam')"
        rows="1"
        max-rows="99"
        @input="
          $root.$emit('update:disaDescription', rule, { ...description, poam: $event }, index)
        "
      />
      <b-form-valid-feedback v-if="hasValidFeedback('poam')">
        {{ validFeedback["poam"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('poam')">
        {{ invalidFeedback["poam"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- severity_override_guidance -->
    <b-form-group
      v-if="fields.displayed.includes('severity_override_guidance')"
      :id="`ruleEditor-disa_rule_description-severity_override_guidance-group-${mod}`"
    >
      <label :for="`ruleEditor-disa_rule_description-severity_override_guidance-${mod}`">
        Security Override Guidance
        <i
          v-if="tooltips['severity_override_guidance']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['severity_override_guidance']"
        />
      </label>
      <b-form-textarea
        :id="`ruleEditor-disa_rule_description-severity_override_guidance-${mod}`"
        :value="description.severity_override_guidance"
        :class="inputClass('severity_override_guidance')"
        placeholder=""
        :disabled="disabled || fields.disabled.includes('severity_override_guidance')"
        rows="1"
        max-rows="99"
        @input="
          $root.$emit(
            'update:disaDescription',
            rule,
            { ...description, severity_override_guidance: $event },
            index
          )
        "
      />
      <b-form-valid-feedback v-if="hasValidFeedback('severity_override_guidance')">
        {{ validFeedback["severity_override_guidance"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('severity_override_guidance')">
        {{ invalidFeedback["severity_override_guidance"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- potential_impacts -->
    <b-form-group
      v-if="fields.displayed.includes('potential_impacts')"
      :id="`ruleEditor-disa_rule_description-potential_impacts-group-${mod}`"
    >
      <label :for="`ruleEditor-disa_rule_description-potential_impacts-${mod}`">
        Potential Impacts
        <i
          v-if="tooltips['potential_impacts']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['potential_impacts']"
        />
      </label>
      <b-form-textarea
        :id="`ruleEditor-disa_rule_description-potential_impacts-${mod}`"
        :value="description.potential_impacts"
        :class="inputClass('potential_impacts')"
        placeholder=""
        :disabled="disabled || fields.disabled.includes('potential_impacts')"
        rows="1"
        max-rows="99"
        @input="
          $root.$emit(
            'update:disaDescription',
            rule,
            { ...description, potential_impacts: $event },
            index
          )
        "
      />
      <b-form-valid-feedback v-if="hasValidFeedback('potential_impacts')">
        {{ validFeedback["potential_impacts"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('potential_impacts')">
        {{ invalidFeedback["potential_impacts"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- third_party_tools -->
    <b-form-group
      v-if="fields.displayed.includes('third_party_tools')"
      :id="`ruleEditor-disa_rule_description-third_party_tools-group-${mod}`"
    >
      <label :for="`ruleEditor-disa_rule_description-third_party_tools-${mod}`">
        Third Party Tools
        <i
          v-if="tooltips['third_party_tools']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['third_party_tools']"
        />
      </label>
      <b-form-textarea
        :id="`ruleEditor-disa_rule_description-third_party_tools-${mod}`"
        :value="description.third_party_tools"
        :class="inputClass('third_party_tools')"
        placeholder=""
        :disabled="disabled || fields.disabled.includes('third_party_tools')"
        rows="1"
        max-rows="99"
        @input="
          $root.$emit(
            'update:disaDescription',
            rule,
            { ...description, third_party_tools: $event },
            index
          )
        "
      />
      <b-form-valid-feedback v-if="hasValidFeedback('third_party_tools')">
        {{ validFeedback["third_party_tools"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('third_party_tools')">
        {{ invalidFeedback["third_party_tools"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- mitigation_control -->
    <b-form-group
      v-if="fields.displayed.includes('mitigation_control')"
      :id="`ruleEditor-disa_rule_description-mitigation_control-group-${mod}`"
    >
      <label :for="`ruleEditor-disa_rule_description-mitigation_control-${mod}`">
        Mitigation Control
        <i
          v-if="tooltips['mitigation_control']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['mitigation_control']"
        />
      </label>
      <b-form-textarea
        :id="`ruleEditor-disa_rule_description-mitigation_control-${mod}`"
        :value="description.mitigation_control"
        :class="inputClass('mitigation_control')"
        placeholder=""
        :disabled="disabled || fields.disabled.includes('mitigation_control')"
        rows="1"
        max-rows="99"
        @input="
          $root.$emit(
            'update:disaDescription',
            rule,
            { ...description, mitigation_control: $event },
            index
          )
        "
      />
      <b-form-valid-feedback v-if="hasValidFeedback('mitigation_control')">
        {{ validFeedback["mitigation_control"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('mitigation_control')">
        {{ invalidFeedback["mitigation_control"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- responsibility -->
    <b-form-group
      v-if="fields.displayed.includes('responsibility')"
      :id="`ruleEditor-disa_rule_description-responsibility-group-${mod}`"
    >
      <label :for="`ruleEditor-disa_rule_description-responsibility-${mod}`">
        Responsibility
        <i
          v-if="tooltips['responsibility']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['responsibility']"
        />
      </label>
      <b-form-textarea
        :id="`ruleEditor-disa_rule_description-responsibility-${mod}`"
        :value="description.responsibility"
        :class="inputClass('responsibility')"
        placeholder=""
        :disabled="disabled || fields.disabled.includes('responsibility')"
        rows="1"
        max-rows="99"
        @input="
          $root.$emit(
            'update:disaDescription',
            rule,
            { ...description, responsibility: $event },
            index
          )
        "
      />
      <b-form-valid-feedback v-if="hasValidFeedback('responsibility')">
        {{ validFeedback["responsibility"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('responsibility')">
        {{ invalidFeedback["responsibility"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- ia_controls -->
    <b-form-group
      v-if="fields.displayed.includes('ia_controls')"
      :id="`ruleEditor-disa_rule_description-ia_controls-group-${mod}`"
    >
      <label :for="`ruleEditor-disa_rule_description-ia_controls-${mod}`">
        IA Controls
        <i
          v-if="tooltips['ia_controls']"
          v-b-tooltip.hover.html
          class="mdi mdi-information"
          aria-hidden="true"
          :title="tooltips['ia_controls']"
        />
      </label>
      <b-form-textarea
        :id="`ruleEditor-disa_rule_description-ia_controls-${mod}`"
        :value="description.ia_controls"
        :class="inputClass('ia_controls')"
        placeholder=""
        :disabled="disabled || fields.disabled.includes('ia_controls')"
        rows="1"
        max-rows="99"
        @input="
          $root.$emit(
            'update:disaDescription',
            rule,
            { ...description, ia_controls: $event },
            index
          )
        "
      />
      <b-form-valid-feedback v-if="hasValidFeedback('ia_controls')">
        {{ validFeedback["ia_controls"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('ia_controls')">
        {{ invalidFeedback["ia_controls"] }}
      </b-form-invalid-feedback>
    </b-form-group>
  </div>
</template>

<script>
import FormFeedbackMixinVue from "../../../mixins/FormFeedbackMixin.vue";
export default {
  name: "DisaRuleDescriptionForm",
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
  data: function () {
    return {
      mod: Math.floor(Math.random() * 1000),
    };
  },
  computed: {
    tooltips: function () {
      return {
        documentable: null,
        vuln_discussion: "Discuss, in detail, the rationale for this control's vulnerability",
        false_positives: "List any likely false-positives associated with evaluating this control",
        false_negatives: "List any likely false-negatives associated with evaluating this control",
        mitigations: [
          "Not Yet Determined",
          "Applicable - Configurable",
          "Applicable - Inherently Meets",
          "Not Applicable",
        ].includes(this.rule.status)
          ? null
          : "Discuss how the system mitigates this vulnerability in the absence of a configuration that would eliminate it",
        poam:
          this.rule.status === "Applicable - Does Not Meet"
            ? "Discuss the action of the POA&M in place for this vulnerability, including the start date and end date of the action"
            : null,
        severity_override_guidance: null,
        potential_impacts:
          "List the potential operational impacts on a system when applying fix discussed in this control",
        third_party_tools: null,
        mitigation_control: null,
        responsibility: null,
        ia_controls: "The Common Control Indicator (CCI) that applies to this vulnerability",
      };
    },
  },
};
</script>

<style scoped></style>
