<template>
  <div v-if="description._destroy != true" class="card p-3 mb-3">
    <p><strong>{{description.id == null ? 'New ' : ''}}Rule Description</strong></p>
    <!-- documentable -->
    <b-form-group description="">
      <b-form-checkbox v-model="description.documentable" :disabled="disabled">Documentable</b-form-checkbox>
    </b-form-group>

    <!-- vuln_discussion -->
    <b-form-group
      :id="'ruleEditor-disa_rule_description-vuln_discussion-group-' + index"
      label="Vulnerability Discussion"
      :label-for="'ruleEditor-disa_rule_description-vuln_discussion-' + index"
      description=""
    >
      <b-form-textarea
        :id="'ruleEditor-disa_rule_description-vuln_discussion-' + index"
        :class="inputClass('vuln_discussion')"
        v-model="description.vuln_discussion"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
      <b-form-valid-feedback v-if="hasValidFeedback('vuln_discussion')">
        {{this.validFeedback['vuln_discussion']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('vuln_discussion')">
        {{this.invalidFeedback['vuln_discussion']}}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- false_positives -->
    <b-form-group
      :id="'ruleEditor-disa_rule_description-false_positives-group-' + index"
      label="False Positives"
      :label-for="'ruleEditor-disa_rule_description-false_positives-' + index"
      description=""
    >
      <b-form-textarea
        :id="'ruleEditor-disa_rule_description-false_positives-' + index"
        :class="inputClass('false_positives')"
        v-model="description.false_positives"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
      <b-form-valid-feedback v-if="hasValidFeedback('false_positives')">
        {{this.validFeedback['false_positives']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('false_positives')">
        {{this.invalidFeedback['false_positives']}}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- false_negatives -->
    <b-form-group
      :id="'ruleEditor-disa_rule_description-false_negatives-group-' + index"
      label="False Negatives"
      :label-for="'ruleEditor-disa_rule_description-false_negatives-' + index"
      description=""
    >
      <b-form-textarea
        :id="'ruleEditor-disa_rule_description-false_negatives-' + index"
        :class="inputClass('false_negatives')"
        v-model="description.false_negatives"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
      <b-form-valid-feedback v-if="hasValidFeedback('false_negatives')">
        {{this.validFeedback['false_negatives']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('false_negatives')">
        {{this.invalidFeedback['false_negatives']}}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- mitigations -->
    <b-form-group
      :id="'ruleEditor-disa_rule_description-mitigations-group-' + index"
      label="Mitigations"
      :label-for="'ruleEditor-disa_rule_description-mitigations-' + index"
      description=""
    >
      <b-form-textarea
        :id="'ruleEditor-disa_rule_description-mitigations-' + index"
        :class="inputClass('mitigations')"
        v-model="description.mitigations"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
      <b-form-valid-feedback v-if="hasValidFeedback('mitigations')">
        {{this.validFeedback['mitigations']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('mitigations')">
        {{this.invalidFeedback['mitigations']}}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- severity_override_guidance -->
    <b-form-group
      :id="'ruleEditor-disa_rule_description-severity_override_guidance-group-' + index"
      label="Security Override Guidance"
      :label-for="'ruleEditor-disa_rule_description-severity_override_guidance-' + index"
      description=""
    >
      <b-form-textarea
        :id="'ruleEditor-disa_rule_description-severity_override_guidance-' + index"
        :class="inputClass('severity_override_guidance')"
        v-model="description.severity_override_guidance"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
      <b-form-valid-feedback v-if="hasValidFeedback('severity_override_guidance')">
        {{this.validFeedback['severity_override_guidance']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('severity_override_guidance')">
        {{this.invalidFeedback['severity_override_guidance']}}
      </b-form-invalid-feedback>
    </b-form-group>
    
    <!-- potential_impacts -->
    <b-form-group
      :id="'ruleEditor-disa_rule_description-potential_impacts-group-' + index"
      label="Potential Impacts"
      :label-for="'ruleEditor-disa_rule_description-potential_impacts-' + index"
      description=""
    >
      <b-form-textarea
        :id="'ruleEditor-disa_rule_description-potential_impacts-' + index"
        :class="inputClass('potential_impacts')"
        v-model="description.potential_impacts"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
      <b-form-valid-feedback v-if="hasValidFeedback('potential_impacts')">
        {{this.validFeedback['potential_impacts']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('potential_impacts')">
        {{this.invalidFeedback['potential_impacts']}}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- third_party_tools -->
    <b-form-group
      :id="'ruleEditor-disa_rule_description-third_party_tools-group-' + index"
      label="Third Party Tools"
      :label-for="'ruleEditor-disa_rule_description-third_party_tools-' + index"
      description=""
    >
      <b-form-textarea
        :id="'ruleEditor-disa_rule_description-third_party_tools-' + index"
        :class="inputClass('third_party_tools')"
        v-model="description.third_party_tools"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
      <b-form-valid-feedback v-if="hasValidFeedback('third_party_tools')">
        {{this.validFeedback['third_party_tools']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('third_party_tools')">
        {{this.invalidFeedback['third_party_tools']}}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- mitigation_control -->
    <b-form-group
      :id="'ruleEditor-disa_rule_description-mitigation_control-group-' + index"
      label="Mitigation Control"
      :label-for="'ruleEditor-disa_rule_description-mitigation_control-' + index"
      description=""
    >
      <b-form-textarea
        :id="'ruleEditor-disa_rule_description-mitigation_control-' + index"
        :class="inputClass('mitigation_control')"
        v-model="description.mitigation_control"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
      <b-form-valid-feedback v-if="hasValidFeedback('mitigation_control')">
        {{this.validFeedback['mitigation_control']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('mitigation_control')">
        {{this.invalidFeedback['mitigation_control']}}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- responsibility -->
    <b-form-group
      :id="'ruleEditor-disa_rule_description-responsibility-group-' + index"
      label="Responsibility"
      :label-for="'ruleEditor-disa_rule_description-responsibility-' + index"
      description=""
    >
      <b-form-textarea
        :id="'ruleEditor-disa_rule_description-responsibility-' + index"
        :class="inputClass('responsibility')"
        v-model="description.responsibility"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
      <b-form-valid-feedback v-if="hasValidFeedback('responsibility')">
        {{this.validFeedback['responsibility']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('responsibility')">
        {{this.invalidFeedback['responsibility']}}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- ia_controls -->
    <b-form-group
      :id="'ruleEditor-disa_rule_description-ia_controls-group-' + index"
      label="IA Controls"
      :label-for="'ruleEditor-disa_rule_description-ia_controls-' + index"
      description=""
    >
      <b-form-textarea
        :id="'ruleEditor-disa_rule_description-ia_controls-' + index"
        :class="inputClass('ia_controls')"
        v-model="description.ia_controls"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
      <b-form-valid-feedback v-if="hasValidFeedback('ia_controls')">
        {{this.validFeedback['ia_controls']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('ia_controls')">
        {{this.invalidFeedback['ia_controls']}}
      </b-form-invalid-feedback>
    </b-form-group>
    <!-- This is commented out because there is currently the assumption that users will only need one description -->
    <!-- <a @click="$emit('removeDisaRuleDescription', index)" class="clickable text-dark" v-if="!disabled">
      <i class="mdi mdi-trash-can" aria-hidden="true"></i>
      Remove DISA Description
    </a> -->
  </div>
</template>

<script>
import FormFeedbackMixinVue from '../../../mixins/FormFeedbackMixin.vue';
export default {
  name: 'DisaRuleDescriptionForm',
  mixins: [FormFeedbackMixinVue],
  props: {
    description: {
      type: Object,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: true,
    },
    index: {
      type: Number,
      required: false,
      default: Math.floor(Math.random() * 1000)
    }
  },
}
</script>

<style scoped>
</style>
