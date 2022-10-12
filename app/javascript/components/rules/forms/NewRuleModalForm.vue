<template>
  <div>
    <b-modal :id="`${idPrefix}-rule-modal`" ref="modal" :title="title" centered @ok="handleSubmit">
      <form ref="form" method="post">
        <!-- Hide the rule_id (SV-#) input when duplicating the requirement and show a confirmation -->
        <div v-if="forDuplicate">Clone requirement {{ selectedRuleText }}?</div>
        <div v-else>Create a new requirement in this project?</div>
      </form>
    </b-modal>
  </div>
</template>
<script>
import FormMixinVue from "../../../mixins/FormMixin.vue";
export default {
  name: "NewRuleModalForm",
  mixins: [FormMixinVue],
  props: {
    idPrefix: {
      type: String,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    forDuplicate: {
      type: Boolean,
      required: true,
    },
    selectedRuleId: {
      type: Number,
      required: false,
    },
    selectedRuleText: {
      type: String,
      required: false,
    },
  },
  methods: {
    handleSubmit: function () {
      this.$root.$emit(
        "create:rule",
        { duplicate: this.forDuplicate, id: this.selectedRuleId },
        (response) => {
          this.$emit("ruleSelected", response.data.data);
        }
      );
    },
  },
};
</script>
<style scoped></style>
