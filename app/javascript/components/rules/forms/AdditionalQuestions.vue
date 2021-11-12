<template>
  <div>
    <b-form-group
      v-for="question in additional_questions"
      :key="`additional-question-${question.id}`"
    >
      <AdditionalAnswerForm
        :rule="rule"
        :question="question"
        :disabled="disabled"
        :invalid-feedback="invalidFeedback"
        :valid-feedback="validFeedback"
      />
    </b-form-group>
  </div>
</template>

<script>
import AdditionalAnswerForm from "./AdditionalAnswerForm";

export default {
  name: "AdditionalQuestions",
  components: { AdditionalAnswerForm },
  props: {
    rule: {
      type: Object,
      required: true,
    },
    additional_questions: {
      type: Array,
      default: () => [],
    },
    disabled: {
      type: Boolean,
      default: false,
    },
    validFeedback: {
      type: Object,
      required: false,
    },
    invalidFeedback: {
      type: Object,
      required: false,
    },
  },
  methods: {},
};
</script>
