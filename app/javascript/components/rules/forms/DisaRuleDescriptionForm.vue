<template>
  <div v-if="description._destroy != true" class="card relationCard">
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
        v-model="description.vuln_discussion"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
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
        v-model="description.false_positives"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
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
        v-model="description.false_negatives"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
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
        v-model="description.mitigations"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
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
        v-model="description.severity_override_guidance"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
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
        v-model="description.potential_impacts"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
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
        v-model="description.third_party_tools"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
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
        v-model="description.mitigation_control"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
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
        v-model="description.responsibility"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
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
        v-model="description.ia_controls"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
    </b-form-group>
    <!-- This is commented out because there is currently the assumption that users will only need one description -->
    <!-- <a @click="$emit('removeDisaRuleDescription', index)" class="clickable text-dark" v-if="!disabled">
      <i class="mdi mdi-trash-can" aria-hidden="true"></i>
      Remove DISA Description
    </a> -->
  </div>
</template>

<script>
export default {
  name: 'DisaRuleDescriptionForm',
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
