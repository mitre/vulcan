<script setup lang="ts">
/**
 * Project Component
 * Displays project details, components, members, and history
 * Vue 3 Composition API + Bootstrap 5
 */

import { orderBy, sortBy, uniq } from 'lodash'
import { BTabs, BTab, BButton, BOffcanvas } from 'bootstrap-vue-next'
import { computed, onMounted, ref, watch } from 'vue'
import { formatDateTime, hasPermission, useAppToast, useProjects } from '@/composables'
import { http } from '@/services/http.service'
import axios from 'axios'

// Child components
import AddComponentModal from '../components/AddComponentModal.vue'
import ComponentCard from '../components/ComponentCard.vue'
import NewComponentModal from '../components/NewComponentModal.vue'
import MembershipsTable from '../memberships/MembershipsTable.vue'
import UpdateProjectDetailsModal from '../projects/UpdateProjectDetailsModal.vue'
import History from '../shared/History.vue'
import DiffViewer from './DiffViewer.vue'
import RevisionHistory from './RevisionHistory.vue'
import UpdateMetadataModal from './UpdateMetadataModal.vue'

// Props
const props = defineProps<{
  initialProjectState: any
  statuses: string[]
  severities: string[]
  availableRoles: string[]
  currentUserId?: number
  effectivePermissions?: string
}>()

// Emits (currently unused but may be needed for parent communication)
// const emit = defineEmits<{
//   (e: 'refresh'): void
// }>()

const toast = useAppToast()
const { fetchById, update } = useProjects()

// Reactive state - wrap plain object prop in ref
const project = ref(props.initialProjectState)
const visible = ref(props.initialProjectState?.visibility === 'discoverable')
const activeTab = ref(0)
const showDetails = ref(true)
const showMetadata = ref(true)
const showHistory = ref(true)

// Offcanvas state - separate for each section
const showDetailsOffcanvas = ref(false)
const showMetadataOffcanvas = ref(false)
const showHistoryOffcanvas = ref(false)
const showPendingRequestsOffcanvas = ref(false)
const showExportOffcanvas = ref(false)

// Export modal state
const showExportModal = ref(false)
const excelExportType = ref('')
const selectedComponentsToExport = ref<number[]>([])
const allComponentsSelected = ref(false)
const releasedComponentsSelected = ref(false)

// Visibility confirmation modal
const showVisibilityModal = ref(false)

// Computed
const isProjectAdmin = computed(() => hasPermission(props.effectivePermissions, 'admin'))
const isAuthor = computed(() => hasPermission(props.effectivePermissions, 'author'))

// Pending members - use user data directly from access_requests
const pendingMembers = computed(() => {
  if (!project.value?.access_requests) return []

  return project.value.access_requests.map((request: any) => ({
    id: request.user?.id || request.user_id,
    name: request.user?.name || 'Unknown User',
    email: request.user?.email || '',
    request_id: request.id,
    created_at: request.created_at,
  }))
})

// Get access request by ID
function getAccessRequestById(requestId: number) {
  return project.value?.access_requests?.find((request: any) => request.id === requestId)
}

// Accept access request - delegate to MembershipsTable component
const membershipsTableRef = ref<InstanceType<typeof MembershipsTable> | null>(null)

async function acceptRequest(member: any) {
  showPendingRequestsOffcanvas.value = false
  activeTab.value = 3

  await new Promise(resolve => setTimeout(resolve, 100))

  if (membershipsTableRef.value && typeof membershipsTableRef.value.acceptRequest === 'function') {
    membershipsTableRef.value.acceptRequest(member)
  }
  else {
    toast.info(`Click "Accept" on ${member.name}'s pending request to assign a role`)
  }
}

// Reject access request
async function rejectRequest(member: any) {
  if (!member.request_id) return

  try {
    await axios.delete(`/projects/${project.value.id}/project_access_requests/${member.request_id}`)
    toast.success(`${member.name}'s request has been rejected.`, 'Request Rejected')
    await refreshProject()
    showPendingRequestsOffcanvas.value = false
  }
  catch (error: any) {
    console.error('Failed to reject request:', error)
    toast.error(error.response?.data?.error || 'Failed to reject request. Please try again.')
  }
}

const sortedComponents = computed(() => {
  return orderBy(
    project.value?.components || [],
    [(c: any) => c.name.toLowerCase(), 'version', 'release'],
    ['asc'],
  )
})

const sortedRegularComponents = computed(() => {
  return sortedComponents.value.filter((c: any) => c.component_id == null)
})

const sortedOverlayComponents = computed(() => {
  return sortedComponents.value.filter((c: any) => c.component_id != null)
})

const sortedAvailableComponents = computed(() => {
  return sortBy(project.value?.available_components || [], ['child_project_name'])
})

const uniqueComponentNames = computed(() => {
  return uniq(sortedComponents.value.map((c: any) => c.name))
})

const lastAudit = computed(() => {
  return project.value?.histories?.[0] || null
})

const releasedComponentIds = computed(() => {
  return (project.value?.components || [])
    .filter((c: any) => c.released)
    .map((c: any) => c.id)
})

const exportComponentOptions = computed(() => {
  return sortedComponents.value.map((c: any) => {
    const versionRelease = c.version && c.release ? ` - V${c.version}R${c.release}` : ''
    return { label: `${c.name}${versionRelease}`, value: c.id }
  })
})

const detailsStats = computed(() => {
  const d = project.value?.details || {}
  const total = d.total || 1
  return [
    { label: 'Applicable - Configurable', value: d.ac, pct: ((d.ac / total) * 100).toFixed(2) },
    { label: 'Applicable - Inherently Meets', value: d.aim, pct: ((d.aim / total) * 100).toFixed(2) },
    { label: 'Applicable - Does Not Meet', value: d.adnm, pct: ((d.adnm / total) * 100).toFixed(2) },
    { label: 'Not Applicable', value: d.na, pct: ((d.na / total) * 100).toFixed(2) },
    { label: 'Not Yet Determined', value: d.nyd, pct: ((d.nyd / total) * 100).toFixed(2) },
    { label: 'Not Under Review', value: d.nur, pct: ((d.nur / total) * 100).toFixed(2) },
    { label: 'Under Review', value: d.ur, pct: ((d.ur / total) * 100).toFixed(2) },
    { label: 'Locked', value: d.lck, pct: ((d.lck / total) * 100).toFixed(2) },
  ]
})

// Persist tab selection
watch(activeTab, (val) => {
  localStorage.setItem(`projectTabIndex-${project.value?.id}`, JSON.stringify(val))
})

onMounted(() => {
  // Check URL hash first (takes priority over localStorage)
  const hash = window.location.hash.slice(1) // Remove the '#'
  if (hash === 'members') {
    activeTab.value = 3
    return
  }

  // Fall back to saved tab preference
  const saved = localStorage.getItem(`projectTabIndex-${project.value?.id}`)
  if (saved) {
    try {
      activeTab.value = JSON.parse(saved)
    }
    catch {
      localStorage.removeItem(`projectTabIndex-${project.value?.id}`)
    }
  }
})

// Methods
async function refreshProject() {
  try {
    const refreshed = await fetchById(project.value.id)
    if (refreshed) {
      project.value = refreshed
      visible.value = refreshed.visibility === 'discoverable'
    }
  }
  catch {
    toast.error('Failed to refresh project')
  }
}

async function updateVisibility() {
  try {
    await update(project.value.id, {
      visibility: visible.value ? 'discoverable' : 'hidden',
    })
    toast.success('Visibility updated')
    await refreshProject()
  }
  catch {
    toast.error('Failed to update visibility')
    visible.value = project.value.visibility === 'discoverable'
  }
  showVisibilityModal.value = false
}

async function deleteComponent(componentId: number) {
  try {
    await http.delete(`/components/${componentId}`)
    toast.success('Component removed')
    await refreshProject()
  }
  catch {
    toast.error('Failed to remove component')
  }
}

async function downloadExport(type: string) {
  try {
    const params = type === 'excel' || type === 'disa_excel'
      ? `?component_ids=${selectedComponentsToExport.value.join(',')}`
      : ''
    await http.get(`/projects/${project.value.id}/export/${type}${params}`)
    window.open(`/projects/${project.value.id}/export/${type}${params}`)

    if (type === 'excel' || type === 'disa_excel') {
      showExportModal.value = false
      excelExportType.value = ''
      selectedComponentsToExport.value = []
    }
  }
  catch {
    toast.error('Failed to export')
  }
}

function toggleAllComponents() {
  if (allComponentsSelected.value) {
    selectedComponentsToExport.value = (project.value?.components || []).map((c: any) => c.id)
  }
  else {
    selectedComponentsToExport.value = []
  }
}

function toggleReleasedComponents() {
  if (releasedComponentsSelected.value) {
    selectedComponentsToExport.value = releasedComponentIds.value
  }
  else {
    selectedComponentsToExport.value = []
  }
}

function openExportModal(type: string) {
  excelExportType.value = type
  showExportModal.value = true
}
</script>

<template>
  <div>
    <!-- Breadcrumb -->
    <nav aria-label="breadcrumb">
      <ol class="breadcrumb">
        <li class="breadcrumb-item">
          <a href="/projects">Projects</a>
        </li>
        <li class="breadcrumb-item active" aria-current="page">
          {{ project?.name }}
        </li>
      </ol>
    </nav>

    <!-- Action Bar -->
    <div class="mb-3 pb-3 border-bottom">
      <!-- Title Row -->
      <div class="d-flex justify-content-between align-items-center mb-2">
        <div class="d-flex align-items-center gap-2">
          <h1 class="mb-0 h2">{{ project?.name }}</h1>
          <span class="badge bg-info">{{ project?.visibility }}</span>
          <div v-if="isProjectAdmin" class="form-check form-switch ms-2">
            <input
              id="visibility-switch"
              v-model="visible"
              class="form-check-input"
              type="checkbox"
              @change="showVisibilityModal = true"
            >
            <label class="form-check-label" for="visibility-switch">
              <small>{{ visible ? 'Switch back to private' : 'Mark as discoverable' }}</small>
            </label>
          </div>
        </div>
        <div class="btn-group" role="group">
        <BButton variant="outline-secondary" size="sm" @click="showDetailsOffcanvas = true">
          <i class="bi bi-info-circle me-1" />
          Details
        </BButton>
        <BButton variant="outline-secondary" size="sm" @click="showMetadataOffcanvas = true">
          <i class="bi bi-tags me-1" />
          Metadata
        </BButton>
        <BButton variant="outline-secondary" size="sm" @click="showHistoryOffcanvas = true">
          <i class="bi bi-clock-history me-1" />
          History
        </BButton>
        <BButton v-if="isProjectAdmin" variant="primary" size="sm" @click="showExportOffcanvas = true">
          <i class="bi bi-download me-1" />
          Export
        </BButton>
      </div>
      </div>

      <!-- Metadata Row -->
      <div class="d-flex justify-content-end text-muted small">
        <div class="me-4">
          <span v-if="lastAudit?.created_at">Last update on {{ formatDateTime(lastAudit.created_at) }}</span>
        </div>
        <div>
          <span v-if="project?.admin_name">
            {{ project.admin_name }}
            {{ project.admin_email ? `(${project.admin_email})` : '' }}
          </span>
          <em v-else>No Project Admin</em>
        </div>
      </div>
    </div>

    <!-- Main content -->
    <div class="row">
      <!-- Main column - Full width tabs -->
      <div class="col-12">
        <BTabs v-model:index="activeTab" content-class="mt-3" nav-class="nav-justified" lazy>
          <!-- Components Tab -->
          <BTab lazy active>
            <template #title>
              Components <span class="badge bg-info ms-1">{{ project?.components?.length || 0 }}</span>
            </template>
            <h2>Project Components</h2>
            <div class="mb-3">
              <NewComponentModal
                v-if="isProjectAdmin"
                :project_id="project?.id"
                :project="project"
                @project-updated="refreshProject"
              />
              <NewComponentModal
                v-if="isProjectAdmin"
                :project_id="project?.id"
                :project="project"
                :spreadsheet_import="true"
                @project-updated="refreshProject"
              />
              <NewComponentModal
                v-if="isProjectAdmin"
                :project_id="project?.id"
                :project="project"
                :copy_component="true"
                @project-updated="refreshProject"
              />

              <!-- Download dropdown -->
              <div class="dropdown d-inline-block">
                <button
                  class="btn btn-secondary dropdown-toggle"
                  type="button"
                  data-bs-toggle="dropdown"
                >
                  Download
                </button>
                <ul class="dropdown-menu">
                  <li>
                    <button class="dropdown-item" @click="openExportModal('disa_excel')">
                      DISA Excel Export
                    </button>
                  </li>
                  <li>
                    <button class="dropdown-item" @click="openExportModal('excel')">
                      Excel Export
                    </button>
                  </li>
                  <li>
                    <button class="dropdown-item" @click="downloadExport('inspec')">
                      InSpec Profile
                    </button>
                  </li>
                  <li>
                    <button class="dropdown-item" @click="downloadExport('xccdf')">
                      XCCDF Export
                    </button>
                  </li>
                </ul>
              </div>
            </div>

            <!-- Empty State - No Components -->
            <div
              v-if="sortedComponents.length === 0"
              class="text-center py-5 my-4 bg-body-secondary rounded-3"
            >
              <i class="bi bi-box-seam display-1 text-body-secondary mb-3 d-block" />
              <h3 class="text-body-secondary">
                No Components Yet
              </h3>
              <p class="text-body-secondary mb-4">
                Get started by creating your first component for this project.
              </p>
              <NewComponentModal
                v-if="isProjectAdmin"
                :project_id="project?.id"
                :project="project"
                @project-updated="refreshProject"
              >
                <template #opener>
                  <button class="btn btn-primary btn-lg">
                    <i class="bi bi-plus-circle me-2" />
                    Create Your First Component
                  </button>
                </template>
              </NewComponentModal>
              <p v-if="!isProjectAdmin" class="text-body-secondary small mt-3">
                Contact a project administrator to add components.
              </p>
            </div>

            <!-- Regular Components -->
            <div v-else class="row row-cols-1 row-cols-lg-2">
              <div v-for="component in sortedRegularComponents" :key="component.id" class="col">
                <ComponentCard
                  :component="component"
                  :effective-permissions="effectivePermissions"
                  @delete-component="deleteComponent($event)"
                  @project-updated="refreshProject"
                />
              </div>
            </div>

            <!-- Overlay Components (only show when there are regular components) -->
            <template v-if="sortedComponents.length > 0">
              <h2 class="mt-4">
                Overlaid Components
              </h2>
              <AddComponentModal
                v-if="isProjectAdmin"
                :project_id="project?.id"
                :available_components="sortedAvailableComponents"
                @project-updated="refreshProject"
              />
              <div class="row row-cols-1 row-cols-lg-2">
                <div v-for="component in sortedOverlayComponents" :key="component.id" class="col">
                  <ComponentCard
                    :component="component"
                    :effective-permissions="effectivePermissions"
                    @delete-component="deleteComponent($event)"
                    @project-updated="refreshProject"
                  />
                </div>
              </div>
            </template>
          </BTab>

          <!-- Diff Viewer Tab -->
          <BTab lazy>
            <template #title>
              Diff Viewer
            </template>
            <DiffViewer :project="initialProjectState" />
          </BTab>

          <!-- Revision History Tab -->
          <BTab lazy>
            <template #title>
              Revision History
            </template>
            <RevisionHistory
              :project="initialProjectState"
              :unique-component-names="uniqueComponentNames"
            />
          </BTab>

          <!-- Members Tab -->
          <BTab lazy>
            <template #title>
              Members <span class="badge bg-info ms-1">{{ project?.memberships_count || 0 }}</span>
              <span
                v-if="isProjectAdmin && project?.access_requests?.length > 0"
                class="badge bg-danger ms-1 cursor-pointer"
                role="button"
                @click.stop="showPendingRequestsOffcanvas = true"
              >
                <i class="bi bi-exclamation-circle me-1" />
                {{ project.access_requests.length }} pending
              </span>
            </template>
            <MembershipsTable
              ref="membershipsTableRef"
              :editable="isProjectAdmin"
              membership_type="Project"
              :membership_id="project?.id"
              :memberships="project?.memberships"
              :memberships_count="project?.memberships_count"
              :available_members="project?.available_members"
              :available_roles="availableRoles"
              :access_requests="project?.access_requests"
            />
          </BTab>
        </BTabs>
      </div>
    </div>

    <!-- Project Details Offcanvas -->
    <BOffcanvas
      v-model="showDetailsOffcanvas"
      placement="end"
      title="Project Details"
    >
      <p class="mb-2">
        <strong>Name:</strong> {{ project?.name }}
      </p>
      <p v-if="project?.description" class="mb-2">
        <strong>Description:</strong> {{ project.description }}
      </p>
      <p v-for="stat in detailsStats" :key="stat.label" class="mb-2">
        <strong>{{ stat.label }}:</strong> {{ stat.value }} ({{ stat.pct }}%)
      </p>
      <p class="mb-3">
        <strong>Total:</strong> {{ project?.details?.total }}
      </p>
      <UpdateProjectDetailsModal
        v-if="isProjectAdmin"
        :project="project"
        @project-updated="refreshProject"
      />
    </BOffcanvas>

    <!-- Project Metadata Offcanvas -->
    <BOffcanvas
      v-model="showMetadataOffcanvas"
      placement="end"
      title="Project Metadata"
    >
      <small
        v-if="isProjectAdmin && (!project?.metadata || !project?.metadata['Slack Channel ID'])"
        class="text-muted mb-3 d-block"
      >
        Add a metadata with key `Slack Channel ID` for slack notifications.
      </small>
      <div v-for="(value, key) in project?.metadata" :key="key" class="mb-2">
        <strong>{{ key }}:</strong> {{ value }}
      </div>
      <div class="mt-3">
        <UpdateMetadataModal
          v-if="isAuthor"
          :project="project"
          @project-updated="refreshProject"
        />
      </div>
    </BOffcanvas>

    <!-- Project History Offcanvas -->
    <BOffcanvas
      v-model="showHistoryOffcanvas"
      placement="end"
      title="Project History"
    >
      <History :histories="project?.histories" :revertable="false" />
    </BOffcanvas>

    <!-- Pending Access Requests Offcanvas -->
    <BOffcanvas
      v-model="showPendingRequestsOffcanvas"
      placement="end"
      title="Pending Access Requests"
      body-class="pb-5"
    >
      <div v-if="pendingMembers.length === 0" class="text-muted text-center py-4">
        <i class="bi bi-inbox display-4 d-block mb-2" />
        No pending access requests
      </div>

      <div v-else class="list-group list-group-flush">
        <div
          v-for="member in pendingMembers"
          :key="member.request_id"
          class="list-group-item px-0"
        >
          <div class="d-flex justify-content-between align-items-start mb-2">
            <div>
              <strong class="d-block">{{ member.name }}</strong>
              <small class="text-muted d-block">{{ member.email }}</small>
              <small class="text-muted">
                <i class="bi bi-clock me-1" />
                Requested {{ formatDateTime(member.created_at) }}
              </small>
            </div>
          </div>
          <div class="d-flex gap-2 mt-2">
            <BButton
              variant="success"
              size="sm"
              @click="acceptRequest(member)"
            >
              <i class="bi bi-check-lg me-1" />
              Accept
            </BButton>
            <BButton
              variant="danger"
              size="sm"
              @click="rejectRequest(member)"
            >
              <i class="bi bi-x-lg me-1" />
              Reject
            </BButton>
          </div>
        </div>
      </div>
    </BOffcanvas>

    <!-- Export Offcanvas -->
    <BOffcanvas
      v-model="showExportOffcanvas"
      placement="end"
      title="Export Project"
    >
      <div class="mb-4">
        <h6>Quick Export</h6>
        <div class="d-grid gap-2">
          <BButton variant="outline-primary" @click="downloadExport('inspec')">
            <i class="bi bi-filetype-rb me-2" />
            InSpec Profile
          </BButton>
          <BButton variant="outline-primary" @click="downloadExport('xccdf')">
            <i class="bi bi-filetype-xml me-2" />
            XCCDF Export
          </BButton>
          <BButton variant="outline-primary" @click="openExportModal('excel')">
            <i class="bi bi-filetype-xlsx me-2" />
            Excel Export
          </BButton>
          <BButton variant="outline-primary" @click="openExportModal('disa_excel')">
            <i class="bi bi-filetype-xlsx me-2" />
            DISA Excel Export
          </BButton>
        </div>
      </div>
    </BOffcanvas>

    <!-- Visibility Confirmation Modal -->
    <div
      v-if="showVisibilityModal"
      class="modal fade show d-block"
      tabindex="-1"
      style="background: rgba(0,0,0,0.5)"
    >
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              Confirm Visibility Change
            </h5>
            <button
              type="button"
              class="btn-close"
              @click="showVisibilityModal = false; visible = project?.visibility === 'discoverable'"
            />
          </div>
          <div class="modal-body">
            Are you sure you want to change the visibility of this project to
            <mark>{{ visible ? 'discoverable' : 'hidden' }}</mark>?
          </div>
          <div class="modal-footer">
            <button
              type="button"
              class="btn btn-secondary"
              @click="showVisibilityModal = false; visible = project?.visibility === 'discoverable'"
            >
              Cancel
            </button>
            <button type="button" class="btn btn-primary" @click="updateVisibility">
              Confirm
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Excel Export Modal -->
    <div
      v-if="showExportModal"
      class="modal fade show d-block"
      tabindex="-1"
      style="background: rgba(0,0,0,0.5)"
    >
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              {{ excelExportType === 'excel' ? 'Excel Export' : 'DISA Excel Export' }}
            </h5>
            <button type="button" class="btn-close" @click="showExportModal = false" />
          </div>
          <div class="modal-body">
            <h5>Select components to export:</h5>
            <div class="form-check">
              <input
                id="select-all"
                v-model="allComponentsSelected"
                type="checkbox"
                class="form-check-input"
                @change="toggleAllComponents"
              >
              <label class="form-check-label" for="select-all">
                {{ allComponentsSelected ? 'Un-select All' : 'Select All' }}
              </label>
            </div>
            <div class="form-check">
              <input
                id="select-released"
                v-model="releasedComponentsSelected"
                type="checkbox"
                class="form-check-input"
                :disabled="releasedComponentIds.length === 0"
                @change="toggleReleasedComponents"
              >
              <label class="form-check-label" for="select-released">
                Select Released Components
              </label>
            </div>
            <hr>
            <div v-for="opt in exportComponentOptions" :key="opt.value" class="form-check">
              <input
                :id="`comp-${opt.value}`"
                v-model="selectedComponentsToExport"
                type="checkbox"
                class="form-check-input"
                :value="opt.value"
              >
              <label class="form-check-label" :for="`comp-${opt.value}`">
                {{ opt.label }}
              </label>
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" @click="showExportModal = false">
              Cancel
            </button>
            <button type="button" class="btn btn-primary" @click="downloadExport(excelExportType)">
              Export Selected Components
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.cursor-pointer {
  cursor: pointer;
}
</style>
