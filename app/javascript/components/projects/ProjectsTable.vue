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
      class="text-center align-middle"
      :items="searchedProjects"
      :fields="fields"
      :per-page="perPage"
      :current-page="currentPage"
      sort-icon-left
    >
      <template #cell(name)="data">
        <b-link v-if="data.item.is_member" :href="getProjectAction(data.item)">
          {{ data.item.name }}
        </b-link>
        <span v-else>{{ data.item.name }}</span>
      </template>

      <template #cell(description)="data">
        {{ truncate(data.item.description, data.item.id) }}
        <b-link v-if="data.item.description" @click="toggleTruncate(data.item.id)">
          {{ truncated[data.item.id] ? "..." : "read less" }}
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
        <span v-if="!data.item.is_member && !data.item.access_request_id">
          <b-button
            class="btn btn-info text-nowrap mx-2 my-3"
            data-method="post"
            :href="requestAccessAction(data.item)"
            rel="nofollow"
          >
            <i class="mdi mdi-account-arrow-right" aria-hidden="true" />
            Request Access
          </b-button>
        </span>
        <span v-if="data.item.access_request_id">
          <b-button
            class="btn btn-danger text-nowrap mx-2 my-3"
            :data-confirm="getLabel(data.item, 'cancel request')"
            data-method="delete"
            :href="cancelAccessRequestAction(data.item)"
            rel="nofollow"
          >
            <i class="mdi mdi-cancel" aria-hidden="true" />
            Cancel Access Request
          </b-button>
        </span>
        <span v-if="is_vulcan_admin">
          <b-button
            class="px-2 m-2"
            variant="danger"
            :data-confirm="getLabel(data.item, 'remove project')"
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
      truncated: {}, // store the truncated state for each project description
      fields: [
        { key: "name", sortable: true },
        { key: "description", label: "Description" },
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
  created: function () {
    this.projects.forEach((project) => {
      this.$set(this.truncated, project.id, true);
    });
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
    // Path to POST/DELETE action to when requesting access to project or cancelling request
    requestAccessAction: function (project) {
      return `/projects/${project.id}/project_access_requests`;
    },
    cancelAccessRequestAction: function (project) {
      return `/projects/${project.id}/project_access_requests/${project.access_request_id}`;
    },
    getLabel: function (project, action) {
      if (action === "remove project") {
        return `Are you sure you want to completely remove project ${project.name} and all of its related data?`;
      } else {
        return `Are you sure you want to cancel your request to access project ${project.name}?`;
      }
    },
    refreshProjects: function () {
      this.$emit("projectRenamed");
    },
    toggleTruncate: function (id) {
      this.$set(this.truncated, id, !this.truncated[id]);
    },
    truncate: function (text, id) {
      if (this.truncated[id] && text && text.length > 75) {
        return text.substring(0, 75);
      }
      return text;
    },
  },
};
</script>

<style scoped>
.floatright {
  float: right;
}
</style>
