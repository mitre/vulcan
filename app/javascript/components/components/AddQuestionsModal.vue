<template>
  <div>
    <b-button class="px-2 m-2" variant="success" @click="showModal()">
      Update Additional Questions
    </b-button>
    <b-modal
      ref="addQuestionsToComponentModal"
      title="Add Questions to Component"
      size="lg"
      ok-title="Update"
      @show="resetModal()"
      @ok="updateQuestions()"
    >
      <b-form @submit="updateQuestions()">
        <div v-for="(data, index) in questions" :key="index" class="pb-2">
          <b-input-group>
            <b-col sm="3" class="px-0">
              <b-form-select
                v-model="data.question_type"
                :options="typeOptions"
                class="rounded-0"
              />
            </b-col>
            <b-col class="px-0">
              <b-form-input
                v-model="data.name"
                placeholder="Field Name"
                class="rounded-0"
                required
              />
            </b-col>
            <b-col v-if="data.question_type === 'dropdown'" sm="5" class="px-0">
              <b-form-input
                :value="data.options.join(', ')"
                placeholder="Values (Comma Separated)"
                class="rounded-0"
                required
                @change="data.options = $event.split(',').map((s) => s.trim())"
              />
              <!-- Add button for removing field entry -->
            </b-col>
            <b-col sm="1" class="px-0">
              <b-button variant="danger" class="ml-2" @click="removeQuestions(index)"> X </b-button>
            </b-col>
          </b-input-group>
        </div>
        <b-row>
          <b-col>
            <b-button @click="addQuestions">Add</b-button>
          </b-col>
        </b-row>
        <!-- Allow the enter button to submit the form -->
        <b-btn type="submit" class="d-none" @click.prevent="updateMetadata()" />
      </b-form>
    </b-modal>
  </div>
</template>

<script>
import axios from "axios";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

function initialState(component) {
  return {
    questions: [...component.additional_questions],
    deleted_questions: [],
    typeOptions: [
      { value: "freeform", text: "Freeform Text" },
      { value: "dropdown", text: "Multiple Select" },
    ],
  };
}

export default {
  name: "AddQuestionsToComponentModal",
  mixins: [AlertMixinVue, FormMixinVue],
  props: {
    component: {
      type: Object,
      required: true,
    },
  },
  data: function () {
    return initialState(this.component);
  },
  methods: {
    addQuestions: function () {
      this.questions.push({ name: "", question_type: "freeform", options: [] });
    },
    showModal: function () {
      this.$refs["addQuestionsToComponentModal"].show();
    },
    resetModal: function () {
      Object.assign(this.$data, initialState(this.component));
    },
    removeQuestions: function (index) {
      let currentQuestion = this.questions.splice(index, 1)[0];
      currentQuestion._destroy = true;
      this.deleted_questions.push(currentQuestion);
    },
    updateQuestions: function () {
      this.$refs["addQuestionsToComponentModal"].hide();
      let payload = {
        component: {
          additional_questions_attributes: this.questions.concat(this.deleted_questions),
        },
      };
      axios
        .put(`/components/${this.component.id}`, payload)
        .then(this.updateAdditionalQuestionsSuccess)
        .catch(this.alertOrNotifyResponse);
    },
    updateAdditionalQuestionsSuccess: function (response) {
      this.alertOrNotifyResponse(response);
      this.$emit("componentUpdated");
    },
  },
};
</script>

<style scoped></style>
