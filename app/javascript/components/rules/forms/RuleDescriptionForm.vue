<template>
  <div>
    <div v-if="description._destroy != true">
      <!-- description -->
      <b-form-group :id="`ruleEditor-rule_description-group-${mod}`">
        <label :for="`ruleEditor-rule_description-${mod}`">
          Rule Description
          <i
            v-if="tooltips['rule_description']"
            v-b-tooltip.hover.html
            class="mdi mdi-information"
            aria-hidden="true"
            :title="tooltips['rule_description']"
          />
        </label>
        <b-form-textarea
          :id="`ruleEditor-rule_description-${mod}`"
          :value="description.description"
          :class="inputClass('description')"
          placeholder=""
          :disabled="disabled"
          rows="1"
          max-rows="99"
          @input="
            $root.$emit('update:description', rule, { ...description, description: $event }, index)
          "
        />
        <b-form-valid-feedback v-if="hasValidFeedback('description')">
          {{ validFeedback["description"] }}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('description')">
          {{ invalidFeedback["description"] }}
        </b-form-invalid-feedback>
      </b-form-group>
    </div>
  </div>
</template>

<script>
import FormFeedbackMixinVue from "../../../mixins/FormFeedbackMixin.vue";

export default {
  name: "RuleDescriptionForm",
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
      tooltips: {
        rule_description: null,
      },
    };
  },
};
</script>

<style scoped></style>
