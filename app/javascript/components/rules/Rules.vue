<template>
  <div>
    <b-breadcrumb :items="breadcrumbs"></b-breadcrumb>
    
    <h1>{{project.name}} - Controls</h1>

    <RulesCodeEditorView :project="project" :rules="rules" />
  </div>
</template>

<script>
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
  }
}
</script>

<style scoped>

</style>
