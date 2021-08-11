<template>
  <div id="NewProjectMemberCard" class="card">
    <h2>Add Project Member</h2>

    <form v-bind:action="formAction" method="post">
      <div class="row">
        <input type="hidden" id="NewProjectMemberAuthenticityToken" name="authenticity_token" v-bind:value="authenticityToken" />

        <!-- User dropdown -->
        <div class="form-group col-md-6">
          <label for="NewProjectMemberUser">User</label>
          <select class="form-control" id="NewProjectMemberUser" name="project_member[user_id]" v-model="selectedUser" required>
            <option/>
            <option v-bind:key="available_member.email" v-for="available_member in available_members" v-bind:value="available_member.id">
              {{available_member.email}}
            </option>
          </select>
          <small id="NewProjectMemberUserHelp" class="form-text text-muted"></small>
        </div>

        <!-- Role dropdown -->
        <div class="form-group col-sm-12 col-md-6">
          <label for="NewProjectMemberRole">Role</label>
          <select class="form-control" id="NewProjectMemberRole" name="project_member[role]" v-model="selectedRole" required>
            <option/>
            <option v-bind:key="available_role" v-for="available_role in available_roles">{{available_role}}</option>
          </select>
          <small id="NewProjectMemberRoleHelp" class="form-text text-muted">User will be assigned this role only for this project.</small>
        </div>
      </div>

      <button type="submit" class="btn btn-primary">Add User to Project</button>
    </form>
  </div>
</template>

<script>
export default {
  name: 'NewProjectMember',
  props: {
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
  },
  data: function () {
    return {
      selectedUser: null,
      selectedRole: null
    }
  },
  computed: {
    formAction: function () {
      return "/projects/" + this.project.id + "/project_members";
    },
    authenticityToken: function() {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    }
  }
}
</script>

<style scoped>
#NewProjectMemberCard {
  padding: 1em;
  margin: 1em;
}
</style>
