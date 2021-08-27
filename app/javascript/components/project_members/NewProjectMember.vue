<template>
  <div id="NewProjectMemberCard" class="card">
    <h2>Add Project Member</h2>

    <form :action="formAction" method="post">
      <div class="row">
        <input
          id="NewProjectMemberAuthenticityToken"
          type="hidden"
          name="authenticity_token"
          :value="authenticityToken"
        />

        <!-- User dropdown -->
        <div class="form-group col-md-6">
          <label for="NewProjectMemberUser">User</label>
          <select
            id="NewProjectMemberUser"
            v-model="selectedUser"
            class="form-control"
            name="project_member[user_id]"
            required
          >
            <option />
            <option
              v-for="available_member in available_members"
              :key="available_member.email"
              :value="available_member.id"
            >
              {{ available_member.email }}
            </option>
          </select>
          <small id="NewProjectMemberUserHelp" class="form-text text-muted" />
        </div>

        <!-- Role dropdown -->
        <div class="form-group col-sm-12 col-md-6">
          <label for="NewProjectMemberRole">Role</label>
          <select
            id="NewProjectMemberRole"
            v-model="selectedRole"
            class="form-control"
            name="project_member[role]"
            required
          >
            <option />
            <option v-for="available_role in available_roles" :key="available_role">
              {{ available_role }}
            </option>
          </select>
          <small id="NewProjectMemberRoleHelp" class="form-text text-muted"
            >User will be assigned this role only for this project.</small
          >
        </div>
      </div>

      <b-button type="submit" variant="primary">Add User to Project</b-button>
    </form>
  </div>
</template>

<script>
import FormMixinVue from "../../mixins/FormMixin.vue";

export default {
  name: "NewProjectMember",
  mixins: [FormMixinVue],
  props: {
    project: {
      type: Object,
      required: true,
    },
    available_members: {
      type: Array,
      required: true,
    },
    available_roles: {
      type: Array,
      required: true,
    },
  },
  data: function () {
    return {
      selectedUser: null,
      selectedRole: null,
    };
  },
  computed: {
    formAction: function () {
      return "/projects/" + this.project.id + "/project_members";
    },
  },
};
</script>

<style scoped>
#NewProjectMemberCard {
  padding: 1em;
  margin: 1em;
}
</style>
