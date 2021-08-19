<template>
  <div v-if="check._destroy != true"  class="card p-3 mb-3">
    <p><strong>{{check.id == null ? 'New ' : ''}}Check</strong></p>

    <!-- system -->
    <b-form-group
      :id="'ruleEditor-check-system-group-' + index"
      label="System"
      :label-for="'ruleEditor-check-system-' + index"
      description=""
    > 
      <b-form-input
        :id="'ruleEditor-check-system-' + index"
        :class="inputClass('system')"
        v-model="check.system"
        placeholder=""
        :disabled="disabled"
      ></b-form-input>
      <b-form-valid-feedback v-if="hasValidFeedback('system')">
        {{this.validFeedback['system']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('system')">
        {{this.invalidFeedback['system']}}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- content_ref_name -->
    <b-form-group
      :id="'ruleEditor-check-content_ref_name-group-' + index"
      label="Reference Name"
      :label-for="'ruleEditor-check-content_ref_name-' + index"
      description=""
    > 
      <b-form-input
        :id="'ruleEditor-check-content_ref_name-' + index"
        :class="inputClass('content_ref_name')"
        v-model="check.content_ref_name"
        placeholder=""
        :disabled="disabled"
      ></b-form-input>
      <b-form-valid-feedback v-if="hasValidFeedback('content_ref_name')">
        {{this.validFeedback['content_ref_name']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('content_ref_name')">
        {{this.invalidFeedback['content_ref_name']}}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- content_ref_href -->
    <b-form-group
      :id="'ruleEditor-check-content_ref_href-group-' + index"
      label="Reference Link"
      :label-for="'ruleEditor-check-content_ref_href-' + index"
      description=""
    > 
      <b-form-input
        :id="'ruleEditor-check-content_ref_href-' + index"
        :class="inputClass('content_ref_href')"
        v-model="check.content_ref_href"
        placeholder=""
        :disabled="disabled"
      ></b-form-input>
      <b-form-valid-feedback v-if="hasValidFeedback('content_ref_href')">
        {{this.validFeedback['content_ref_href']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('content_ref_href')">
        {{this.invalidFeedback['content_ref_href']}}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- content -->
    <b-form-group
      :id="'ruleEditor-check-content-group-' + index"
      label="Check"
      :label-for="'ruleEditor-check-content-' + index"
      description=""
    > 
      <b-form-textarea
        :id="'ruleEditor-check-content-' + index"
        :class="inputClass('content')"
        v-model="check.content"
        placeholder=""
        :disabled="disabled"
        rows="1"
        max-rows="99"
      ></b-form-textarea>
      <b-form-valid-feedback v-if="hasValidFeedback('content')">
        {{this.validFeedback['content']}}
      </b-form-valid-feedback>
      <b-form-invalid-feedback v-if="hasInvalidFeedback('content')">
        {{this.invalidFeedback['content']}}
      </b-form-invalid-feedback>
    </b-form-group>

    <!-- Remove link -->
    <a @click="$emit('removeCheck', index)" class="clickable text-dark" v-if="!disabled">
      <i class="mdi mdi-trash-can" aria-hidden="true"></i>
      Remove Check
    </a>
  </div>
</template>

<script>
import FormFeedbackMixinVue from '../../../mixins/FormFeedbackMixin.vue';
export default {
  name: 'CheckForm',
  mixins: [FormFeedbackMixinVue],
  props: {
    check: {
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
    },
  },
}
</script>

<style scoped>
</style>
