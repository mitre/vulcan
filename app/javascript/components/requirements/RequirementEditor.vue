<script setup lang="ts">
/**
 * RequirementEditor - Main editing area for Focus mode
 *
 * Uses the useRequirementEditor composable which provides:
 * - Dynamic field display based on status
 * - Validation
 * - Save/reset actions
 * - XOR logic for mitigations/POA&M
 *
 * This component is now a thin UI wrapper around the composable.
 */

import type { IRule } from '@/types'
import { computed, ref, toRef, watch } from 'vue'
import { useRequirementEditor, useRules } from '@/composables'
import ActionCommentModal from '../shared/ActionCommentModal.vue'
import ChangelogModal from './ChangelogModal.vue'
import EditorToolbar from './EditorToolbar.vue'
import FieldEditModal from './FieldEditModal.vue'
import SeverityBadge from './SeverityBadge.vue'
import StatusBadge from './StatusBadge.vue'

const props = defineProps<Props>()

// Emits
const emit = defineEmits<{
  (e: 'saved'): void
}>()

// Severity options
const SEVERITY_OPTIONS = [
  { value: 'high', label: 'CAT I (High)' },
  { value: 'medium', label: 'CAT II (Medium)' },
  { value: 'low', label: 'CAT III (Low)' },
  { value: 'unknown', label: 'Unknown' },
]

// Props
interface Props {
  rule: IRule | null
  effectivePermissions: string
  componentId?: number
  projectPrefix?: string
}

// Convert props to refs for the composable
const ruleRef = toRef(props, 'rule')
const permissionsRef = computed(() => props.effectivePermissions)

// Use the requirement editor composable - THE STABLE INTERFACE
const {
  // Field helpers
  showField,
  isDisabled,
  getTooltip,
  riskLevel,
  riskDescription,
  statuses: RULE_STATUSES,

  // Editor state
  editedRule,
  isDirty,
  isValid,
  validationErrors,

  // Permissions
  canEdit,
  isMerged,
  isLocked,
  isUnderReview,

  // DISA helpers
  disaDescription,
  editedDisaDescription,
  mitigationsAvailable,
  poamAvailable,
  toggleMitigations,
  togglePoam,

  // Actions
  save,
  markDirty,

  // Loading
  loading,
} = useRequirementEditor(ruleRef, permissionsRef)

// Rules composable for lock/unlock/revert/review
const { rules, lockRule, unlockRule, createReview, refreshRule } = useRules()

// Handle save with emit
async function handleSave() {
  const success = await save()
  if (success) {
    emit('saved')
  }
}

// Toolbar handlers - open action modal
function handleRequestReview() {
  pendingAction.value = 'review'
}

function handleLock() {
  pendingAction.value = 'lock'
}

function handleUnlock() {
  pendingAction.value = 'unlock'
}

// Action modal confirmation handler
async function handleActionConfirm(comment: string) {
  if (!props.rule || !pendingAction.value) return

  actionLoading.value = true
  let success = false

  try {
    switch (pendingAction.value) {
      case 'lock':
        success = await lockRule(props.rule.id, comment || 'Locked via editor')
        break
      case 'unlock':
        success = await unlockRule(props.rule.id, comment || 'Unlocked via editor')
        break
      case 'review':
        success = await createReview(props.rule.id, {
          action: 'request_review',
          comment: comment || undefined,
        })
        break
    }

    if (success) {
      await refreshRule(props.rule.id)
      pendingAction.value = null
    }
  }
  finally {
    actionLoading.value = false
  }
}

function handleActionCancel() {
  pendingAction.value = null
}

function handleRevert() {
  // Revert opens changelog modal for history selection
  showChangelogModal.value = true
}

function handleSatisfies() {
  // TODO: Implement Satisfactions modal with normalized "Satisfy" terminology
  // This will be the next feature after Find/Replace
  alert('Satisfactions feature coming soon! This will show which requirements this control satisfies and which satisfy it.')
}

function handleChangelog() {
  showChangelogModal.value = true
}

async function handleReverted() {
  // Refresh the rule data after a revert
  if (props.rule) {
    await refreshRule(props.rule.id)
  }
  showChangelogModal.value = false
}

// Accordion state
const openSections = ref<string[]>(['status'])

// Modal state for expanded field editing
const showVulnModal = ref(false)
const showCheckModal = ref(false)
const showFixModal = ref(false)
const showChangelogModal = ref(false)

// Action modal state (lock/unlock/review)
type ActionType = 'lock' | 'unlock' | 'review' | null
const pendingAction = ref<ActionType>(null)
const actionLoading = ref(false)

const actionModalConfig = computed(() => {
  switch (pendingAction.value) {
    case 'lock':
      return {
        title: 'Lock Control',
        message: 'Locking this control will prevent further edits until unlocked by an admin.',
        confirmText: 'Lock Control',
        confirmVariant: 'warning',
        commentLabel: 'Reason for locking',
        requireComment: false,
      }
    case 'unlock':
      return {
        title: 'Unlock Control',
        message: 'Unlocking this control will allow edits to be made.',
        confirmText: 'Unlock Control',
        confirmVariant: 'success',
        commentLabel: 'Reason for unlocking',
        requireComment: false,
      }
    case 'review':
      return {
        title: 'Request Review',
        message: 'Request a reviewer to check this control. Editing will be disabled until the review is complete.',
        confirmText: 'Request Review',
        confirmVariant: 'primary',
        commentLabel: 'Notes for reviewer',
        requireComment: false,
      }
    default:
      return {
        title: '',
        message: '',
        confirmText: 'Confirm',
        confirmVariant: 'primary',
        commentLabel: 'Comment',
        requireComment: false,
      }
  }
})

// Handle modal saves - update the edited value and mark dirty
function handleVulnSave(value: string) {
  editedDisaDescription.value.vuln_discussion = value
  markDirty()
}

function handleCheckSave(value: string) {
  // For now, update the first check. TODO: Support multiple checks
  if (props.rule?.checks?.length) {
    // This should update the local edited state
    markDirty()
  }
}

function handleFixSave(value: string) {
  editedRule.value.fixtext = value
  markDirty()
}

function toggleSection(section: string) {
  const idx = openSections.value.indexOf(section)
  if (idx >= 0) {
    openSections.value.splice(idx, 1)
  }
  else {
    openSections.value.push(section)
  }
}

function isOpen(section: string): boolean {
  return openSections.value.includes(section)
}

// Open relevant sections when status changes
watch(
  () => editedRule.value.status,
  (newStatus) => {
    if (!openSections.value.includes('status')) {
      openSections.value.push('status')
    }

    if (newStatus === 'Applicable - Configurable') {
      if (!openSections.value.includes('vuln')) openSections.value.push('vuln')
      if (!openSections.value.includes('check')) openSections.value.push('check')
      if (!openSections.value.includes('fix')) openSections.value.push('fix')
    }
    else if (newStatus === 'Applicable - Does Not Meet') {
      if (!openSections.value.includes('mitigation')) openSections.value.push('mitigation')
    }
  },
)
</script>

<template>
  <div class="requirement-editor h-100 d-flex flex-column overflow-hidden">
    <!-- No selection -->
    <div v-if="!rule" class="flex-grow-1 d-flex align-items-center justify-content-center text-muted">
      <div class="text-center">
        <i class="bi bi-file-text" style="font-size: 3rem" />
        <p class="mt-2">
          Select a requirement to edit
        </p>
      </div>
    </div>

    <!-- Editor -->
    <template v-else>
      <!-- Header -->
      <div class="editor-header p-3 border-bottom">
        <div class="d-flex align-items-start justify-content-between">
          <div>
            <h5 class="mb-1">
              <span class="font-monospace">{{ rule.rule_id }}</span>
              <i v-if="isLocked" class="bi bi-lock-fill text-muted ms-2" title="Locked" />
              <i v-if="isMerged" class="bi bi-diagram-3 text-info ms-2" title="Merged rule" />
            </h5>
            <p class="mb-0 text-muted small">
              {{ rule.version }}
            </p>
          </div>
          <div class="d-flex gap-2 align-items-center">
            <!-- Risk indicator -->
            <span
              v-if="riskLevel !== 'none' && riskLevel !== 'low'"
              class="badge"
              :class="{
                'bg-warning text-dark': riskLevel === 'medium',
                'bg-danger': riskLevel === 'high',
              }"
              :title="riskDescription"
            >
              <i class="bi bi-exclamation-triangle me-1" />
              {{ riskLevel === 'high' ? 'Review periodically' : 'Monitor' }}
            </span>
            <StatusBadge :status="rule.status" />
            <SeverityBadge v-if="showField('rule_severity')" :severity="rule.rule_severity" />
          </div>
        </div>
      </div>

      <!-- Sections (scrollable) -->
      <div class="editor-body flex-grow-1 overflow-auto" style="min-height: 0">
        <!-- Status & Core Fields Section -->
        <div class="accordion-section border-bottom">
          <div
            class="section-header d-flex align-items-center justify-content-between p-3 cursor-pointer"
            @click="toggleSection('status')"
          >
            <strong>
              <i class="bi bi-gear me-2" />
              Status & Classification
            </strong>
            <i :class="isOpen('status') ? 'bi bi-chevron-up' : 'bi bi-chevron-down'" />
          </div>
          <div v-if="isOpen('status')" class="section-body p-3">
            <div class="row g-3">
              <!-- Status (always shown) -->
              <div class="col-md-6">
                <label class="form-label">
                  Status
                  <i
                    v-if="getTooltip('status')"
                    class="bi bi-info-circle text-muted ms-1"
                    :title="getTooltip('status') || ''"
                  />
                </label>
                <select
                  v-model="editedRule.status"
                  class="form-select"
                  :disabled="!canEdit"
                  @change="markDirty"
                >
                  <option v-for="s in RULE_STATUSES" :key="s" :value="s">
                    {{ s }}
                  </option>
                </select>
              </div>

              <!-- Severity (Configurable only) -->
              <div v-if="showField('rule_severity')" class="col-md-6">
                <label class="form-label">
                  Severity
                  <i
                    v-if="getTooltip('rule_severity')"
                    class="bi bi-info-circle text-muted ms-1"
                    :title="getTooltip('rule_severity') || ''"
                  />
                </label>
                <select
                  v-model="editedRule.rule_severity"
                  class="form-select"
                  :disabled="isDisabled('rule_severity')"
                  @change="markDirty"
                >
                  <option v-for="opt in SEVERITY_OPTIONS" :key="opt.value" :value="opt.value">
                    {{ opt.label }}
                  </option>
                </select>
              </div>

              <!-- Title (Configurable, or readonly for others) -->
              <div v-if="showField('title')" class="col-12">
                <label class="form-label">
                  Title
                  <i
                    v-if="getTooltip('title')"
                    class="bi bi-info-circle text-muted ms-1"
                    :title="getTooltip('title') || ''"
                  />
                </label>
                <textarea
                  v-model="editedRule.title"
                  class="form-control"
                  rows="2"
                  :disabled="isDisabled('title')"
                  @input="markDirty"
                />
              </div>

              <!-- Status Justification -->
              <div v-if="showField('status_justification')" class="col-12">
                <label class="form-label">
                  Status Justification
                  <span class="text-danger">*</span>
                  <i
                    v-if="getTooltip('status_justification')"
                    class="bi bi-info-circle text-muted ms-1"
                    :title="getTooltip('status_justification') || ''"
                  />
                </label>
                <textarea
                  v-model="editedRule.status_justification"
                  class="form-control"
                  :class="{ 'is-invalid': validationErrors.some(e => e.field === 'status_justification') }"
                  rows="3"
                  :disabled="isDisabled('status_justification')"
                  placeholder="Explain why this status was selected..."
                  @input="markDirty"
                />
                <div
                  v-if="validationErrors.some(e => e.field === 'status_justification')"
                  class="invalid-feedback"
                >
                  {{ validationErrors.find(e => e.field === 'status_justification')?.message }}
                </div>
              </div>

              <!-- Artifact Description -->
              <div v-if="showField('artifact_description')" class="col-12">
                <label class="form-label">
                  Artifact Description
                  <i
                    v-if="getTooltip('artifact_description')"
                    class="bi bi-info-circle text-muted ms-1"
                    :title="getTooltip('artifact_description') || ''"
                  />
                </label>
                <textarea
                  v-model="editedRule.artifact_description"
                  class="form-control"
                  :class="{ 'is-invalid': validationErrors.some(e => e.field === 'artifact_description') }"
                  rows="3"
                  :disabled="isDisabled('artifact_description')"
                  placeholder="Provide evidence (code files, documentation, screenshots)..."
                  @input="markDirty"
                />
                <div
                  v-if="validationErrors.some(e => e.field === 'artifact_description')"
                  class="invalid-feedback"
                >
                  {{ validationErrors.find(e => e.field === 'artifact_description')?.message }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Vulnerability Discussion -->
        <div v-if="showField('vuln_discussion', 'disa')" class="accordion-section border-bottom">
          <div
            class="section-header d-flex align-items-center justify-content-between p-3 cursor-pointer"
            @click="toggleSection('vuln')"
          >
            <strong>
              <i class="bi bi-shield-exclamation me-2" />
              Vulnerability Discussion
            </strong>
            <div class="d-flex align-items-center gap-2">
              <button
                class="btn btn-sm btn-outline-secondary"
                title="Expand to full editor"
                @click.stop="showVulnModal = true"
              >
                <i class="bi bi-arrows-fullscreen" />
              </button>
              <i :class="isOpen('vuln') ? 'bi bi-chevron-up' : 'bi bi-chevron-down'" />
            </div>
          </div>
          <div v-if="isOpen('vuln')" class="section-body p-3">
            <p class="text-muted small mb-2">
              <i class="bi bi-info-circle me-1" />
              {{ getTooltip('vuln_discussion') || 'Discuss, in detail, the rationale for this control\'s vulnerability' }}
            </p>
            <textarea
              v-model="editedDisaDescription.vuln_discussion"
              class="form-control"
              rows="6"
              :disabled="isDisabled('vuln_discussion', 'disa')"
              placeholder="Describe the vulnerability and its impact..."
              @input="markDirty"
            />
          </div>
        </div>

        <!-- Check Text -->
        <div v-if="showField('content', 'check')" class="accordion-section border-bottom">
          <div
            class="section-header d-flex align-items-center justify-content-between p-3 cursor-pointer"
            @click="toggleSection('check')"
          >
            <strong>
              <i class="bi bi-check2-square me-2" />
              Check Text
            </strong>
            <div class="d-flex align-items-center gap-2">
              <button
                class="btn btn-sm btn-outline-secondary"
                title="Expand to full editor"
                @click.stop="showCheckModal = true"
              >
                <i class="bi bi-arrows-fullscreen" />
              </button>
              <i :class="isOpen('check') ? 'bi bi-chevron-up' : 'bi bi-chevron-down'" />
            </div>
          </div>
          <div v-if="isOpen('check')" class="section-body p-3">
            <p class="text-muted small mb-2">
              <i class="bi bi-info-circle me-1" />
              The check/test script to validate compliance
            </p>
            <div v-if="rule.checks?.length">
              <div v-for="(check, idx) in rule.checks" :key="idx" class="mb-2">
                <textarea
                  :value="check.content"
                  class="form-control font-monospace small"
                  rows="6"
                  :disabled="isDisabled('content', 'check')"
                  placeholder="Enter check text..."
                  @input="markDirty"
                />
              </div>
            </div>
            <div v-else>
              <textarea
                class="form-control font-monospace small"
                rows="6"
                :disabled="isDisabled('content', 'check')"
                placeholder="Enter check text..."
                @input="markDirty"
              />
            </div>
          </div>
        </div>

        <!-- Fix Text -->
        <div v-if="showField('fixtext')" class="accordion-section border-bottom">
          <div
            class="section-header d-flex align-items-center justify-content-between p-3 cursor-pointer"
            @click="toggleSection('fix')"
          >
            <strong>
              <i class="bi bi-wrench me-2" />
              Fix Text
            </strong>
            <div class="d-flex align-items-center gap-2">
              <button
                class="btn btn-sm btn-outline-secondary"
                title="Expand to full editor"
                @click.stop="showFixModal = true"
              >
                <i class="bi bi-arrows-fullscreen" />
              </button>
              <i :class="isOpen('fix') ? 'bi bi-chevron-up' : 'bi bi-chevron-down'" />
            </div>
          </div>
          <div v-if="isOpen('fix')" class="section-body p-3">
            <p class="text-muted small mb-2">
              <i class="bi bi-info-circle me-1" />
              {{ getTooltip('fixtext') }}
            </p>
            <textarea
              v-model="editedRule.fixtext"
              class="form-control"
              rows="6"
              :disabled="isDisabled('fixtext')"
              placeholder="Describe how to remediate..."
              @input="markDirty"
            />
          </div>
        </div>

        <!-- Mitigations / POA&M -->
        <div v-if="showField('mitigations_available', 'disa')" class="accordion-section border-bottom">
          <div
            class="section-header d-flex align-items-center justify-content-between p-3 cursor-pointer"
            @click="toggleSection('mitigation')"
          >
            <strong>
              <i class="bi bi-shield-check me-2" />
              Mitigations & POA&M
            </strong>
            <i :class="isOpen('mitigation') ? 'bi bi-chevron-up' : 'bi bi-chevron-down'" />
          </div>
          <div v-if="isOpen('mitigation')" class="section-body p-3">
            <div
              class="alert small mb-3"
              :class="validationErrors.some(e => e.field === 'mitigations') ? 'alert-warning' : 'alert-info'"
            >
              <i class="bi bi-info-circle me-1" />
              Select either Mitigations OR POA&M (not both)
              <span v-if="validationErrors.some(e => e.field === 'mitigations')" class="fw-bold">
                - {{ validationErrors.find(e => e.field === 'mitigations')?.message }}
              </span>
            </div>

            <!-- Mitigations Toggle -->
            <div class="form-check form-switch mb-3">
              <input
                id="mitigationsToggle"
                class="form-check-input"
                type="checkbox"
                :checked="mitigationsAvailable"
                :disabled="!canEdit"
                @change="toggleMitigations(($event.target as HTMLInputElement).checked)"
              >
              <label class="form-check-label" for="mitigationsToggle">
                Mitigations Available
              </label>
            </div>

            <!-- Mitigations Text -->
            <div v-if="mitigationsAvailable" class="mb-4">
              <label class="form-label">
                Mitigations
                <i
                  v-if="getTooltip('mitigations')"
                  class="bi bi-info-circle text-muted ms-1"
                  :title="getTooltip('mitigations') || ''"
                />
              </label>
              <textarea
                v-model="editedDisaDescription.mitigations"
                class="form-control"
                rows="4"
                :disabled="!canEdit"
                placeholder="Describe how the system mitigates this vulnerability..."
                @input="markDirty"
              />
            </div>

            <!-- POA&M Toggle -->
            <div v-if="!mitigationsAvailable" class="form-check form-switch mb-3">
              <input
                id="poamToggle"
                class="form-check-input"
                type="checkbox"
                :checked="poamAvailable"
                :disabled="!canEdit"
                @change="togglePoam(($event.target as HTMLInputElement).checked)"
              >
              <label class="form-check-label" for="poamToggle">
                POA&M Available
              </label>
            </div>

            <!-- POA&M Text -->
            <div v-if="poamAvailable && !mitigationsAvailable">
              <label class="form-label">
                Plan of Action & Milestones
                <i
                  v-if="getTooltip('poam')"
                  class="bi bi-info-circle text-muted ms-1"
                  :title="getTooltip('poam') || ''"
                />
              </label>
              <textarea
                v-model="editedDisaDescription.poam"
                class="form-control"
                rows="4"
                :disabled="!canEdit"
                placeholder="Describe the POA&M action, including start and end dates..."
                @input="markDirty"
              />
            </div>
          </div>
        </div>

        <!-- Vendor Comments -->
        <div v-if="showField('vendor_comments')" class="accordion-section border-bottom">
          <div
            class="section-header d-flex align-items-center justify-content-between p-3 cursor-pointer"
            @click="toggleSection('vendor')"
          >
            <strong>
              <i class="bi bi-chat-left-text me-2" />
              Vendor Comments
            </strong>
            <span class="badge bg-secondary small">Internal</span>
            <i :class="isOpen('vendor') ? 'bi bi-chevron-up' : 'bi bi-chevron-down'" class="ms-auto" />
          </div>
          <div v-if="isOpen('vendor')" class="section-body p-3">
            <p class="text-muted small mb-2">
              <i class="bi bi-eye-slash me-1" />
              Internal notes - not published in final STIG
            </p>
            <textarea
              v-model="editedRule.vendor_comments"
              class="form-control"
              rows="3"
              :disabled="isDisabled('vendor_comments')"
              placeholder="Optional internal comments..."
              @input="markDirty"
            />
          </div>
        </div>

        <!-- TODO: Add more sections -->
        <!-- - SRG Reference (modal/slide-out) -->
        <!-- - Related/Merged requirements (right sidebar) -->
        <!-- - Reviews & History (right sidebar) -->
      </div>

      <!-- Toolbar / Command bar -->
      <EditorToolbar
        :rule="rule"
        :is-dirty="isDirty"
        :is-valid="isValid"
        :loading="loading"
        :can-edit="canEdit"
        :is-locked="isLocked"
        :is-under-review="isUnderReview"
        :is-merged="isMerged"
        :effective-permissions="effectivePermissions"
        @save="handleSave"
        @request-review="handleRequestReview"
        @lock="handleLock"
        @unlock="handleUnlock"
        @revert="handleRevert"
        @satisfies="handleSatisfies"
        @changelog="handleChangelog"
      />
    </template>

    <!-- Field Edit Modals -->
    <FieldEditModal
      v-model="showVulnModal"
      title="Vulnerability Discussion"
      field-name="vuln_discussion"
      :value="editedDisaDescription.vuln_discussion || ''"
      placeholder="Describe the vulnerability and its impact..."
      help-text="Discuss, in detail, the rationale for this control's vulnerability"
      :disabled="!canEdit"
      @save="handleVulnSave"
    />

    <FieldEditModal
      v-model="showCheckModal"
      title="Check Text"
      field-name="check_content"
      :value="rule?.checks?.[0]?.content || ''"
      placeholder="Enter check/test script..."
      help-text="The check/test script to validate compliance"
      :disabled="!canEdit"
      @save="handleCheckSave"
    />

    <FieldEditModal
      v-model="showFixModal"
      title="Fix Text"
      field-name="fixtext"
      :value="editedRule.fixtext || ''"
      placeholder="Describe how to remediate..."
      help-text="Provide detailed remediation steps"
      :disabled="!canEdit"
      @save="handleFixSave"
    />

    <!-- Changelog/History Modal -->
    <ChangelogModal
      v-model="showChangelogModal"
      :rule="rule"
      @reverted="handleReverted"
    />

    <!-- Action Comment Modal (Lock/Unlock/Review) -->
    <ActionCommentModal
      :model-value="pendingAction !== null"
      :title="actionModalConfig.title"
      :message="actionModalConfig.message"
      :confirm-text="actionModalConfig.confirmText"
      :confirm-variant="actionModalConfig.confirmVariant"
      :comment-label="actionModalConfig.commentLabel"
      :require-comment="actionModalConfig.requireComment"
      :loading="actionLoading"
      @update:model-value="!$event && handleActionCancel()"
      @confirm="handleActionConfirm"
      @cancel="handleActionCancel"
    />
  </div>
</template>

<style scoped>
.cursor-pointer {
  cursor: pointer;
}

/* Use CSS variables for dark mode compatibility */
.editor-header {
  background-color: var(--bs-tertiary-bg);
}

.section-header {
  background-color: var(--bs-secondary-bg);
}

.section-header:hover {
  background-color: var(--bs-tertiary-bg);
}

pre {
  white-space: pre-wrap;
  word-wrap: break-word;
}

.form-check-input:checked {
  background-color: var(--bs-primary);
  border-color: var(--bs-primary);
}
</style>
