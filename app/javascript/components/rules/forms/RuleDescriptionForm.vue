<template>
  <div>
    <div v-if="description._destroy != true" class="card relationCard">
      <p><strong>{{description.id == null ? 'New ' : ''}}Rule Description</strong></p>
      <b-form-group
        :id="'ruleEditor-rule_description-group-' + index"
        label="Rule Description"
        :label-for="'ruleEditor-rule_description' + index"
        description=""
      >
        <b-form-textarea
          :id="'ruleEditor-rule_description-' + index"
          v-model="description.description"
          placeholder=""
          :disabled="disabled"
        ></b-form-textarea>
      </b-form-group>
      <a @click="$emit('removeRuleDescription', index)" class="clickable text-dark" v-if="rule.locked == false">
        <i class="mdi mdi-trash-can" aria-hidden="true"></i>
        Remove Rule Description
      </a>
    </div>
  </div>
</template>

<script>
export default {
  name: 'RuleDescriptionForm',
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
