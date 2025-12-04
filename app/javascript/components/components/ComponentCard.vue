<script setup lang="ts">
/**
 * ComponentCard.vue
 * Displays a project component card with metrics, progress, and actions
 * Vue 3 Composition API + Bootstrap 5
 */
import { computed, ref } from 'vue'
import { formatDateTime, hasPermission, useAppToast } from '@/composables'
import { http } from '@/services/http.service'
import LockControlsModal from './LockControlsModal.vue'
import NewComponentModal from './NewComponentModal.vue'

// Types
interface RulesSummary {
  primary_count: number
  nested_count: number
  total: number
  locked: number
  under_review: number
  not_under_review: number
}

interface ComponentData {
  id: number
  name: string
  version?: string
  release?: string
  released: boolean
  releasable: boolean
  description?: string
  based_on_title: string
  based_on_version: string
  rules_summary?: RulesSummary
  admin_name?: string
  admin_email?: string
  created_at?: string
  project_id: number
  prefix: string
  security_requirements_guide_id: number
}

// Props
const props = withDefaults(defineProps<{
  component: ComponentData
  actionable?: boolean
  effectivePermissions?: string
}>(), {
  actionable: true,
})

// Emits
const emit = defineEmits<{
  deleteComponent: [componentId: number]
  projectUpdated: []
}>()

// Toast for notifications
const toast = useAppToast()

// State
const showDeleteConfirmation = ref(false)
const showReleaseConfirmation = ref(false)
const releasing = ref(false)

// Computed
const releaseComponentTooltip = computed(() => {
  if (props.component.released) {
    return 'Component has already been released'
  }
  if (props.component.releasable) {
    return 'Release Component'
  }
  return 'All rules must be locked to release a component'
})

const isReviewer = computed(() => hasPermission(props.effectivePermissions, 'reviewer'))
const isAdmin = computed(() => hasPermission(props.effectivePermissions, 'admin'))

// Progress bar calculations
const progressPercent = computed(() => {
  const summary = props.component.rules_summary
  if (!summary || summary.total === 0) return { locked: 0, review: 0, draft: 0 }
  return {
    locked: (summary.locked / summary.total) * 100,
    review: (summary.under_review / summary.total) * 100,
    draft: (summary.not_under_review / summary.total) * 100,
  }
})

// Methods
function downloadExport(type: string) {
  http.get(`/components/${props.component.id}/export/${type}`)
    .then(() => {
      // Once validated that there is content to download, open download window
      window.open(`/components/${props.component.id}/export/${type}`)
    })
    .catch((err) => {
      toast.fromError(err)
    })
}

function confirmComponentRelease() {
  if (!props.component.releasable) {
    return
  }
  showReleaseConfirmation.value = true
}

function releaseComponent() {
  releasing.value = true
  const payload = {
    component: {
      released: true,
    },
  }
  http.patch(`/components/${props.component.id}`, payload)
    .then((response) => {
      toast.fromResponse(response)
      showReleaseConfirmation.value = false
      emit('projectUpdated')
    })
    .catch((err) => {
      toast.fromError(err)
    })
    .finally(() => {
      releasing.value = false
    })
}

function handleDeleteConfirm() {
  emit('deleteComponent', props.component.id)
  showDeleteConfirmation.value = false
}
</script>

<template>
  <div class="m-3 position-relative">
    <!-- Delete Confirmation Overlay -->
    <div
      v-if="showDeleteConfirmation"
      class="position-absolute top-0 start-0 w-100 h-100 d-flex align-items-center justify-content-center bg-white"
      style="z-index: 10; opacity: 0.95;"
    >
      <div class="text-center">
        <p>Are you sure you want to remove this component from the project?</p>
        <button class="btn btn-outline-secondary me-2" @click="showDeleteConfirmation = false">
          Cancel
        </button>
        <button class="btn btn-danger" @click="handleDeleteConfirm">
          Remove
        </button>
      </div>
    </div>

    <!-- Release Confirmation Modal -->
    <div
      v-if="showReleaseConfirmation"
      class="modal fade show d-block"
      tabindex="-1"
      style="background-color: rgba(0,0,0,0.5);"
    >
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              Release Component
            </h5>
            <button
              type="button"
              class="btn-close"
              aria-label="Close"
              @click="showReleaseConfirmation = false"
            />
          </div>
          <div class="modal-body">
            <p>Are you sure you want to release this component?</p>
            <p>This cannot be undone and will make the component publicly available within Vulcan.</p>
          </div>
          <div class="modal-footer">
            <button
              type="button"
              class="btn btn-secondary"
              @click="showReleaseConfirmation = false"
            >
              Cancel
            </button>
            <button
              type="button"
              class="btn btn-success"
              :disabled="releasing"
              @click="releaseComponent"
            >
              {{ releasing ? 'Releasing...' : 'Release Component' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Card -->
    <div class="card shadow">
      <div class="card-body">
        <!-- Card Title -->
        <div class="d-flex justify-content-between align-items-start mb-2">
          <div>
            <span class="h5 mb-0">{{ component.name }}</span>
            <span v-if="component.version || component.release" class="text-muted ms-2">
              <small>
                <span v-if="component.version">v{{ component.version }}</span>
                <span v-if="component.release">r{{ component.release }}</span>
              </small>
            </span>
            <i
              v-if="component.released"
              class="bi bi-patch-check-fill text-success ms-2"
              data-bs-toggle="tooltip"
              title="Component Released"
            />
          </div>
        </div>

        <!-- Subtitle -->
        <h6 class="card-subtitle mb-2 text-muted">
          Based on {{ component.based_on_title }} {{ component.based_on_version }}
        </h6>
        <p v-if="component.description" class="card-subtitle text-muted my-2">
          {{ component.description }}
        </p>

        <!-- Metrics Section -->
        <div v-if="component.rules_summary" class="mt-3 mb-3">
          <table class="table table-sm table-borderless mb-0">
            <tbody>
              <tr>
                <td class="text-muted">
                  <i class="bi bi-folder me-2" />
                  Primary Controls
                </td>
                <td class="text-end">
                  <h4 class="mb-0 text-primary">
                    {{ component.rules_summary.primary_count }}
                  </h4>
                </td>
              </tr>
              <tr v-if="component.rules_summary.nested_count > 0">
                <td class="text-muted">
                  <i class="bi bi-arrow-return-right me-2" />
                  Inherited
                </td>
                <td class="text-end">
                  <h4 class="mb-0 text-secondary">
                    {{ component.rules_summary.nested_count }}
                  </h4>
                </td>
              </tr>
              <tr class="border-top">
                <td class="text-muted">
                  <i class="bi bi-shield-check me-2" />
                  <strong>Total Requirements</strong>
                </td>
                <td class="text-end">
                  <h4 class="mb-0">
                    {{ component.rules_summary.total }}
                  </h4>
                </td>
              </tr>
            </tbody>
          </table>

          <!-- Progress Bar -->
          <div class="mt-3">
            <small class="text-muted">Completion Progress:</small>
            <div class="progress mt-2" style="height: 1.5rem;">
              <div
                class="progress-bar bg-success"
                role="progressbar"
                :style="{ width: `${progressPercent.locked}%` }"
                :aria-valuenow="component.rules_summary.locked"
                :aria-valuemin="0"
                :aria-valuemax="component.rules_summary.total"
              >
                {{ component.rules_summary.locked }} Locked
              </div>
              <div
                v-if="component.rules_summary.under_review > 0"
                class="progress-bar bg-warning"
                role="progressbar"
                :style="{ width: `${progressPercent.review}%` }"
                :aria-valuenow="component.rules_summary.under_review"
                :aria-valuemin="0"
                :aria-valuemax="component.rules_summary.total"
              >
                {{ component.rules_summary.under_review }} Review
              </div>
              <div
                v-if="component.rules_summary.not_under_review > 0"
                class="progress-bar bg-info"
                role="progressbar"
                :style="{ width: `${progressPercent.draft}%` }"
                :aria-valuenow="component.rules_summary.not_under_review"
                :aria-valuemin="0"
                :aria-valuemax="component.rules_summary.total"
              >
                {{ component.rules_summary.not_under_review }} Draft
              </div>
            </div>
          </div>
        </div>

        <!-- PoC and Created Date -->
        <div class="mt-4">
          <p class="mb-1">
            <span v-if="component.admin_name">
              PoC: {{ component.admin_name }}
              {{ component.admin_email ? `(${component.admin_email})` : "" }}
            </span>
            <em v-else>No Component Admin</em>
          </p>
          <p v-if="component.created_at" class="text-muted mb-0">
            <small>
              <i class="bi bi-calendar-plus me-1" />
              Created {{ formatDateTime(component.created_at) }}
            </small>
          </p>
        </div>

        <!-- Component actions -->
        <div class="mt-3 pt-3 border-top">
          <!-- Primary Actions Row -->
          <div class="d-flex justify-content-between align-items-center">
            <div>
              <!-- Primary Action Button - Goes to Requirements Editor -->
              <a
                :href="`/components/${component.id}/controls`"
                class="btn btn-primary btn-sm me-2"
              >
                <i class="bi bi-pencil-square me-1" />
                Edit Requirements
              </a>
              <!-- Component Details Link -->
              <a
                :href="`/components/${component.id}`"
                class="btn btn-outline-secondary btn-sm me-2"
                title="View component details, settings, and metadata"
              >
                <i class="bi bi-info-circle me-1" />
                Details
              </a>

              <!-- Export Dropdown -->
              <div class="dropdown d-inline-block">
                <button
                  class="btn btn-outline-secondary btn-sm dropdown-toggle"
                  type="button"
                  data-bs-toggle="dropdown"
                  aria-expanded="false"
                >
                  Export
                </button>
                <ul class="dropdown-menu">
                  <li>
                    <button class="dropdown-item" @click="downloadExport('csv')">
                      <i class="bi bi-file-earmark-text me-2" />CSV
                    </button>
                  </li>
                  <li>
                    <button class="dropdown-item" @click="downloadExport('inspec')">
                      <i class="bi bi-shield-check me-2" />InSpec
                    </button>
                  </li>
                  <li>
                    <button class="dropdown-item" @click="downloadExport('xccdf')">
                      <i class="bi bi-file-earmark-code me-2" />XCCDF
                    </button>
                  </li>
                </ul>
              </div>
            </div>

            <!-- Admin Actions -->
            <div v-if="actionable && component.id" class="d-flex align-items-center">
              <!-- All action buttons in one group -->
              <div class="btn-toolbar">
                <LockControlsModal
                  v-if="isReviewer"
                  :component_id="component.id"
                  @project-updated="emit('projectUpdated')"
                >
                  <template #opener>
                    <button
                      class="btn btn-outline-warning btn-sm me-1"
                      data-bs-toggle="tooltip"
                      title="Lock all controls"
                    >
                      <i class="bi bi-lock" />
                    </button>
                  </template>
                </LockControlsModal>

                <NewComponentModal
                  v-if="isAdmin"
                  :component_to_duplicate="component.id"
                  :project_id="component.project_id"
                  :predetermined_prefix="component.prefix"
                  :predetermined_security_requirements_guide_id="component.security_requirements_guide_id"
                  @project-updated="emit('projectUpdated')"
                >
                  <template #opener>
                    <button
                      class="btn btn-outline-info btn-sm me-1"
                      data-bs-toggle="tooltip"
                      title="Duplicate component"
                    >
                      <i class="bi bi-files" />
                    </button>
                  </template>
                </NewComponentModal>

                <button
                  v-if="isAdmin && !component.released"
                  class="btn btn-outline-success btn-sm me-1"
                  :disabled="!component.releasable"
                  :title="releaseComponentTooltip"
                  data-bs-toggle="tooltip"
                  @click="confirmComponentRelease"
                >
                  <i class="bi bi-tag" />
                </button>

                <button
                  v-if="isAdmin"
                  class="btn btn-outline-danger btn-sm"
                  title="Remove from project"
                  data-bs-toggle="tooltip"
                  @click="showDeleteConfirmation = !showDeleteConfirmation"
                >
                  <i class="bi bi-trash" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.inspec-icon {
  background: url("data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4KPHN2ZyB3aWR0aD0iMzJweCIgaGVpZ2h0PSIzMnB4IiB2aWV3Qm94PSIwIDAgMzIgMzIiIHZlcnNpb249IjEuMSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KICA8dGl0bGU+QXJ0Ym9hcmQ8L3RpdGxlPgogIDxkZXNjPkNyZWF0ZWQgd2l0aCBTa2V0Y2guPC9kZXNjPgogIDxnIGlkPSJBcnRib2FyZCIgc3Ryb2tlPSJub25lIiBzdHJva2Utd2lkdGg9IjEiIGZpbGw9Im5vbmUiIGZpbGwtcnVsZT0iZXZlbm9kZCI+CiAgICA8ZyBpZD0iR3JvdXAtMyIgZmlsbD0iIzQ0OUJCQiI+CiAgICAgIDxwYXRoIGQ9Ik02LjQ5MjkyNzkzLDI4Ljg3MDQ0OTUgTDExLjg5MTQzODcsMjQuMDA5NjA4NyBDMTMuMTIzMTM2NSwyNC42NDI2ODU4IDE0LjUxOTg0MDcsMjUgMTYsMjUgQzIwLjk3MDU2MjcsMjUgMjUsMjAuOTcwNTYyNyAyNSwxNiBDMjUsMTEuMDI5NDM3MyAyMC45NzA1NjI3LDcgMTYsNyBDMTEuMDI5NDM3Myw3IDcsMTEuMDI5NDM3MyA3LDE2IEM3LDE3LjY2Njg0NzYgNy40NTMxMzIzMiwxOS4yMjc4NjA0IDguMjQyOTMyODYsMjAuNTY2NTc0NCBMMi45ODE2NDIzNywyNS4zMDM4NjE2IEMxLjEwNDcxMzgzLDIyLjY4MjI2MDIgMCwxOS40NzAxNCAwLDE2IEMwLDcuMTYzNDQ0IDcuMTYzNDQ0LDAgMTYsMCBDMjQuODM2NTU2LDAgMzIsNy4xNjM0NDQgMzIsMTYgQzMyLDI0LjgzNjU1NiAyNC44MzY1NTYsMzIgMTYsMzIgQzEyLjQzOTY2ODEsMzIgOS4xNTA5NDI1NCwzMC44MzcxMTUgNi40OTI5Mjc5MywyOC44NzA0NDk1IFoiIGlkPSJDb21iaW5lZC1TaGFwZSIgc3R5bGU9ImZpbGw6IHJnYmEoMCwgMCwgMCwgMC44KTsiLz4KICAgICAgPGNpcmNsZSBpZD0iT3ZhbCIgY3g9IjE2IiBjeT0iMTYiIHI9IjUuMjUiIHN0eWxlPSJmaWxsOiByZ2JhKDAsIDAsIDAsIDAuOCk7Ii8+CiAgICA8L2c+CiAgPC9nPgo8L3N2Zz4=");
  background-size: 100%;
  height: 1rem;
  width: 1rem;
  display: inline-block;
  vertical-align: middle;
}

.xccdf-icon {
  background: url("data:image/png;base64,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");
  background-size: 100%;
  height: 1rem;
  width: 1rem;
  display: inline-block;
  vertical-align: middle;
}
</style>
