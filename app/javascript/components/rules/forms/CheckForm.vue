<template>
  <div v-if="check._destroy != true"  class="card p-3 mb-3">
    <p><strong>{{check.id == null ? 'New ' : ''}}Check</strong></p>
    <b-form-group
      :id="'ruleEditor-check-group-' + index"
      label="System"
      :label-for="'ruleEditor-check-system-' + index"
      description=""
    > 
      <b-form-input
        :id="'ruleEditor-check-system-' + index"
        v-model="check.system"
        placeholder=""
        :disabled="disabled"
      ></b-form-input>
    </b-form-group>

    <b-form-group
      :id="'ruleEditor-check-group-' + index"
      label="Reference Name"
      :label-for="'ruleEditor-check-content_ref_name-' + index"
      description=""
    > 
      <b-form-input
        :id="'ruleEditor-check-content_ref_name-' + index"
        v-model="check.content_ref_name"
        placeholder=""
        :disabled="disabled"
      ></b-form-input>
    </b-form-group>

    <b-form-group
      :id="'ruleEditor-check-group-' + index"
      label="Reference Link"
      :label-for="'ruleEditor-check-content_ref_href-' + index"
      description=""
    > 
      <b-form-input
        :id="'ruleEditor-check-content_ref_href-' + index"
        v-model="check.content_ref_href"
        placeholder=""
        :disabled="disabled"
      ></b-form-input>
    </b-form-group>

    <b-form-group
      :id="'ruleEditor-check-group-' + index"
      label="Check"
      :label-for="'ruleEditor-check-content-' + index"
      description=""
    > 
      <b-form-textarea
        :id="'ruleEditor-check-content-' + index"
        v-model="check.content"
        placeholder=""
        :disabled="disabled"
      ></b-form-textarea>
    </b-form-group>
    <a @click="$emit('removeCheck', index)" class="clickable text-dark" v-if="!disabled">
      <i class="mdi mdi-trash-can" aria-hidden="true"></i>
      Remove Check
    </a>
  </div>
</template>

<script>
export default {
  name: 'CheckForm',
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
    }
  },
}
</script>

<style scoped>
</style>
