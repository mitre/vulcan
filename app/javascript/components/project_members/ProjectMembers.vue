<template>
  <div>
    <h1>{{project.name}} - Manage Project Members</h1>
    <NewProjectMember v-bind:project="project"
                      v-bind:available_members="available_members"
                      v-bind:available_roles="available_roles" />
    <ProjectMembersTable v-bind:project="project"
                         v-bind:project_members="project_members"
                         v-bind:available_roles="available_roles" />
  </div>
</template>

<script>
export default {
  name: 'ProjectMembers',
  props: {
    project_members: {
      type: Array,
      required: true,
    },
    project: {
      type: Object,
      required: true
    },
    available_members: {
      type: Array,
      required: true,
    },
    available_roles: {
      type: Array,
      required: true,
    }
  }
}
</script>

<style scoped>

</style>
