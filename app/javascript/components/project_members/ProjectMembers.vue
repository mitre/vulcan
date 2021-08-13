<template>
  <div>
    <h1>{{project.name}} - Manage Project Members</h1>
    <NewProjectMember :project="project"
                      :available_members="available_members"
                      :available_roles="available_roles" />
    <ProjectMembersTable :project="project"
                         :project_members="project_members"
                         :available_roles="available_roles" />
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
