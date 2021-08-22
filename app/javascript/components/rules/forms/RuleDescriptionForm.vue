<template>
  <div>
    <div v-if="description._destroy != true" class="card p-3 mb-3">
      <p><strong>{{description.id == null ? 'New ' : ''}}Rule Description</strong></p>

      <!-- description -->
      <b-form-group :id="'ruleEditor-rule_description-group-' + index">
        <label :label-for="'ruleEditor-rule_description' + index">
          Rule Description
          <i v-if="tooltips['rule_description']" class="mdi mdi-information" aria-hidden="true" v-b-tooltip.hover.html :title="tooltips['rule_description']"></i>
        </label>
        <b-form-textarea
          :id="'ruleEditor-rule_description-' + index"
          :class="inputClass('description')"
          v-model="description.description"
          placeholder=""
          :disabled="disabled"
          rows="1"
          max-rows="99"
        ></b-form-textarea>
        <b-form-valid-feedback v-if="hasValidFeedback('description')">
          {{this.validFeedback['description']}}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('description')">
          {{this.invalidFeedback['description']}}
        </b-form-invalid-feedback>
      </b-form-group>

      <!-- Remove link -->
      <a @click="$emit('removeRuleDescription', index)" class="clickable text-dark" v-if="!disabled">
        <i class="mdi mdi-trash-can" aria-hidden="true"></i>
        Remove Rule Description
      </a>
    </div>
  </div>
</template>

<script>
import FormFeedbackMixinVue from '../../../mixins/FormFeedbackMixin.vue';
export default {
  name: 'RuleDescriptionForm',
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
  data: function () {
    return {
      tooltips: {
        rule_description: null,
      }
    }
  },
}
</script>

<style scoped>
</style>
