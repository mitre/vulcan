<template>
  <div>
    <h2>{{ project_members_count }} Members</h2>

    <!-- User search -->
    <div class="row">
      <div class="col-6">
        <div class="input-group">
          <div class="input-group-prepend">
            <div class="input-group-text">
              <i class="mdi mdi-magnify" aria-hidden="true" />
            </div>
          </div>
          <input
            id="userSearch"
            v-model="search"
            type="text"
            class="form-control"
            placeholder="Search users by name or email..."
          />
        </div>
      </div>
      <div v-if="editable && available_members && available_roles" class="col-6 float-right">
        <b-button v-b-modal.new-project-member variant="primary" size="large" class="float-right">
          New Member
        </b-button>

        <b-modal
          id="new-project-member"
          size="md"
          title="Add New Project Member"
          centered
          :hide-footer="true"
        >
          <NewProjectMember
            :project="project"
            :available_members="available_members"
            :available_roles="available_roles"
          />
        </b-modal>
      </div>
    </div>

    <br />

    <!-- Project Members table -->
    <b-table
      id="project-members-table"
      :items="searchedProjectMembers"
      :fields="fields"
      :per-page="perPage"
      :current-page="currentPage"
    >
      <!-- Column template for Name -->
      <template #cell(name)="data">
        {{ data.item.name }}
        <br />
        <small>{{ data.item.email }}</small>
      </template>

      <!-- Column template for Role -->
      <template v-if="editable" #cell(role)="data">
        <form :id="formId(data.item)" :action="formAction(data.item)" method="post">
          <input type="hidden" name="_method" value="put" />
          <input type="hidden" name="authenticity_token" :value="authenticityToken" />
          <select
            v-model="data.item.role"
            class="form-control"
            name="project_member[role]"
            @change="roleChanged($event, data.item)"
          >
            <option v-for="available_role in available_roles" :key="available_role">
              {{ available_role }}
            </option>
          </select>
        </form>
      </template>

      <template v-else #cell(role)="data">
        {{ data.item.role }}
      </template>

      <!-- Column template for Actions -->
      <template v-if="editable" #cell(actions)="data">
        <b-button
          class="projectMemberDeleteButton"
          variant="danger"
          data-confirm="Are you sure you want to remove this user from the project?"
          data-method="delete"
          :href="formAction(data.item)"
          rel="nofollow"
        >
          <i class="mdi mdi-trash-can" aria-hidden="true" />
          Remove
        </b-button>
      </template>
    </b-table>

    <!-- Pagination controls -->
    <b-pagination
      v-model="currentPage"
      :total-rows="rows"
      :per-page="perPage"
      aria-controls="project-members-table"
    />
  </div>
</template>

<script>
import FormMixinVue from "../../mixins/FormMixin.vue";
import NewProjectMember from "./NewProjectMember.vue";

export default {
  name: "ProjectMembersTable",
  components: { NewProjectMember },
  mixins: [FormMixinVue],
  props: {
    project_members: {
      type: Array,
      required: true,
    },
    project: {
      type: Object,
      required: true,
    },
    editable: {
      type: Boolean,
      default: false,
    },
    available_roles: {
      type: Array,
      required: false,
    },
    available_members: {
      type: Array,
      required: true,
    },
    project_members_count: {
      type: Number,
      required: true,
    },
  },
  data: function () {
    return {
      search: "",
      perPage: 10,
      currentPage: 1,
      fields: [
        { key: "name", label: "User", sortable: true },
        { key: "role", sortable: true },
        { key: "actions", label: "" },
      ],
    };
  },
  computed: {
    // Search users based on name and email
    searchedProjectMembers: function () {
      let downcaseSearch = this.search.toLowerCase();
      return this.project_members.filter(
        (pm) =>
          pm.email.toLowerCase().includes(downcaseSearch) ||
          pm.name.toLowerCase().includes(downcaseSearch)
      );
    },
    // Used by b-pagination to know how many total rows there are
    rows: function () {
      return this.searchedProjectMembers.length;
    },
  },
  methods: {
    // Automatically submit the form when a user selects a form option
    roleChanged: function (_event, project_member) {
      document.getElementById(this.formId(project_member)).submit();
    },
    // Generator for a unique form id for the user role dropdown
    formId: function (project_member) {
      return "ProjectMember-" + project_member.id;
    },
    // Path to POST/DELETE to when updating/deleting a user
    formAction: function (project_member) {
      return `/projects/${this.project.id}/project_members/${project_member.id}`;
    },
  },
};
</script>

<style scoped>
.projectMemberDeleteButton {
  float: right;
}
</style>
