<template>
  <div>
    <div v-if="description._destroy != true">
      <!-- description -->
      <b-form-group :id="`ruleEditor-rule_description-group-${mod}`">
        <label :for="`ruleEditor-rule_description-${mod}`">
          Rule Description
          <InfoTooltip v-if="tooltips['rule_description']" :text="tooltips['rule_description']" />
        </label>
        <MarkdownTextarea
          :id="`ruleEditor-rule_description-${mod}`"
          :value="description.description"
          :input-class="inputClass('description')"
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
import { useFormFeedback } from "../../../composables/useFormFeedback";
import MarkdownTextarea from "../../shared/MarkdownTextarea.vue";
import InfoTooltip from "../../shared/InfoTooltip.vue";

export default {
  name: "RuleDescriptionForm",
  components: { MarkdownTextarea, InfoTooltip },
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
    validFeedback: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    invalidFeedback: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  setup(props) {
    const { inputClass, hasValidFeedback, hasInvalidFeedback } = useFormFeedback(props);
    return { inputClass, hasValidFeedback, hasInvalidFeedback };
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
