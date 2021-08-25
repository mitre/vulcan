<template>
  <div>
    <h1>{{project.name}} - Manage Project Members</h1>
    <NewProjectMember :project="project"
                      :available_members="available_members"
                      :available_roles="available_roles" />
    <ProjectMembersTable :editable="true"
                         :project="project"
                         :project_members="project_members"
                         :available_roles="available_roles"
                         :project_members_count="project_members_count"/>
  </div>
</template>

<script>
import NewProjectMember from './NewProjectMember.vue'
import ProjectMembersTable from './ProjectMembersTable.vue'

export default {
  components: { NewProjectMember, ProjectMembersTable },
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
