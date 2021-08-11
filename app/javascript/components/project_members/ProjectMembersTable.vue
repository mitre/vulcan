<template>
  <div>
    <h2>Project Members</h2>

    <!-- User search -->
    <div class="row">
      <div class="col-6">
        <div class="input-group">
          <div class="input-group-prepend">
            <div class="input-group-text"><i class="mdi mdi-magnify" aria-hidden="true"></i></div>
          </div>
          <input type="text" class="form-control" id="userSearch" placeholder="Search users by name or email..." v-model="search">
        </div>
      </div>
    </div>

    <br/>
    
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
                     v-for="project_member in searchedProjectMembers" />
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
  },
  data: function () {
    return {
      search: ""
    }
  },
  computed: {
    searchedProjectMembers: function () {
      let downcaseSearch = this.search.toLowerCase()
      return this.project_members.filter(pm => pm.email.toLowerCase().includes(downcaseSearch) || pm.name.toLowerCase().includes(downcaseSearch));
    }
  }
}
</script>

<style scoped>

</style>
