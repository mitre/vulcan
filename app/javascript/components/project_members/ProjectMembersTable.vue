<template>
  <div>
    <h2>Project Members</h2>
    
    <table class="table">
      <tr>
        <th>User</th>
        <th>Role</th>
        <th></th>
      </tr>
      <ProjectMember v-bind:key="project_member.email"
                     v-bind:project_member="project_member"
                     v-bind:project="project"
                     v-bind:available_roles="available_roles"
                     v-for="project_member in project_members" />
    </table>
  </div>
</template>

<script>
export default {
  name: 'ProjectMembersTable',
  props: {
    project_members: {
      type: Array,
      required: true,
    },
    project: {
      type: Object,
      required: true
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
