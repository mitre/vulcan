<template>
  <div>
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
    
    <!-- User table -->
    <table class="table">
      <tr>
        <th>User</th>
        <th>Type</th>
        <th>Role</th>
        <th></th>
      </tr>
      <User v-bind:key="user.id"
            v-bind:user="user"
            v-for="user in searchedUsers" />
    </table>
  </div>
</template>

<script>
export default {
  name: 'UsersTable',
  props: {
    users: {
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
    searchedUsers: function () {
      let downcaseSearch = this.search.toLowerCase()
      return this.users.filter(user => user.email.toLowerCase().includes(downcaseSearch) || user.name.toLowerCase().includes(downcaseSearch));
    }
  }
}
</script>

<style scoped>

</style>
