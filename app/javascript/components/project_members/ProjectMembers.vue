<template>
  <div>
    <h1>{{ project.name }} - Manage Project Members</h1>
    <ProjectMembersTable :project="project"
                         :project_members="project_members"
                         :available_members="available_members"
                         :available_roles="available_roles"
                         :project_members_count="project_members_count"/>
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
    },
    project_members_count: {
      type: Number,
      required: true
    }
  }
}
</script>

<style scoped>

</style>
