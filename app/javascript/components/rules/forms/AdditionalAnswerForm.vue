<template>
  <div>
    <label :for="`ruleEditor-additional-question-${question.name}`">
      {{ question.name }}
    </label>
    <b-form-select
      v-if="question.question_type === 'dropdown'"
      :id="`ruleEditor-additional-field-${question.id}`"
      :value="findAnswerText(question.id)"
      :disabled="disabled"
      :options="question.options"
      :class="inputClass(question.name)"
      @input="addOrUpdateAnswer($event, question.id)"
    />
    <b-form-textarea
      v-else
      :id="`ruleEditor-additional-field-${question.id}`"
      :disabled="disabled"
      :value="findAnswerText(question.id)"
      placeholder=""
      rows="1"
      max-rows="99"
      :class="inputClass(question.name)"
      @input="addOrUpdateAnswer($event, question.id)"
    />
  </div>
</template>

<script>
import FormFeedbackMixinVue from "../../../mixins/FormFeedbackMixin.vue";

export default {
  name: "AdditionalAnswerForm",
  mixins: [FormFeedbackMixinVue],
  props: {
    rule: {
      type: Object,
      required: true,
    },
    question: {
      type: Object,
      required: true,
    },
    disabled: {
      type: Boolean,
      default: false,
    },
  },
  methods: {
    addOrUpdateAnswer: function (event, question_id) {
      let all_answers = this.rule.additional_answers_attributes;
      let index = all_answers.findIndex((answer) => answer.additional_question_id === question_id);
      if (index !== -1) {
        all_answers[index].answer = event;
      } else {
        all_answers.push({ additional_question_id: question_id, answer: event });
      }

      this.$root.$emit("update:rule", { ...this.rule, additional_answers_attributes: all_answers });
    },
    findAnswerText: function (question_id) {
      return this.rule.additional_answers_attributes.find(
        (element) => element.additional_question_id == question_id
      )?.answer;
    },
  },
};
</script>
