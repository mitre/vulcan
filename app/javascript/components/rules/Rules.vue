<template>
  <div class="mb-5">
    <b-breadcrumb :items="breadcrumbs" />

    <h1>{{ project.name }} - Controls</h1>

    <RulesCodeEditorView
      :project="project"
      :rules="reactiveRules"
      :statuses="statuses"
      :severities="severities"
      @ruleUpdated="ruleUpdated"
      @update:rule="ruleUpdate($event)"
    />
  </div>
</template>

<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import RulesCodeEditorView from "./RulesCodeEditorView.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";

export default {
  name: "Rules",
  components: { RulesCodeEditorView },
  mixins: [AlertMixinVue, FormMixinVue],
  props: {
    project: {
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
  },
  data: function () {
    return {
      reactiveRules: this.rules,
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
          text: "Controls",
          active: true,
        },
      ];
    },
  },
  mounted() {
    this.$root.$on("update:rule", this.ruleUpdate);
    this.$root.$on("update:check", this.checkUpdate);
    this.$root.$on("update:description", this.descriptionUpdate);
    this.$root.$on("update:disaDescription", this.disaDescriptionUpdate);
    this.$root.$on("add:check", this.checkUpdate);
    this.$root.$on("add:description", this.descriptionUpdate);
    this.$root.$on("add:disaDescription", this.disaDescriptionUpdate);
  },
  methods: {
    /**
     * Event handler for @add:description
     */
    addRuleDescription: function (rule) {
      const ruleIndex = this.reactiveRules.findIndex((r) => r.id == rule.id);
      // Guard if rule is not found
      if (ruleIndex == -1) {
        return;
      }

      this.reactiveRules[ruleIndex].rule_descriptions_attributes.push({
        description: "",
        rule_id: this.rule.id,
        _destroy: false,
      });
    },
    /**
     * Event handler for @add:check
     */
    addCheck: function (rule) {
      const ruleIndex = this.reactiveRules.findIndex((r) => r.id == rule.id);
      // Guard if rule is not found
      if (ruleIndex == -1) {
        return;
      }

      this.reactiveRules[ruleIndex].checks_attributes.push({
        system: "",
        content_ref_name: "",
        content_ref_href: "",
        content: "",
        rule_id: this.rule.id,
        _destroy: false,
      });
    },
    /**
     * Event handler for @add:disaDescription
     */
    addDisaRuleDescription: function (rule) {
      const ruleIndex = this.reactiveRules.findIndex((r) => r.id == rule.id);
      // Guard if rule is not found
      if (ruleIndex == -1) {
        return;
      }

      this.reactiveRules[ruleIndex].disa_rule_descriptions_attributes.push({
        description: "",
        rule_id: this.rule.id,
        _destroy: false,
      });
    },
    /**
     * Event handler for @update:rule.
     * Splices the updated version of the rule where the previous rule was.
     */
    ruleUpdate: function (rule) {
      const index = this.reactiveRules.findIndex((r) => r.id == rule.id);
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
      const ruleIndex = this.reactiveRules.findIndex((r) => r.id == rule.id);
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
      const ruleIndex = this.reactiveRules.findIndex((r) => r.id == rule.id);
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
      const ruleIndex = this.reactiveRules.findIndex((r) => r.id == rule.id);
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
    ruleUpdated: function (id, updated = "all") {
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
    ruleFetchSuccess: function (response, updated) {
      const ruleIndex = this.reactiveRules.findIndex((rule) => {
        return rule.id == response.data.id;
      });

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
