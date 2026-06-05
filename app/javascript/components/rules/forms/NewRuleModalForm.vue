<template>
  <div>
    <b-modal :id="`${idPrefix}-rule-modal`" ref="modal" :title="title" centered @ok="handleSubmit">
      <form ref="form" method="post">
        <!-- Hide the rule_id (SV-#) input when duplicating the control and show a confirmation -->
        <div v-if="forDuplicate">Clone control {{ selectedRuleText }}?</div>
        <div v-else>Create a new control in this project?</div>
      </form>
    </b-modal>
  </div>
</template>
<script>
import FormMixinVue from "../../../mixins/FormMixin.vue";
import { useRuleSelectionStore } from "../../../stores/ruleSelection";

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
  setup() {
    const ruleStore = useRuleSelectionStore();
    return { ruleStore };
  },
  methods: {
    handleSubmit: function () {
      this.$root.$emit(
        "create:rule",
        { duplicate: this.forDuplicate, id: this.selectedRuleId },
        (response) => {
          this.ruleStore.selectRule(response.data.data.id);
        },
      );
    },
  },
};
</script>
<style scoped></style>
