<script setup lang="ts">
/**
 * Project Component
 * Displays project details, components, members, and history
 * Vue 3 Composition API + Bootstrap 5
 */

import { orderBy, sortBy, uniq } from 'lodash'
import { computed, onMounted, ref, watch } from 'vue'
import { updateProject } from '@/apis/projects.api'
import { formatDateTime, hasPermission, useAppToast } from '@/composables'
import { http } from '@/services/http.service'

// Child components (still Vue 2 compat for now)
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

// Reactive state
const project = ref<any>(props.initialProjectState)
const visible = ref(props.initialProjectState?.visibility === 'discoverable')
const activeTab = ref(0)
const showDetails = ref(true)
const showMetadata = ref(true)
const showHistory = ref(true)

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
    const response = await http.get(`/projects/${project.value.id}`)
    project.value = response.data
    visible.value = project.value.visibility === 'discoverable'
  }
  catch {
    toast.error('Failed to refresh project')
  }
}

async function updateVisibility() {
  try {
    await updateProject(project.value.id, {
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

    <!-- Header -->
    <div class="row align-items-center mb-3">
      <div class="col-md-8">
        <div class="d-flex align-items-center gap-2">
          <h1 class="mb-0">
            {{ project?.name }}
          </h1>
          <span class="badge bg-info">{{ project?.visibility }}</span>
          <div v-if="isProjectAdmin" class="form-check form-switch ms-3">
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
      </div>
      <div class="col-md-4 text-muted text-end">
        <p v-if="lastAudit" class="mb-1">
          <span v-if="lastAudit.created_at">Last update on {{ formatDateTime(lastAudit.created_at) }}</span>
          <span v-if="lastAudit.user_id"> by {{ lastAudit.user_id }}</span>
        </p>
        <p class="mb-1">
          <span v-if="project?.admin_name">
            {{ project.admin_name }}
            {{ project.admin_email ? `(${project.admin_email})` : '' }}
          </span>
          <em v-else>No Project Admin</em>
        </p>
      </div>
    </div>

    <!-- Main content -->
    <div class="row">
      <!-- Left column - Tabs -->
      <div class="col-md-10 border-end">
        <ul class="nav nav-tabs nav-justified" role="tablist">
          <li class="nav-item">
            <button
              class="nav-link" :class="[{ active: activeTab === 0 }]"
              @click="activeTab = 0"
            >
              Components ({{ project?.components?.length || 0 }})
            </button>
          </li>
          <li class="nav-item">
            <button
              class="nav-link" :class="[{ active: activeTab === 1 }]"
              @click="activeTab = 1"
            >
              Diff Viewer
            </button>
          </li>
          <li class="nav-item">
            <button
              class="nav-link" :class="[{ active: activeTab === 2 }]"
              @click="activeTab = 2"
            >
              Revision History
            </button>
          </li>
          <li class="nav-item">
            <button
              class="nav-link" :class="[{ active: activeTab === 3 }]"
              @click="activeTab = 3"
            >
              Members ({{ project?.memberships_count || 0 }})
              <span
                v-if="isProjectAdmin && project?.access_requests?.length > 0"
                class="badge bg-info ms-1"
              >
                pending
              </span>
            </button>
          </li>
        </ul>

        <div class="tab-content mt-3">
          <!-- Components Tab -->
          <div v-show="activeTab === 0" class="tab-pane active">
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
          </div>

          <!-- Diff Viewer Tab -->
          <div v-show="activeTab === 1" class="tab-pane">
            <DiffViewer :project="initialProjectState" />
          </div>

          <!-- Revision History Tab -->
          <div v-show="activeTab === 2" class="tab-pane">
            <RevisionHistory
              :project="initialProjectState"
              :unique-component-names="uniqueComponentNames"
            />
          </div>

          <!-- Members Tab -->
          <div v-show="activeTab === 3" class="tab-pane">
            <MembershipsTable
              :editable="isProjectAdmin"
              membership_type="Project"
              :membership_id="project?.id"
              :memberships="project?.memberships"
              :memberships_count="project?.memberships_count"
              :available_members="project?.available_members"
              :available_roles="availableRoles"
              :access_requests="project?.access_requests"
            />
          </div>
        </div>
      </div>

      <!-- Right column - Details sidebar -->
      <div class="col-md-2">
        <!-- Project Details -->
        <div class="mb-4">
          <div
            class="d-flex align-items-center cursor-pointer"
            @click="showDetails = !showDetails"
          >
            <h5 class="m-0">
              Project Details
            </h5>
            <i class="bi ms-2" :class="[showDetails ? 'bi-chevron-down' : 'bi-chevron-up']" />
          </div>
          <div v-show="showDetails" class="mt-2">
            <p class="mb-1">
              <strong>Name:</strong> {{ project?.name }}
            </p>
            <p v-if="project?.description" class="mb-1">
              <strong>Description:</strong> {{ project.description }}
            </p>
            <p v-for="stat in detailsStats" :key="stat.label" class="mb-1">
              <strong>{{ stat.label }}:</strong> {{ stat.value }} ({{ stat.pct }}%)
            </p>
            <p class="mb-1">
              <strong>Total:</strong> {{ project?.details?.total }}
            </p>
            <UpdateProjectDetailsModal
              v-if="isProjectAdmin"
              :project="project"
              @project-updated="refreshProject"
            />
          </div>
        </div>

        <!-- Project Metadata -->
        <div class="mb-4">
          <div
            class="d-flex align-items-center cursor-pointer"
            @click="showMetadata = !showMetadata"
          >
            <h5 class="m-0">
              Project Metadata
            </h5>
            <i class="bi ms-2" :class="[showMetadata ? 'bi-chevron-down' : 'bi-chevron-up']" />
          </div>
          <div v-show="showMetadata" class="mt-2">
            <small
              v-if="isProjectAdmin && (!project?.metadata || !project?.metadata['Slack Channel ID'])"
              class="text-muted"
            >
              Add a metadata with key `Slack Channel ID` for slack notifications.
            </small>
            <div v-for="(value, key) in project?.metadata" :key="key">
              <p class="mb-1">
                <strong>{{ key }}:</strong> {{ value }}
              </p>
            </div>
            <UpdateMetadataModal
              v-if="isAuthor"
              :project="project"
              @project-updated="refreshProject"
            />
          </div>
        </div>

        <!-- Project History -->
        <div>
          <div
            class="d-flex align-items-center cursor-pointer"
            @click="showHistory = !showHistory"
          >
            <h5 class="m-0">
              Project History
            </h5>
            <i class="bi ms-2" :class="[showHistory ? 'bi-chevron-down' : 'bi-chevron-up']" />
          </div>
          <div v-show="showHistory" class="mt-2">
            <History :histories="project?.histories" :revertable="false" />
          </div>
        </div>
      </div>
    </div>

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
