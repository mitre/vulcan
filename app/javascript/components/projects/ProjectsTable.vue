<template>
  <div>
    <!-- Delete Confirmation Modal -->
    <ConfirmDeleteModal
      v-model="showDeleteModal"
      :item-name="projectToDelete ? projectToDelete.name : ''"
      item-type="project"
      :is-deleting="isDeleting"
      warning-message="This will permanently delete the project and all related data."
      deleting-message="Removing project and all components..."
      @confirm="confirmDelete"
      @cancel="cancelDelete"
    />

    <!-- Table information -->
    <p>
      <b>Project Count:</b> <b-badge variant="info">{{ projectCount }}</b-badge>
    </p>
    <small v-if="projectCount > 0" class="text-info">
      {{ discoverableProjectCount }} Discoverable Project{{
        discoverableProjectCount > 1 ? "s" : ""
      }}
    </small>

    <!-- Project search -->
    <div class="d-flex flex-md-row flex-sm-column justify-content-start">
      <div class="col-lg-6">
        <div class="input-group">
          <div class="input-group-prepend">
            <div class="input-group-text">
              <b-icon icon="search" aria-hidden="true" />
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
      <div class="d-flex flex-wrap mx-auto mt-sm-2 mt-md-0 justify-content-lg-start">
        <b-form-checkbox
          v-model="filter.allToggled"
          :disabled="filter.allToggled"
          size="lg"
          class="ml-3"
          switch
        >
          <small>All Projects</small>
        </b-form-checkbox>
        <b-form-checkbox v-model="filter.myProjectsToggled" size="lg" class="ml-3" switch>
          <small>Show My Projects</small>
          <b-icon
            v-b-tooltip.hover.html="'Projects I am a member of'"
            icon="info-circle"
            aria-hidden="true"
          />
        </b-form-checkbox>
        <b-form-checkbox v-model="filter.discoverableToggled" size="lg" class="ml-3" switch>
          <small>Show Discoverable Projects</small>
          <b-icon
            v-b-tooltip.hover.html="
              'Projects intended to be discovered and potentially collaborated upon by other users. Interested users can request access to the project'
            "
            icon="info-circle"
            aria-hidden="true"
          />
        </b-form-checkbox>
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
      sort-by="name"
      sort-icon-left
    >
      <template #cell(name)="data">
        <b-link v-if="data.item.is_member" :href="getProjectAction(data.item)">
          {{ data.item.name }}
        </b-link>
        <span v-else>{{ data.item.name }}</span>
      </template>

      <template #cell(pending_comment_count)="data">
        <span v-if="data.item.total_comment_count > 0">
          <b-link
            v-if="data.item.pending_comment_link && data.item.is_member"
            v-b-tooltip.hover
            :href="data.item.pending_comment_link"
            :title="commentBadgeTitle(data.item)"
          >
            <b-badge v-if="data.item.pending_comment_count > 0" variant="warning" class="mr-1">
              <b-icon icon="chat-left-text" /> {{ data.item.pending_comment_count }} pending
            </b-badge>
            <small class="text-muted"> {{ data.item.total_comment_count }} total </small>
          </b-link>
          <span v-else>
            <b-badge v-if="data.item.pending_comment_count > 0" variant="light" class="mr-1">
              <b-icon icon="chat-left-text" /> {{ data.item.pending_comment_count }}
            </b-badge>
            <small class="text-muted">{{ data.item.total_comment_count }} total</small>
          </span>
        </span>
        <span v-else class="text-muted">—</span>
      </template>

      <template #cell(description)="data">
        {{ truncate(data.item.description, data.item.id) }}
        <b-link
          v-if="data.item.description && data.item.description.length > 75"
          @click="toggleTruncate(data.item.id)"
        >
          {{ truncated[data.item.id] ? "..." : "read less" }}
        </b-link>
      </template>

      <template #cell(updated_at)="data">
        {{ friendlyDateTime(data.item.updated_at) }}
      </template>

      <template #cell(actions)="data">
        <!-- Admin actions render disabled-with-tooltip for non-admin members,
             never v-if'd away, per the vulcan-disabled-not-hidden rule. -->
        <UpdateProjectDetailsModal
          :project="data.item"
          :is_project_table="true"
          :disabled="!canAdminProject(data.item)"
          :disabled-title="ADMIN_ONLY_TOOLTIP"
          class="floatright"
          @projectUpdated="refreshProjects"
        />
        <!-- Access-request controls are status-driven (absence = situation
             does not apply) — these stay v-if'd per the disabled-not-hidden
             scope clarification. -->
        <span v-if="!data.item.is_member && !data.item.access_request_id">
          <b-button
            class="btn btn-info text-nowrap mx-2 my-3"
            data-method="post"
            :href="requestAccessAction(data.item)"
            rel="nofollow"
          >
            <b-icon icon="person-plus" aria-hidden="true" />
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
            <b-icon icon="x-circle" aria-hidden="true" />
            Cancel Access Request
          </b-button>
        </span>
        <b-button
          v-b-tooltip.hover="canAdminProject(data.item) ? '' : ADMIN_ONLY_TOOLTIP"
          class="px-2 m-2"
          variant="danger"
          data-testid="remove-project-btn"
          :disabled="!canAdminProject(data.item)"
          :title="canAdminProject(data.item) ? '' : ADMIN_ONLY_TOOLTIP"
          @click="openDeleteModal(data.item)"
        >
          <b-icon icon="trash" aria-hidden="true" />
          Remove
        </b-button>
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
import axios from "axios";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import UpdateProjectDetailsModal from "./UpdateProjectDetailsModal.vue";
import ConfirmDeleteModal from "../shared/ConfirmDeleteModal.vue";
import { useDeleteConfirmation } from "../../composables";

export default {
  name: "ProjectsTable",
  components: { UpdateProjectDetailsModal, ConfirmDeleteModal },
  mixins: [DateFormatMixinVue, AlertMixinVue],
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
  setup() {
    const {
      showModal: showDeleteModal,
      itemToDelete: projectToDelete,
      isDeleting,
      openModal: openDeleteModal,
      cancel: cancelDelete,
      confirm: confirmDeleteAction,
    } = useDeleteConfirmation();

    return {
      showDeleteModal,
      projectToDelete,
      isDeleting,
      openDeleteModal,
      cancelDelete,
      confirmDeleteAction,
    };
  },
  data: function () {
    return {
      search: "",
      perPage: 10,
      currentPage: 1,
      truncated: {}, // store the truncated state for each project description
      // Tooltip shown on admin-only buttons when the current user lacks
      // admin rights — keeps the control discoverable per the
      // vulcan-disabled-not-hidden rule.
      ADMIN_ONLY_TOOLTIP: "Project admin only",
      filter: {
        discoverableToggled: this.is_vulcan_admin,
        myProjectsToggled: true,
        allToggled: this.is_vulcan_admin,
      },
      fields: [
        { key: "name", sortable: true },
        { key: "description", label: "Description" },
        { key: "memberships_count", label: "Members", sortable: true },
        {
          key: "pending_comment_count",
          label: "Comments",
          sortable: true,
          thClass: "text-center",
          tdClass: "text-center",
        },
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
      let projects = [];
      if (this.filter.allToggled) {
        projects = this.projects;
      } else if (this.filter.discoverableToggled) {
        projects = this.projects.filter((project) => project.visibility === "discoverable");
      } else if (this.filter.myProjectsToggled) {
        projects = this.projects.filter((project) => project.is_member);
      }
      let downcaseSearch = this.search.toLowerCase();
      return projects.filter((project) =>
        (project.name || "").toLowerCase().includes(downcaseSearch),
      );
    },
    // Used by b-pagination to know how many total rows there are
    rows: function () {
      return this.searchedProjects.length;
    },
    // Total number of user's projects
    projectCount: function () {
      return this.projects.length;
    },
    // Total number of discoverable projects in the system
    discoverableProjectCount: function () {
      return this.projects.filter((project) => project.visibility === "discoverable").length;
    },
  },
  watch: {
    filter: {
      handler(_) {
        localStorage.setItem("projectTableFilters", JSON.stringify(this.filter));
      },
      deep: true,
    },
    "filter.allToggled": function (newValue, oldValue) {
      // Handle changes in individual field checkboxes
      if (newValue) {
        this.filter.discoverableToggled = true;
        this.filter.myProjectsToggled = true;
      }
    },
    "filter.discoverableToggled": function (newValue, oldValue) {
      // Handle changes in individual field checkboxes
      if (newValue && this.filter.myProjectsToggled) {
        this.filter.allToggled = true;
      } else {
        this.filter.allToggled = false;
      }
    },
    "filter.myProjectsToggled": function (newValue, oldValue) {
      // Handle changes in individual field checkboxes
      if (newValue && this.filter.discoverableToggled) {
        this.filter.allToggled = true;
      } else {
        this.filter.allToggled = false;
      }
    },
  },
  mounted: function () {
    // Persist `filters` across page loads
    if (localStorage.getItem("projectTableFilters")) {
      try {
        this.filter = JSON.parse(localStorage.getItem("projectTableFilters"));
      } catch (e) {
        localStorage.removeItem("projectTableFilters");
      }
    }
  },
  destroyed() {
    window.removeEventListener("scroll", this.handleScroll);
  },
  created: function () {
    this.projects.forEach((project) => {
      this.$set(this.truncated, project.id, true);
    });
  },
  methods: {
    // Whether the current user can admin a project (site admin OR project admin).
    // Matches backend authorize_admin_project (User#can_admin_project?).
    canAdminProject(project) {
      return this.is_vulcan_admin || project.admin;
    },
    // Tooltip text for the comments-column link — explicit so users
    // know what the click will do based on the project's state.
    commentBadgeTitle(project) {
      const pending = project.pending_comment_count;
      const total = project.total_comment_count;
      if (pending > 0) {
        return `Open triage: ${pending} pending of ${total} total comment${total === 1 ? "" : "s"}`;
      }
      return `Open comments: ${total} total comment${total === 1 ? "" : "s"} (all triaged)`;
    },
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
      this.$emit("projectUpdated");
    },
    async confirmDelete() {
      const { success, error } = await this.confirmDeleteAction(async (project) => {
        const response = await axios.delete(`/projects/${project.id}.json`);
        this.alertOrNotifyResponse(response);
      });

      if (success) {
        this.$emit("projectUpdated");
      } else if (error) {
        this.alertOrNotifyResponse(error);
      }
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
