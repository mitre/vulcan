<template>
  <div>
    <!-- Table information -->
    <p>
      <b>Project Count:</b> <span>{{ projectCount }}</span>
    </p>

    <!-- Project search -->
    <div class="row">
      <div class="col-6">
        <div class="input-group">
          <div class="input-group-prepend">
            <div class="input-group-text">
              <i class="mdi mdi-magnify" aria-hidden="true" />
            </div>
          </div>
          <input
            id="projectSearch"
            v-model="search"
            type="text"
            class="form-control"
            placeholder="Search projects by name..."
          />
        </div>
      </div>
    </div>

    <br />

    <!-- Projects table -->
    <b-table
      id="projects-table"
      :items="searchedProjects"
      :fields="fields"
      :per-page="perPage"
      :current-page="currentPage"
    >
      <template #cell(name)="data">
        <b-link :href="getProjectAction(data.item)">
          {{ data.item.name }}
        </b-link>
      </template>

      <template #cell(updated_at)="data">
        {{ friendlyDateTime(data.item.updated_at) }}
      </template>

      <!-- Column template for Actions -->
      <!-- TODO - control actions available here based on user's admin status and/or project membership roles -->
      <template #cell(actions)="data">
        <b-dropdown text="Actions" class="m-md-2" right>
          <!-- View controls dropdown item -->
          <b-dropdown-item :href="projectControlsAction(data.item)">
            <i class="mdi mdi-file-document" aria-hidden="true" />
            View Controls
          </b-dropdown-item>
          <!-- Manage projects dropdown item -->
          <b-dropdown-item :href="manageProjectMembersAction(data.item)">
            <i class="mdi mdi-account-circle" aria-hidden="true" />
            Manage Project Members
          </b-dropdown-item>
          <!-- Delete project dropdown item -->
          <b-dropdown-item
            data-confirm="Are you sure you want to permanently delete this project?"
            data-method="delete"
            :href="formAction(data.item)"
            rel="nofollow"
          >
            <i class="mdi mdi-trash-can" aria-hidden="true" />
            Delete Project
          </b-dropdown-item>
        </b-dropdown>
      </template>
    </b-table>

    <!-- Pagination controls -->
    <b-pagination
      v-model="currentPage"
      :total-rows="rows"
      :per-page="perPage"
      aria-controls="projects-table"
    />
  </div>
</template>

<script>
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
export default {
  name: "ProjectsTable",
  mixins: [DateFormatMixinVue],
  props: {
    projects: {
      type: Array,
      required: true,
    },
  },
  data: function () {
    return {
      search: "",
      perPage: 10,
      currentPage: 1,
      fields: [
        "name",
        { key: "project_members_count", label: "Members" },
        { key: "updated_at", label: "Last Updated" },
        {
          key: "actions",
          label: "Actions",
          thClass: "text-right",
          tdClass: "p-0 text-right",
        },
      ],
    };
  },
  computed: {
    // Search projects based on name
    searchedProjects: function () {
      let downcaseSearch = this.search.toLowerCase();
      return this.projects.filter((project) =>
        project.name.toLowerCase().includes(downcaseSearch)
      );
    },
    // Used by b-pagination to know how many total rows there are
    rows: function () {
      return this.searchedProjects.length;
    },
    // Total number of projects in the system
    projectCount: function () {
      return this.projects.length;
    },
  },
  methods: {
    // Path to POST/DELETE to when updating/deleting a project
    formAction: function (project) {
      return "/projects/" + project.id;
    },
    // Path to the manage project members page
    manageProjectMembersAction: function (project) {
      return "/projects/" + project.id + "/project_members";
    },
    // Path to the project controls page
    projectControlsAction: function (project) {
      return "/projects/" + project.id + "/controls";
    },
    getProjectAction: function (project) {
      return "/projects/" + project.id;
    },
  },
};
</script>

<style scoped></style>
