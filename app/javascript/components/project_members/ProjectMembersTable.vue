<template>
  <div>
    <h2>Project Members</h2>

    <!-- Table information -->
    <p><b>Project Member Count:</b> <span>{{projectMemberCount}}</span></p>

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

    <!-- Project Members table -->
    <b-table
      id="users-table"
      :items="searchedProjectMembers"
      :fields="fields"
      :per-page="perPage"
      :current-page="currentPage"
    >
      <!-- Column template for Name -->
      <template #cell(name)="data">
        {{data.item.name}}
        <br/>
        <small>{{data.item.email}}</small>
      </template>

      <!-- Column template for Role -->
      <template #cell(role)="data">
        <form v-bind:id="formId(data.item)" v-bind:action="formAction(data.item)" method="post">
          <input type="hidden" name="_method" value="put" />
          <input type="hidden" name="authenticity_token" v-bind:value="authenticityToken" />
          <select class="form-control" name="project_member[role]" @change="roleChanged($event, data.item)" v-model="data.item.role">
            <option v-bind:key="available_role" v-for="available_role in available_roles">{{available_role}}</option>
          </select>
        </form>
      </template>

      <!-- Column template for Actions -->
      <template #cell(actions)="data">
        <b-button class="projectMemberDeleteButton" 
                  variant="danger"
                  data-confirm="Are you sure you want to remove this user from the project?" 
                  data-method="delete" 
                  v-bind:href="formAction(data.item)"
                  rel="nofollow">
          <i class="mdi mdi-trash-can" aria-hidden="true"></i>
          Remove
        </b-button>
      </template>
    </b-table>

    <!-- Pagination controls -->
    <b-pagination
      v-model="currentPage"
      :total-rows="rows"
      :per-page="perPage"
      aria-controls="users-table"
    ></b-pagination>
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
      search: "",
      perPage: 10,
      currentPage: 1,
      fields: [
        { key: 'name', label: 'User' },
        'role',
        { key: 'actions', label: '' }
      ]
    }
  },
  computed: {
    // Search users based on name and email
    searchedProjectMembers: function () {
      let downcaseSearch = this.search.toLowerCase()
      return this.project_members.filter(pm => pm.email.toLowerCase().includes(downcaseSearch) || pm.name.toLowerCase().includes(downcaseSearch));
    },
    // Used by b-pagination to know how many total rows there are
    rows: function() {
      return this.searchedProjectMembers.length;
    },
    // Authenticity Token for forms
    authenticityToken: function() {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    },
    // Total number of users in the system
    projectMemberCount: function() {
      return this.project_members.length;
    }
  },
  methods: {
    // Automatically submit the form when a user selects a form option
    roleChanged: function(event, project_member) {
      document.getElementById(this.formId(project_member)).submit();
    },
    // Generator for a unique form id for the user role dropdown
    formId: function(project_member) {
      return "ProjectMember-" + project_member.id;
    },
    // Path to POST/DELETE to when updating/deleting a user
    formAction: function(project_member) {
      return "/users/" + project_member.id;
    },
  }
}
</script>

<style scoped>
.projectMemberDeleteButton {
  float: right;
}
</style>
