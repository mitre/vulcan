<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <h1>{{ component.name }} - Controls</h1>

    <RulesCodeEditorView
      :project="project"
      :component="component"
      :rules="reactiveRules"
      :statuses="statuses"
      :severities="severities"
      :severities_map="severities_map"
      :effective-permissions="effective_permissions"
      :current-user-id="current_user_id"
      :selected-rule="selectedRule"
      :selected-rule-id="selectedRuleId"
      :open-rule-ids="openRuleIds"
      :handle-rule-selected="handleRuleSelected"
      :handle-rule-deselected="handleRuleDeselected"
    />
  </div>
</template>

<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import RulesCodeEditorView from "./RulesCodeEditorView.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";
import SortRulesMixin from "../../mixins/SortRulesMixin.vue";
import SelectedRulesMixin from "../../mixins/SelectedRulesMixin.vue";
import _ from "lodash";

export default {
  name: "Rules",
  components: { RulesCodeEditorView },
  mixins: [AlertMixinVue, FormMixinVue, SortRulesMixin, SelectedRulesMixin],
  props: {
    effective_permissions: {
      type: String,
      required: true,
    },
    current_user_id: {
      type: Number,
      required: true,
    },
    project: {
      type: Object,
      required: true,
    },
    component: {
      type: Object,
      required: true,
    },
    rules: {
      type: Array,
      required: true,
    },
    rule: {
      type: Object,
      required: false,
    },
    statuses: {
      type: Array,
      required: true,
    },
    severities: {
      type: Array,
      required: true,
    },
    severities_map: {
      type: Object,
      required: true,
    },
  },
  data: function () {
    return {
      reactiveRules: _.cloneDeep(this.rules).sort(this.compareRules),
      selected_rule: this.rule,
    };
  },
  computed: {
    breadcrumbs: function () {
      return [
        {
          text: "Projects",
          href: "/projects",
        },
        {
          text: this.project.name,
          href: "/projects/" + this.project.id,
        },
        {
          text: this.component.name,
          href: `/components/${this.component.id}`,
        },
        {
          text: "Controls",
          href: `/components/${this.component.id}/controls`,
        },
        {
          text: `${
            this.selected_rule ? `${this.component.prefix}-${this.selected_rule.rule_id}` : ""
          }`,
          active: true,
        },
      ];
    },
  },
  mounted() {
    this.$root.$on("refresh:rule", this.refreshRule);
    this.$root.$on("update:rule", this.ruleUpdate);
    this.$root.$on("update:check", this.checkUpdate);
    this.$root.$on("update:description", this.descriptionUpdate);
    this.$root.$on("update:disaDescription", this.disaDescriptionUpdate);
    this.$root.$on("add:check", this.addCheck);
    this.$root.$on("add:description", this.addRuleDescription);
    this.$root.$on("add:disaDescription", this.addDisaRuleDescription);
    this.$root.$on("create:rule", this.createRule);
    this.$root.$on("delete:rule", this.deleteRule);
    this.$root.$on("deselect:rule", this.deselectRule);
    this.$root.$on("select:rule", this.selectRule);
    this.$root.$on("markDuplicate:rule", this.markDuplicateRule);
    this.$root.$on("unmarkDuplicate:rule", this.unmarkDuplicateRule);
    if (this.selected_rule) {
      this.handleRuleSelected(this.selected_rule.id);
    }
  },
  methods: {
    /**
     * Event handler for @markDuplicate:rule
     */
    markDuplicateRule: function (rule_id, satisfied_by_rule_id, successCallback = null) {
      axios
        .post(`/rule_satisfactions`, { rule_id, satisfied_by_rule_id })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.refreshRule(rule_id);
          this.refreshRule(satisfied_by_rule_id);

          if (successCallback) {
            try {
              successCallback(response);
            } catch (_) {}
          }
        })
        .catch(this.alertOrNotifyResponse);
    },
    /**
     * Event handler for @markDuplicate:rule
     */
    unmarkDuplicateRule: function (rule_id, satisfied_by_rule_id, successCallback = null) {
      axios
        .delete(`/rule_satisfactions/${rule_id}`, { data: { rule_id, satisfied_by_rule_id } })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.refreshRule(rule_id);
          this.refreshRule(satisfied_by_rule_id);

          if (successCallback) {
            try {
              successCallback(response);
            } catch (_) {}
          }
        })
        .catch(this.alertOrNotifyResponse);
    },
    /**
     * Event handler for @delete:rule
     */
    deleteRule: function (rule_id, successCallback = null) {
      axios
        .delete(`/rules/${rule_id}`)
        .then((response) => {
          this.alertOrNotifyResponse(response);

          // remove the rule
          const ruleIndex = this.reactiveRules.findIndex((r) => r.id == rule_id);
          if (ruleIndex >= 0) {
            this.reactiveRules.splice(ruleIndex, 1);
          }

          if (successCallback) {
            try {
              successCallback(response);
            } catch (_) {}
          }
        })
        .catch(this.alertOrNotifyResponse);
    },
    /**
     * Event handler for @create:rule
     */
    createRule: function (rule, successCallback = null) {
      axios
        .post(`/components/${this.component.id}/rules`, { rule: rule })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.ruleFetchSuccess(response);
          if (successCallback) {
            try {
              successCallback(response);
            } catch (_) {}
          }
        })
        .catch(this.alertOrNotifyResponse);
    },
    /**
     * Event handler for @select:rule
     */
    selectRule: function (rule) {
      this.selected_rule = rule;
      window.history.pushState(
        {},
        "",
        `/components/${this.component.id}/controls/${this.component.prefix}-${rule.rule_id}`
      );
    },
    /**
     * Event handler for @deselect:rule
     */
    deselectRule: function (ruleId) {
      // this.handleRuleDeselected(ruleId);
      if (this.selected_rule && this.selected_rule.id == ruleId) {
        this.selected_rule = null;
        window.history.pushState({}, "", `/components/${this.component.id}/controls`);
      }
    },
    /**
     * Event handler for @add:description
     */
    addRuleDescription: function (rule) {
      const ruleIndex = this.reactiveRules.findIndex((r) => r.id == rule?.id);
      // Guard if rule is not found
      if (ruleIndex == -1) {
        return;
      }

      this.reactiveRules[ruleIndex].rule_descriptions_attributes.push({
        description: "",
        rule_id: this.reactiveRules[ruleIndex].id,
        _destroy: false,
      });
    },
    /**
     * Event handler for @add:check
     */
    addCheck: function (rule) {
      const ruleIndex = this.reactiveRules.findIndex((r) => r.id == rule?.id);
      // Guard if rule is not found
      if (ruleIndex == -1) {
        return;
      }

      this.reactiveRules[ruleIndex].checks_attributes.push({
        system: "",
        content_ref_name: "",
        content_ref_href: "",
        content: "",
        rule_id: this.reactiveRules[ruleIndex].id,
        _destroy: false,
      });
    },
    /**
     * Event handler for @add:disaDescription
     */
    addDisaRuleDescription: function (rule) {
      const ruleIndex = this.reactiveRules.findIndex((r) => r.id == rule?.id);
      // Guard if rule is not found
      if (ruleIndex == -1) {
        return;
      }

      this.reactiveRules[ruleIndex].disa_rule_descriptions_attributes.push({
        description: "",
        rule_id: this.reactiveRules[ruleIndex].id,
        _destroy: false,
      });
    },
    /**
     * Event handler for @update:rule.
     * Splices the updated version of the rule where the previous rule was.
     */
    ruleUpdate: function (rule) {
      const index = this.reactiveRules.findIndex((r) => r.id == rule?.id);
      // Guard if rule is not found.
      if (index == -1) {
        return;
      }

      this.reactiveRules.splice(index, 1, rule);
    },
    /**
     * Event handler for @update:check
     * Splices the updated version of the check at the specified index.
     *
     * If -1 is passed as the index, then no action will be taken.
     */
    checkUpdate: function (rule, check, index) {
      const ruleIndex = this.reactiveRules.findIndex((r) => r.id == rule?.id);
      // Guard if rule is not found
      // OR
      // check index == -1  because -1 is the default if no index is passed to CheckForm.
      if (ruleIndex == -1 || index == -1) {
        return;
      }

      this.reactiveRules[ruleIndex].checks_attributes.splice(index, 1, check);
    },
    /**
     * Event handler for @update:disaDescription
     * Splices the updated version of the DISA description at the specified index.
     *
     * If -1 is passed as the index, then no action will be taken.
     */
    disaDescriptionUpdate: function (rule, description, index) {
      const ruleIndex = this.reactiveRules.findIndex((r) => r.id == rule?.id);
      // Guard if rule is not found
      // OR
      // check index == -1  because -1 is the default if no index is passed to DisaRuleDescriptionForm.
      if (ruleIndex == -1 || index == -1) {
        return;
      }

      this.reactiveRules[ruleIndex].disa_rule_descriptions_attributes.splice(index, 1, description);
    },
    /**
     * Event handler for @update:description
     * Splices the updated version of the description at the specified index.
     *
     * If -1 is passed as the index, then no action will be taken.
     */
    descriptionUpdate: function (rule, description, index) {
      const ruleIndex = this.reactiveRules.findIndex((r) => r.id == rule?.id);
      // Guard if rule is not found
      // OR
      // check index == -1  because -1 is the default if no index is passed to RuleDescriptionForm.
      if (ruleIndex == -1 || index == -1) {
        return;
      }

      this.reactiveRules[ruleIndex].rule_descriptions_attributes.splice(index, 1, description);
    },
    /**
     * Indicates to this component that a rule has updated and should be re-fetched.
     *
     * id: The rule ID
     * updated: How the rule is expected to have been changed. Expects any of ['all', 'comments']
     */
    refreshRule: function (id, updated = "all") {
      axios
        .get(`/rules/${id}`)
        .then((response) => this.ruleFetchSuccess(response, updated))
        .catch(this.alertOrNotifyResponse);
    },
    /**
     * Update data with a fetched rule.
     *
     * response: The response from the server
     * updated: How the rule is expected to have been changed. Expects any of ['all', 'comments']
     *
     * Changing behavior based on `updated` is necessary because we do not want to wipe away control
     * changes just beause a user has commented.
     */
    ruleFetchSuccess: function (response, updated = "all") {
      if (response.data.id === undefined) {
        response.data.data = JSON.parse(response.data.data);
      }
      const ruleIndex = this.reactiveRules.findIndex((r) => r.id == response.data.id);
      // If the rule is not in the reactive rules then add it and return early
      if (ruleIndex < 0) {
        this.reactiveRules.push(response.data.data);
        return;
      }

      if (updated == "all") {
        this.reactiveRules.splice(ruleIndex, 1, response.data);
      } else if (updated == "comments") {
        this.reactiveRules[ruleIndex].comments.push(...response.data.comments);
      }
    },
  },
};
</script>

<style scoped></style>
