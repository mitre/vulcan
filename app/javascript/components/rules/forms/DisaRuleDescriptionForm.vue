<template>
  <div v-if="description._destroy != true" class="card p-3 mb-3">
    <p>
      <strong>{{ description.id == null ? "New " : "" }}Rule Description</strong>
    </p>
    <!-- documentable -->
    <b-form-group>
      <b-form-checkbox
        v-model="descriptionCopy.documentable"
        :disabled="disabled"
        @input="$root.$emit('update:disaDescription', rule, descriptionCopy, index)"
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
    <b-form-group :id="`ruleEditor-disa_rule_description-vuln_discussion-group-${mod}`">
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
        v-model="descriptionCopy.vuln_discussion"
        :class="inputClass('vuln_discussion')"
        placeholder=""
        :disabled="disabled"
        rows="1"
        max-rows="99"
        @input="$root.$emit('update:disaDescription', rule, descriptionCopy, index)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('vuln_discussion')">
        {{ validFeedback["vuln_discussion"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('vuln_discussion')">
        {{ invalidFeedback["vuln_discussion"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- false_positives -->
    <b-form-group :id="`ruleEditor-disa_rule_description-false_positives-group-${mod}`">
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
        v-model="descriptionCopy.false_positives"
        :class="inputClass('false_positives')"
        placeholder=""
        :disabled="disabled"
        rows="1"
        max-rows="99"
        @input="$root.$emit('update:disaDescription', rule, descriptionCopy, index)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('false_positives')">
        {{ validFeedback["false_positives"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('false_positives')">
        {{ invalidFeedback["false_positives"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- false_negatives -->
    <b-form-group :id="`ruleEditor-disa_rule_description-false_negatives-group-${mod}`">
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
        v-model="descriptionCopy.false_negatives"
        :class="inputClass('false_negatives')"
        placeholder=""
        :disabled="disabled"
        rows="1"
        max-rows="99"
        @input="$root.$emit('update:disaDescription', rule, descriptionCopy, index)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('false_negatives')">
        {{ validFeedback["false_negatives"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('false_negatives')">
        {{ invalidFeedback["false_negatives"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- mitigations -->
    <b-form-group :id="`ruleEditor-disa_rule_description-mitigations-group-${mod}`">
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
        v-model="descriptionCopy.mitigations"
        :class="inputClass('mitigations')"
        placeholder=""
        :disabled="disabled"
        rows="1"
        max-rows="99"
        @input="$root.$emit('update:disaDescription', rule, descriptionCopy, index)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('mitigations')">
        {{ validFeedback["mitigations"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('mitigations')">
        {{ invalidFeedback["mitigations"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- severity_override_guidance -->
    <b-form-group :id="`ruleEditor-disa_rule_description-severity_override_guidance-group-${mod}`">
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
        v-model="descriptionCopy.severity_override_guidance"
        :class="inputClass('severity_override_guidance')"
        placeholder=""
        :disabled="disabled"
        rows="1"
        max-rows="99"
        @input="$root.$emit('update:disaDescription', rule, descriptionCopy, index)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('severity_override_guidance')">
        {{ validFeedback["severity_override_guidance"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('severity_override_guidance')">
        {{ invalidFeedback["severity_override_guidance"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- potential_impacts -->
    <b-form-group :id="`ruleEditor-disa_rule_description-potential_impacts-group-${mod}`">
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
        v-model="descriptionCopy.potential_impacts"
        :class="inputClass('potential_impacts')"
        placeholder=""
        :disabled="disabled"
        rows="1"
        max-rows="99"
        @input="$root.$emit('update:disaDescription', rule, descriptionCopy, index)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('potential_impacts')">
        {{ validFeedback["potential_impacts"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('potential_impacts')">
        {{ invalidFeedback["potential_impacts"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- third_party_tools -->
    <b-form-group :id="`ruleEditor-disa_rule_description-third_party_tools-group-${mod}`">
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
        v-model="descriptionCopy.third_party_tools"
        :class="inputClass('third_party_tools')"
        placeholder=""
        :disabled="disabled"
        rows="1"
        max-rows="99"
        @input="$root.$emit('update:disaDescription', rule, descriptionCopy, index)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('third_party_tools')">
        {{ validFeedback["third_party_tools"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('third_party_tools')">
        {{ invalidFeedback["third_party_tools"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- mitigation_control -->
    <b-form-group :id="`ruleEditor-disa_rule_description-mitigation_control-group-${mod}`">
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
        v-model="descriptionCopy.mitigation_control"
        :class="inputClass('mitigation_control')"
        placeholder=""
        :disabled="disabled"
        rows="1"
        max-rows="99"
        @input="$root.$emit('update:disaDescription', rule, descriptionCopy, index)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('mitigation_control')">
        {{ validFeedback["mitigation_control"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('mitigation_control')">
        {{ invalidFeedback["mitigation_control"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- responsibility -->
    <b-form-group :id="`ruleEditor-disa_rule_description-responsibility-group-${mod}`">
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
        v-model="descriptionCopy.responsibility"
        :class="inputClass('responsibility')"
        placeholder=""
        :disabled="disabled"
        rows="1"
        max-rows="99"
        @input="$root.$emit('update:disaDescription', rule, descriptionCopy, index)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('responsibility')">
        {{ validFeedback["responsibility"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('responsibility')">
        {{ invalidFeedback["responsibility"] }}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- ia_controls -->
    <b-form-group :id="`ruleEditor-disa_rule_description-ia_controls-group-${mod}`">
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
        v-model="descriptionCopy.ia_controls"
        :class="inputClass('ia_controls')"
        placeholder=""
        :disabled="disabled"
        rows="1"
        max-rows="99"
        @input="$root.$emit('update:disaDescription', rule, descriptionCopy, index)"
      />
      <b-form-valid-feedback v-if="hasValidFeedback('ia_controls')">
        {{ validFeedback["ia_controls"] }}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('ia_controls')">
        {{ invalidFeedback["ia_controls"] }}
      </b-form-invalid-feedback>
    </b-form-group>
    <!-- This is commented out because there is currently the assumption that users will only need one description -->
    <!-- <a @click="removeDescription()" class="clickable text-dark" v-if="!disabled">
      <i class="mdi mdi-trash-can" aria-hidden="true"></i>
      Remove DISA Description
    </a> -->
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
  },
  data: function () {
    return {
      mod: Math.floor(Math.random() * 1000),
      descriptionCopy: _.cloneDeep(this.description),
      tooltips: {
        documentable: null,
        vuln_discussion: null,
        false_positives: null,
        false_negatives: null,
        mitigations: null,
        severity_override_guidance: null,
        potential_impacts: null,
        third_party_tools: null,
        mitigation_control: null,
        responsibility: null,
        ia_controls: null,
      },
    };
  },
  methods: {
    removeDescription: function () {
      this.descriptionCopy._destroy = true;
      this.$root.$emit("update:disaDescription", this.rule, this.descriptionCopy, this.index);
    },
  },
};
</script>

<style scoped></style>
