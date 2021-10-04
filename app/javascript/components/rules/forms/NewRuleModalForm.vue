<template>
  <div>
    <b-modal
      :id="`${idPrefix}-rule-modal`"
      ref="modal"
      :title="title"
      centered
      @shown="$refs.newRuleIdInput.focus()"
      @ok="handleSubmit"
    >
      <form ref="form" method="post">
        <!-- Hide the rule_id (SV-#) input when duplicating the control and show a confirmation -->
        <div v-if="forDuplicate">
          Duplicate control {{ selectedRuleId }}?
        </div>
        <b-form-group
          id="rule-id-input-group"
          label-for="rule-id-input"
          description="This must be unique for the project. It will not appear in the sidebar and is hidden."
          :hidden="forDuplicate"
        >
          <label :for="`rule-id-input`">
            Control ID
            <i
              v-if="tooltips['control_id']"
              v-b-tooltip.hover.html
              class="mdi mdi-information"
              aria-hidden="true"
              :title="tooltips['control_id']"
            />
          </label>
          <b-form-input
            id="rule-id-input"
            ref="newRuleIdInput"
            v-model="ruleFormRuleId"
            autocomplete="off"
            required
          />
        </b-form-group>
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
  },
  data: function () {
    return {
      ruleFormRuleId: "",
      tooltips: {
        control_id: "This will be equivalent to the SV-#",
      },
    };
  },
  mounted: function () {
    this.ruleFormRuleId = this.generateRuleId();
  },
  methods: {
    generateRuleId: function () {
      return `VULCAN-${Math.ceil(Math.random() * 1000000)}`;
    },
    handleSubmit: function () {
      this.ruleFormRuleId = this.generateRuleId();
      this.$root.$emit(
        "create:rule",
        { rule_id: this.ruleFormRuleId, duplicate: this.forDuplicate, id: this.selectedRuleId },
        (response) => {
          this.$emit("ruleSelected", response.data.data);
        }
      );
    },
  },
};
</script>
<style scoped></style>
