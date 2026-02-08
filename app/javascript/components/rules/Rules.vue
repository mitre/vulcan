<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <RulesCodeEditorView
      :project="project"
      :component="component"
      :rules="reactiveRules"
      :statuses="statuses"
      :severities="severities"
      :effective-permissions="effective_permissions"
      :current-user-id="current_user_id"
      :available-roles="available_roles"
    />
  </div>
</template>

<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import RulesCodeEditorView from "./RulesCodeEditorView.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";
import SortRulesMixin from "../../mixins/SortRulesMixin.vue";
import _ from "lodash";

export default {
  name: "Rules",
  components: { RulesCodeEditorView },
  mixins: [AlertMixinVue, FormMixinVue, SortRulesMixin],
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
    statuses: {
      type: Array,
      required: true,
    },
    severities: {
      type: Array,
      required: true,
    },
    available_roles: {
      type: Array,
      required: true,
    },
  },
  data: function () {
    return {
      reactiveRules: _.cloneDeep(this.rules).sort(this.compareRules),
    };
  },
  computed: {
    breadcrumbs: function () {
      // Build component name with version (e.g., "Test 2 V1R1")
      let componentText = this.component.name;
      if (this.component.version || this.component.release) {
        componentText += " ";
        if (this.component.version) componentText += `V${this.component.version}`;
        if (this.component.release) componentText += `R${this.component.release}`;
      }
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
          text: componentText,
          href: "/components/" + this.component.id,
        },
        {
          text: "Edit",
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
    this.$root.$on("addSatisfied:rule", this.addSatisfiedRule);
    this.$root.$on("removeSatisfied:rule", this.removeSatisfiedRule);
  },
  methods: {
    /**
     * Event handler for @addSatisfied:rule
     *
     * Updates relationship arrays locally to preserve unsaved changes.
     * Previously called refreshRule() which overwrote local changes with server data.
     */
    addSatisfiedRule: function (rule_id, satisfied_by_rule_id, successCallback = null) {
      axios
        .post(`/rule_satisfactions`, { rule_id, satisfied_by_rule_id })
        .then((response) => {
          this.alertOrNotifyResponse(response);

          // Update relationships locally instead of full refresh
          // This preserves any unsaved local changes (status, title, etc.)
          const ruleIndex = this.reactiveRules.findIndex((r) => r.id == rule_id);
          const satisfiedByIndex = this.reactiveRules.findIndex(
            (r) => r.id == satisfied_by_rule_id,
          );

          if (ruleIndex >= 0 && satisfiedByIndex >= 0) {
            const rule = this.reactiveRules[ruleIndex];
            const satisfiedByRule = this.reactiveRules[satisfiedByIndex];

            // Add to satisfied_by array (rule is satisfied by satisfiedByRule)
            if (!rule.satisfied_by.some((r) => r.id === satisfied_by_rule_id)) {
              rule.satisfied_by.push({
                id: satisfiedByRule.id,
                rule_id: satisfiedByRule.rule_id,
                version: satisfiedByRule.version,
                fixtext: satisfiedByRule.fixtext,
              });
            }

            // Add to satisfies array (satisfiedByRule satisfies rule)
            if (!satisfiedByRule.satisfies.some((r) => r.id === rule_id)) {
              satisfiedByRule.satisfies.push({
                id: rule.id,
                rule_id: rule.rule_id,
                version: rule.version,
              });
            }
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
     * Event handler for @removeSatisfied:rule
     *
     * Updates relationship arrays locally to preserve unsaved changes.
     * Previously called refreshRule() which overwrote local changes with server data.
     */
    removeSatisfiedRule: function (rule_id, satisfied_by_rule_id, successCallback = null) {
      axios
        .delete(`/rule_satisfactions/${rule_id}`, { data: { rule_id, satisfied_by_rule_id } })
        .then((response) => {
          this.alertOrNotifyResponse(response);

          // Update relationships locally instead of full refresh
          // This preserves any unsaved local changes (status, title, etc.)
          const ruleIndex = this.reactiveRules.findIndex((r) => r.id == rule_id);
          const satisfiedByIndex = this.reactiveRules.findIndex(
            (r) => r.id == satisfied_by_rule_id,
          );

          if (ruleIndex >= 0) {
            const rule = this.reactiveRules[ruleIndex];
            // Remove from satisfied_by array
            rule.satisfied_by = rule.satisfied_by.filter((r) => r.id !== satisfied_by_rule_id);
          }

          if (satisfiedByIndex >= 0) {
            const satisfiedByRule = this.reactiveRules[satisfiedByIndex];
            // Remove from satisfies array
            satisfiedByRule.satisfies = satisfiedByRule.satisfies.filter((r) => r.id !== rule_id);
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
