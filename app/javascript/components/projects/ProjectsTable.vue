<script>
import axios from 'axios'
import DateFormatMixinVue from '../../mixins/DateFormatMixin.vue'
import UpdateProjectDetailsModal from './UpdateProjectDetailsModal.vue'

export default {
  name: 'ProjectsTable',
  components: { UpdateProjectDetailsModal },
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
  data() {
    return {
      search: '',
      perPage: 10,
      currentPage: 1,
      truncated: {}, // store the truncated state for each project description
      filter: {
        discoverableToggled: this.is_vulcan_admin,
        myProjectsToggled: true,
        allToggled: this.is_vulcan_admin,
      },
      fields: [
        { key: 'name', sortable: true },
        { key: 'description', label: 'Description' },
        { key: 'memberships_count', label: 'Members', sortable: true },
        { key: 'updated_at', label: 'Last Updated', sortable: true },
        {
          key: 'actions',
          label: 'Actions',
          thClass: 'text-right',
          tdClass: 'p-0 text-right',
        },
      ],
      // Delete confirmation modal state
      showDeleteModal: false,
      projectToDelete: null,
      deleting: false,
    }
  },
  computed: {
    // Search projects based on name
    searchedProjects() {
      let projects = []
      if (this.filter.allToggled) {
        projects = this.projects
      }
      else if (this.filter.discoverableToggled) {
        projects = this.projects.filter(project => project.visibility === 'discoverable')
      }
      else if (this.filter.myProjectsToggled) {
        projects = this.projects.filter(project => project.is_member)
      }
      const downcaseSearch = this.search.toLowerCase()
      return projects.filter(project => project.name.toLowerCase().includes(downcaseSearch))
    },
    // Used by b-pagination to know how many total rows there are
    rows() {
      return this.searchedProjects.length
    },
    // Total number of user's projects
    projectCount() {
      return this.projects.length
    },
    // Total number of discoverable projects in the system
    discoverableProjectCount() {
      return this.projects.filter(project => project.visibility === 'discoverable').length
    },
  },
  watch: {
    'filter': {
      handler(_) {
        localStorage.setItem('projectTableFilters', JSON.stringify(this.filter))
      },
      deep: true,
    },
    'filter.allToggled': function (newValue, oldValue) {
      // Handle changes in individual field checkboxes
      if (newValue) {
        this.filter.discoverableToggled = true
        this.filter.myProjectsToggled = true
      }
    },
    'filter.discoverableToggled': function (newValue, oldValue) {
      // Handle changes in individual field checkboxes
      if (newValue && this.filter.myProjectsToggled) {
        this.filter.allToggled = true
      }
      else {
        this.filter.allToggled = false
      }
    },
    'filter.myProjectsToggled': function (newValue, oldValue) {
      // Handle changes in individual field checkboxes
      if (newValue && this.filter.discoverableToggled) {
        this.filter.allToggled = true
      }
      else {
        this.filter.allToggled = false
      }
    },
  },
  mounted() {
    // Persist `filters` across page loads
    if (localStorage.getItem('projectTableFilters')) {
      try {
        this.filter = JSON.parse(localStorage.getItem('projectTableFilters'))
      }
      catch (e) {
        localStorage.removeItem('projectTableFilters')
      }
    }
  },
  unmounted() {
    window.removeEventListener('scroll', this.handleScroll)
  },
  created() {
    this.projects.forEach((project) => {
      this.truncated[project.id] = true
    })
  },
  methods: {
    // Path to POST/DELETE to when updating/deleting a project
    formAction(project) {
      return `/projects/${project.id}`
    },
    // Path to the manage project members page
    manageProjectMembersAction(project) {
      return `/projects/${project.id}/project_members`
    },
    // Path to the project controls page
    projectControlsAction(project) {
      return `/projects/${project.id}/controls`
    },
    getProjectAction(project) {
      return `/projects/${project.id}`
    },
    destroyAction(project) {
      return `/projects/${project.id}`
    },
    // Path to POST/DELETE action to when requesting access to project or cancelling request
    requestAccessAction(project) {
      return `/projects/${project.id}/project_access_requests`
    },
    cancelAccessRequestAction(project) {
      return `/projects/${project.id}/project_access_requests/${project.access_request_id}`
    },
    getLabel(project, action) {
      if (action === 'remove project') {
        return `Are you sure you want to completely remove project ${project.name} and all of its related data?`
      }
      else {
        return `Are you sure you want to cancel your request to access project ${project.name}?`
      }
    },
    refreshProjects() {
      this.$emit('projectUpdated')
    },
    toggleTruncate(id) {
      this.truncated[id] = !this.truncated[id]
    },
    truncate(text, id) {
      if (this.truncated[id] && text && text.length > 75) {
        return text.substring(0, 75)
      }
      return text
    },
    // Show delete confirmation modal
    confirmDelete(project) {
      this.projectToDelete = project
      this.showDeleteModal = true
    },
    // Actually delete the project
    async deleteProject() {
      if (!this.projectToDelete) return
      this.deleting = true
      try {
        await axios.delete(`/projects/${this.projectToDelete.id}`)
        this.showDeleteModal = false
        this.projectToDelete = null
        this.refreshProjects()
      }
      catch (error) {
        console.error('Failed to delete project:', error)
        alert('Failed to delete project. Please try again.')
      }
      finally {
        this.deleting = false
      }
    },
    // Cancel delete
    cancelDelete() {
      this.showDeleteModal = false
      this.projectToDelete = null
    },
  },
}
</script>

<template>
  <div>
    <!-- Table information -->
    <p>
      <b>Project Count:</b> <b-badge variant="info">
        {{ projectCount }}
      </b-badge>
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
              <i class="bi bi-search" aria-hidden="true" />
            </div>
          </div>
          <input
            id="projectSearch"
            v-model="search"
            type="text"
            class="form-control"
            placeholder="Search projects by name..."
          >
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
          <i
            class="bi bi-info-circle"
            aria-hidden="true"
            data-bs-toggle="tooltip"
            data-bs-placement="top"
            title="Projects I am a member of"
          />
        </b-form-checkbox>
        <b-form-checkbox v-model="filter.discoverableToggled" size="lg" class="ml-3" switch>
          <small>Show Discoverable Projects</small>
          <i
            class="bi bi-info-circle"
            aria-hidden="true"
            data-bs-toggle="tooltip"
            data-bs-placement="top"
            title="Projects intended to be discovered and potentially collaborated upon by other users. Interested users can request access to the project"
          />
        </b-form-checkbox>
      </div>
    </div>

    <br>

    <!-- Projects table -->
    <b-table
      id="projects-table"
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
        <UpdateProjectDetailsModal
          v-if="is_vulcan_admin || data.item.admin"
          :project="data.item"
          :is_project_table="true"
          class="floatright"
          @project-updated="refreshProjects"
        />
        <span v-if="!data.item.is_member && !data.item.access_request_id">
          <b-button
            class="btn btn-info text-nowrap mx-2 my-3"
            data-method="post"
            :href="requestAccessAction(data.item)"
            rel="nofollow"
          >
            <i class="bi bi-person-plus" aria-hidden="true" />
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
            <i class="bi bi-x-circle" aria-hidden="true" />
            Cancel Access Request
          </b-button>
        </span>
        <span v-if="is_vulcan_admin">
          <b-button
            class="px-2 m-2"
            variant="danger"
            @click="confirmDelete(data.item)"
          >
            <i class="bi bi-trash" aria-hidden="true" />
            Remove
          </b-button>
        </span>
      </template>
    </b-table>

    <!-- Delete Confirmation Modal -->
    <b-modal
      v-model="showDeleteModal"
      title="Confirm Delete"
      size="md"
      @hidden="cancelDelete"
    >
      <p v-if="projectToDelete">
        Are you sure you want to completely remove project
        <strong>{{ projectToDelete.name }}</strong>
        and all of its related data?
      </p>
      <template #footer>
        <b-button variant="secondary" @click="cancelDelete">
          Cancel
        </b-button>
        <b-button
          variant="danger"
          :disabled="deleting"
          @click="deleteProject"
        >
          {{ deleting ? 'Deleting...' : 'Delete Project' }}
        </b-button>
      </template>
    </b-modal>

    <!-- Pagination controls -->
    <b-pagination
      v-model="currentPage"
      :total-rows="rows"
      :per-page="perPage"
      aria-controls="projects-table"
    />
  </div>
</template>

<style scoped>
.floatright {
  float: right;
}
</style>
