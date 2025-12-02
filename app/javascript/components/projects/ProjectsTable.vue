<script setup lang="ts">
/**
 * ProjectsTable.vue
 *
 * Displays a table of projects with search, filter toggles, pagination, and row actions.
 * Uses BaseTable for consistent table UI.
 */
import type { IProject } from '@/types'
import axios from 'axios'
import { BFormCheckbox } from 'bootstrap-vue-next'
import { computed, onMounted, reactive, watch } from 'vue'
import ActionMenu from '@/components/shared/ActionMenu.vue'
import BaseTable from '@/components/shared/BaseTable.vue'
import DeleteModal from '@/components/shared/DeleteModal.vue'
import { formatDateTime, useAppToast, useBaseTable, useConfirmModal, useDeleteConfirmation } from '@/composables'
import UpdateProjectDetailsModal from './UpdateProjectDetailsModal.vue'

const props = defineProps<{
  projects: IProject[]
  is_vulcan_admin: boolean
}>()

const emit = defineEmits<{
  projectUpdated: []
}>()

// Toast notifications
const toast = useAppToast()

// Confirmation modal
const { confirm } = useConfirmModal()

// Filter state with localStorage persistence
const filter = reactive({
  allToggled: props.is_vulcan_admin,
  myProjectsToggled: true,
  discoverableToggled: props.is_vulcan_admin,
})

// Apply filters to get base items for table
const filteredByToggle = computed(() => {
  if (filter.allToggled) {
    return props.projects
  }
  else if (filter.discoverableToggled && !filter.myProjectsToggled) {
    return props.projects.filter(p => p.visibility === 'discoverable')
  }
  else if (filter.myProjectsToggled && !filter.discoverableToggled) {
    return props.projects.filter(p => p.is_member)
  }
  else if (filter.myProjectsToggled && filter.discoverableToggled) {
    return props.projects
  }
  return []
})

// Use composable for search/pagination on filtered items
const { search, currentPage, paginatedItems, totalRows } = useBaseTable({
  items: filteredByToggle,
  searchFields: ['name'] as (keyof IProject)[],
})

// Delete confirmation with composable
const {
  showModal: showDeleteModal,
  itemToDelete: projectToDelete,
  isDeleting: deleting,
  confirmDelete,
  executeDelete,
} = useDeleteConfirmation<IProject>({
  onDelete: async (project) => {
    await axios.delete(`/projects/${project.id}`)
    emit('projectUpdated')
  },
  onError: () => {
    toast.error('Failed to delete project. Please try again.')
  },
})

// Text truncation state
const truncated = reactive<Record<number, boolean>>({})

// Column definitions
const columns = [
  { key: 'name', label: 'Name', sortable: true },
  { key: 'description', label: 'Description' },
  { key: 'memberships_count', label: 'Members', sortable: true },
  { key: 'updated_at', label: 'Last Updated', sortable: true },
  { key: 'actions', label: '', thClass: 'text-end', tdClass: 'text-end' },
]

// Counts
const projectCount = computed(() => props.projects.length)
const discoverableProjectCount = computed(() =>
  props.projects.filter(p => p.visibility === 'discoverable').length,
)

// Initialize truncation state
onMounted(() => {
  props.projects.forEach((project) => {
    truncated[project.id] = true
  })

  // Load filter state from localStorage
  const stored = localStorage.getItem('projectTableFilters')
  if (stored) {
    try {
      const parsed = JSON.parse(stored)
      if (typeof parsed.allToggled === 'boolean') filter.allToggled = parsed.allToggled
      if (typeof parsed.myProjectsToggled === 'boolean') filter.myProjectsToggled = parsed.myProjectsToggled
      if (typeof parsed.discoverableToggled === 'boolean') filter.discoverableToggled = parsed.discoverableToggled
    }
    catch {
      localStorage.removeItem('projectTableFilters')
    }
  }
})

// Persist filter state and handle toggle logic
watch(
  () => filter.allToggled,
  (newValue) => {
    if (newValue) {
      filter.discoverableToggled = true
      filter.myProjectsToggled = true
    }
    saveFilters()
  },
)

watch(
  () => filter.discoverableToggled,
  (newValue) => {
    if (newValue && filter.myProjectsToggled) {
      filter.allToggled = true
    }
    else {
      filter.allToggled = false
    }
    saveFilters()
  },
)

watch(
  () => filter.myProjectsToggled,
  (newValue) => {
    if (newValue && filter.discoverableToggled) {
      filter.allToggled = true
    }
    else {
      filter.allToggled = false
    }
    saveFilters()
  },
)

function saveFilters() {
  localStorage.setItem('projectTableFilters', JSON.stringify({
    allToggled: filter.allToggled,
    myProjectsToggled: filter.myProjectsToggled,
    discoverableToggled: filter.discoverableToggled,
  }))
}

/**
 * Truncate text with expand/collapse
 */
function truncateText(text: string | undefined, id: number) {
  if (!text) return ''
  if (truncated[id] && text.length > 75) {
    return text.substring(0, 75)
  }
  return text
}

function toggleTruncate(id: number) {
  truncated[id] = !truncated[id]
}

/**
 * Get actions for a project row
 */
function getActions(project: IProject) {
  const actions = []

  // View is always available for members
  if (project.is_member) {
    actions.push({ id: 'view', label: 'View Project', icon: 'bi-eye' })
  }

  // Request access for non-members without pending request
  if (!project.is_member && !project.access_request_id) {
    actions.push({ id: 'request-access', label: 'Request Access', icon: 'bi-person-plus' })
  }

  // Cancel request for pending requests
  if (project.access_request_id) {
    actions.push({ id: 'cancel-request', label: 'Cancel Request', icon: 'bi-x-circle', variant: 'danger' as const })
  }

  // Delete for admins
  if (props.is_vulcan_admin) {
    actions.push({ id: 'delete', label: 'Remove Project', icon: 'bi-trash', variant: 'danger' as const, dividerBefore: actions.length > 0 })
  }

  return actions
}

/**
 * Handle action menu selection
 */
function handleAction(actionId: string, project: IProject) {
  switch (actionId) {
    case 'view':
      window.location.href = `/projects/${project.id}`
      break
    case 'request-access':
      requestAccess(project)
      break
    case 'cancel-request':
      cancelAccessRequest(project)
      break
    case 'delete':
      confirmDelete(project)
      break
  }
}

/**
 * Request access to a project
 */
async function requestAccess(project: IProject) {
  try {
    await axios.post(`/projects/${project.id}/project_access_requests`)
    emit('projectUpdated')
  }
  catch (error) {
    console.error('Failed to request access:', error)
    toast.error('Failed to request access. Please try again.')
  }
}

/**
 * Cancel access request
 */
async function cancelAccessRequest(project: IProject) {
  if (!project.access_request_id) return

  const confirmed = await confirm(
    `Are you sure you want to cancel your request to access project ${project.name}?`,
    'Cancel Access Request',
  )
  if (!confirmed) return

  try {
    await axios.delete(`/projects/${project.id}/project_access_requests/${project.access_request_id}`)
    emit('projectUpdated')
  }
  catch (error) {
    console.error('Failed to cancel request:', error)
    toast.error('Failed to cancel request. Please try again.')
  }
}

/**
 * Refresh projects after modal update
 */
function refreshProjects() {
  emit('projectUpdated')
}
</script>

<template>
  <div>
    <!-- Table information -->
    <p class="mb-2">
      <strong>Project Count:</strong>
      <span class="badge bg-info ms-1">{{ projectCount }}</span>
    </p>
    <small v-if="projectCount > 0" class="text-info d-block mb-3">
      {{ discoverableProjectCount }} Discoverable Project{{ discoverableProjectCount !== 1 ? 's' : '' }}
    </small>

    <BaseTable
      :items="paginatedItems"
      :columns="columns"
      :total-rows="totalRows"
      :current-page="currentPage"
      :search="search"
      search-placeholder="Search projects by name..."
      @update:search="search = $event"
      @update:current-page="currentPage = $event"
    >
      <!-- Custom filters slot -->
      <template #filters>
        <div class="d-flex flex-wrap gap-3 mb-3">
          <BFormCheckbox
            v-model="filter.allToggled"
            :disabled="filter.allToggled"
            switch
          >
            <small>All Projects</small>
          </BFormCheckbox>
          <BFormCheckbox v-model="filter.myProjectsToggled" switch>
            <small>Show My Projects</small>
            <i
              class="bi bi-info-circle ms-1"
              aria-hidden="true"
              data-bs-toggle="tooltip"
              data-bs-placement="top"
              title="Projects I am a member of"
            />
          </BFormCheckbox>
          <BFormCheckbox v-model="filter.discoverableToggled" switch>
            <small>Show Discoverable Projects</small>
            <i
              class="bi bi-info-circle ms-1"
              aria-hidden="true"
              data-bs-toggle="tooltip"
              data-bs-placement="top"
              title="Projects intended to be discovered and potentially collaborated upon by other users. Interested users can request access to the project"
            />
          </BFormCheckbox>
        </div>
      </template>

      <!-- Name column -->
      <template #cell-name="{ item }">
        <a v-if="item.is_member" :href="`/projects/${item.id}`">
          {{ item.name }}
        </a>
        <span v-else>{{ item.name }}</span>
      </template>

      <!-- Description column with truncation -->
      <template #cell-description="{ item }">
        {{ truncateText(item.description, item.id) }}
        <a
          v-if="item.description && item.description.length > 75"
          href="#"
          class="text-primary"
          @click.prevent="toggleTruncate(item.id)"
        >
          {{ truncated[item.id] ? '...' : 'read less' }}
        </a>
      </template>

      <!-- Updated at column -->
      <template #cell-updated_at="{ item }">
        {{ formatDateTime(item.updated_at) }}
      </template>

      <!-- Actions column -->
      <template #cell-actions="{ item }">
        <div class="d-flex justify-content-end align-items-center gap-2">
          <!-- Edit modal for admins -->
          <UpdateProjectDetailsModal
            v-if="is_vulcan_admin || item.admin"
            :project="item"
            :is_project_table="true"
            @project-updated="refreshProjects"
          />

          <!-- Action menu -->
          <ActionMenu
            :actions="getActions(item)"
            @action="handleAction($event, item)"
          />
        </div>
      </template>
    </BaseTable>

    <!-- Delete Confirmation Modal -->
    <DeleteModal
      v-model="showDeleteModal"
      title="Confirm Delete"
      :item-name="projectToDelete?.name"
      :loading="deleting"
      danger-text="This will delete all components and data associated with this project."
      confirm-button-text="Delete Project"
      @confirm="executeDelete"
    />
  </div>
</template>
