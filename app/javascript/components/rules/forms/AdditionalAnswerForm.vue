<template>
  <div>
    <label :for="`ruleEditor-additional-question-${question.name}`">
      <template v-if="question.question_type === 'url'">
        {{ question.name }}:
        <b-link :href="findAnswerText(question.id)" target="_blank">
          {{ findAnswerText(question.id) }}
        </b-link>
      </template>
      <template v-else>
        {{ question.name }}
      </template>
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
    <template v-else-if="question.question_type === 'url'">
      <template v-if="!validurl">
        <span class="text-danger clickable float-right mr-3"> Must Start with HTTP or HTTPS! </span>
      </template>
      <b-input
        v-if="!disabled"
        :id="`ruleEditor-additional-field-${question.id}`"
        :value="findAnswerText(question.id)"
        :class="inputClass(question.name)"
        placeholder="Enter URL - make sure it starts with http or https..."
        @input="addOrUpdateAnswer($event, question.id)"
      />
    </template>
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
  data: function () {
    return {
      validurl: true,
    };
  },
  methods: {
    addOrUpdateAnswer: function (event, question_id) {
      if (this.question.question_type === "url" && event.length > 3) {
        this.validurl = event.substring(0, 4).toLowerCase() == "http";
      } else {
        this.validurl = true;
      }

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
