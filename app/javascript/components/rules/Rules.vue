<template>
  <div>
    <b-breadcrumb :items="breadcrumbs"></b-breadcrumb>
    
    <h1>{{project.name}} - Controls</h1>

    <RulesCodeEditorView @ruleUpdated="ruleUpdated" :project="project" :rules="reactiveRules" />
  </div>
</template>

<script>
import axios from 'axios';
export default {
  name: 'Rules',
  props: {
    project: {
      type: Object,
      required: true,
    },
    rules: {
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
    },
    // Authenticity Token for forms
    authenticityToken: function() {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    },
  },
  methods: {
    ruleUpdated: function(id) {
      axios.defaults.headers.common['X-CSRF-Token'] = this.authenticityToken;
      axios.get(`/rules/${id}`)
      .then(this.ruleFetchSuccess)
      .catch(this.alertOrNotifyResponse);
    },
    ruleFetchSuccess: function(response) {
      const ruleIndex = this.reactiveRules.findIndex((rule) => { return rule.id == response.data.id });
      this.reactiveRules.splice(ruleIndex, 1, response.data)
    },
  },
}
</script>

<style scoped>
</style>
