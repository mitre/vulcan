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

      <template #cell(actions)="data">
        <RenameProjectModal
          v-if="is_vulcan_admin || data.item.admin"
          :project="data.item"
          class="floatright"
          @projectRenamed="refreshProjects"
        />
        <span>
          <b-button
            v-if="is_vulcan_admin"
            class="px-2 m-2"
            variant="danger"
            :data-confirm="getLabel(data.item)"
            data-method="delete"
            :href="destroyAction(data.item)"
            rel="nofollow"
          >
            <i class="mdi mdi-trash-can" aria-hidden="true" />
            Remove
          </b-button>
        </span>
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
import RenameProjectModal from "./RenameProjectModal.vue";

export default {
  name: "ProjectsTable",
  components: { RenameProjectModal },
  mixins: [DateFormatMixinVue],
  props: {
    projects: {
      type: Array,
      required: true,
    },
    is_vulcan_admin: {
      type: Boolean,
      required: true,
      default: false,
    },
  },
  data: function () {
    return {
      search: "",
      perPage: 10,
      currentPage: 1,
      fields: [
        { key: "name", sortable: true },
        { key: "memberships_count", label: "Members", sortable: true },
        { key: "updated_at", label: "Last Updated", sortable: true },
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
      return this.projects.filter((project) => project.name.toLowerCase().includes(downcaseSearch));
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
      return `/projects/${project.id}`;
    },
    // Path to the manage project members page
    manageProjectMembersAction: function (project) {
      return `/projects/${project.id}/project_members`;
    },
    // Path to the project controls page
    projectControlsAction: function (project) {
      return `/projects/${project.id}/controls`;
    },
    getProjectAction: function (project) {
      return `/projects/${project.id}`;
    },
    destroyAction: function (project) {
      return `/projects/${project.id}`;
    },
    getLabel: function (project) {
      return `Are you sure you want to completely remove project ${project.name} and all of its related data?`;
    },
    refreshProjects: function () {
      this.$emit("projectRenamed");
    },
  },
};
</script>

<style scoped>
.floatright {
  float: right;
}
</style>
