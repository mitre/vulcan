<template>
  <div>
    <div v-if="description._destroy != true" class="card p-3 mb-3">
      <p>
        <strong>{{ description.id == null ? "New " : "" }}Rule Description</strong>
      </p>

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
          v-model="description.description"
          :class="inputClass('description')"
          placeholder=""
          :disabled="disabled"
          rows="1"
          max-rows="99"
        />
        <b-form-valid-feedback v-if="hasValidFeedback('description')">
          {{ validFeedback["description"] }}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('description')">
          {{ invalidFeedback["description"] }}
        </b-form-invalid-feedback>
      </b-form-group>

      <!-- Remove link -->
      <a v-if="!disabled" class="clickable text-dark" @click="$emit('removeRuleDescription')">
        <i class="mdi mdi-trash-can" aria-hidden="true" />
        Remove Rule Description
      </a>
    </div>
  </div>
</template>

<script>
import FormFeedbackMixinVue from "../../../mixins/FormFeedbackMixin.vue";
export default {
  name: "RuleDescriptionForm",
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
