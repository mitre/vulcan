<template>
  <div class="mb-5">
    <b-breadcrumb :items="breadcrumbs"></b-breadcrumb>

    <h1>{{project.name}} - Controls</h1>

    <RulesCodeEditorView @ruleUpdated="ruleUpdated" :project="project" :rules="reactiveRules" :statuses="statuses" :severities="severities" />
  </div>
</template>

<script>
import axios from 'axios';
import AlertMixinVue from '../../mixins/AlertMixin.vue';
import RulesCodeEditorView from './RulesCodeEditorView.vue'
import FormMixinVue from '../../mixins/FormMixin.vue';

export default {
  name: 'Rules',
  mixins: [AlertMixinVue, FormMixinVue],
  components: { RulesCodeEditorView },
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
    }
  },
  data: function () {
    return {
      reactiveRules: this.rules
    }
  },
  computed: {
    breadcrumbs: function() {
      return [
        {
          text: 'Projects',
          href: '/projects'
        },
        {
          text: this.project.name,
          href: '/projects/' + this.project.id
        },
        {
          text: 'Controls',
          active: true
        }
      ]
    }
  },
  methods: {
    /**
     * Indicates to this component that a rule has updated and should be re-fetched.
     *
     * id: The rule ID
     * updated: How the rule is expected to have been changed. Expects any of ['all', 'comments']
     */
    ruleUpdated: function(id, updated = 'all') {
      axios.get(`/rules/${id}`)
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
    ruleFetchSuccess: function(response, updated) {
      const ruleIndex = this.reactiveRules.findIndex((rule) => { return rule.id == response.data.id });

      if (updated == 'all') {
        this.reactiveRules.splice(ruleIndex, 1, response.data);
      }
      else if (updated == 'comments') {
        console.log('comments!');
        console.log(response.data.comments);
        this.reactiveRules[ruleIndex].comments.push(... response.data.comments);
      }
    },
  },
}
</script>

<style scoped>
</style>
