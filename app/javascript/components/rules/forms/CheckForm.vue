<template>
  <div v-if="check._destroy != true"  class="card p-3 mb-3">
    <p><strong>{{check.id == null ? 'New ' : ''}}Check</strong></p>

    <!-- system -->
    <b-form-group :id="'ruleEditor-check-system-group-' + index"> 
      <label :for="'ruleEditor-check-system-' + index">
        System
        <i v-if="tooltips['system']" class="mdi mdi-information" aria-hidden="true" v-b-tooltip.hover.html :title="tooltips['system']"></i>
      </label>
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
    <b-form-group :id="'ruleEditor-check-content_ref_name-group-' + index"> 
      <label :for="'ruleEditor-check-content_ref_name-' + index">
        Reference Name
        <i v-if="tooltips['content_ref_name']" class="mdi mdi-information" aria-hidden="true" v-b-tooltip.hover.html :title="tooltips['content_ref_name']"></i>
      </label>
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
    <b-form-group :id="'ruleEditor-check-content_ref_href-group-' + index"> 
      <label :for="'ruleEditor-check-content_ref_href-' + index">
        Reference Link
        <i v-if="tooltips['content_ref_href']" class="mdi mdi-information" aria-hidden="true" v-b-tooltip.hover.html :title="tooltips['content_ref_href']"></i>
      </label>
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
    <b-form-group :id="'ruleEditor-check-content-group-' + index">
      <label :for="'ruleEditor-check-content-' + index">
        Check
        <i v-if="tooltips['content']" class="mdi mdi-information" aria-hidden="true" v-b-tooltip.hover.html :title="tooltips['content']"></i>
      </label>
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
  data: function () {
    return {
      tooltips: {
        system: null,
        content_ref_name: null,
        content_ref_href: null,
        content: null,
      }
    }
  },
}
</script>

<style scoped>
</style>
