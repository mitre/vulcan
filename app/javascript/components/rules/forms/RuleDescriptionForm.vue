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
          v-model="descriptionCopy.description"
          :class="inputClass('description')"
          placeholder=""
          :disabled="disabled"
          rows="1"
          max-rows="99"
          @input="$root.$emit('update:description', rule, descriptionCopy, index)"
        />
        <b-form-valid-feedback v-if="hasValidFeedback('description')">
          {{ validFeedback["description"] }}
        </b-form-valid-feedback>
        <b-form-invalid-feedback v-if="hasInvalidFeedback('description')">
          {{ invalidFeedback["description"] }}
        </b-form-invalid-feedback>
      </b-form-group>

      <!-- Remove link -->
      <a v-if="!disabled" class="clickable text-dark" @click="removeDescription()">
        <i class="mdi mdi-trash-can" aria-hidden="true" />
        Remove Rule Description
      </a>
    </div>
  </div>
</template>

<script>
import FormFeedbackMixinVue from "../../../mixins/FormFeedbackMixin.vue";
import _ from "lodash";

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
      descriptionCopy: _.cloneDeep(this.description),
      tooltips: {
        rule_description: null,
      },
    };
  },
  methods: {
    removeDescription: function () {
      this.descriptionCopy._destroy = true;
      this.$root.$emit("update:description", this.rule, this.descriptionCopy, this.index);
    },
  },
};
</script>

<style scoped></style>
