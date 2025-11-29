<script setup lang="ts">
/**
 * EditorToolbar - Sticky bottom action bar for requirement editor
 *
 * Actions:
 * - Primary: Save, Request Review
 * - Secondary: Lock/Unlock, Revert, Satisfies, Changelog
 * Note: Find/Replace moved to navigator (component-wide scope)
 */

import { computed, ref } from 'vue'
import type { IRule } from '@/types'

// Props
interface Props {
  rule: IRule | null
  isDirty: boolean
  isValid: boolean
  loading: boolean
  canEdit: boolean
  isLocked: boolean
  isUnderReview: boolean
  isMerged: boolean
  effectivePermissions: string
}

const props = defineProps<Props>()

// Emits
const emit = defineEmits<{
  (e: 'save'): void
  (e: 'requestReview'): void
  (e: 'lock'): void
  (e: 'unlock'): void
  (e: 'revert'): void
  (e: 'satisfies'): void
  (e: 'changelog'): void
}>()

// Computed permissions
const isAdmin = computed(() => props.effectivePermissions === 'admin')
const isReviewer = computed(() => props.effectivePermissions === 'reviewer')
const canReview = computed(() => isAdmin.value || isReviewer.value)

// Can request review: not locked, not under review, has rule
const canRequestReview = computed(() => {
  return props.rule && !props.isLocked && !props.isUnderReview && props.canEdit
})

// Can lock: admin, not under review, not already locked
const canLock = computed(() => {
  return props.rule && isAdmin.value && !props.isUnderReview && !props.isLocked
})

// Can unlock: admin, is locked
const canUnlock = computed(() => {
  return props.rule && isAdmin.value && props.isLocked
})

// Status message
const statusMessage = computed(() => {
  if (props.isLocked) return { icon: 'bi-lock-fill', text: 'Locked', class: 'text-muted' }
  if (props.isUnderReview) return { icon: 'bi-hourglass-split', text: 'Under Review', class: 'text-info' }
  if (props.isMerged) return { icon: 'bi-diagram-3', text: 'Merged', class: 'text-info' }
  if (props.isDirty && !props.isValid) return { icon: 'bi-exclamation-triangle', text: 'Fix errors', class: 'text-danger' }
  if (props.isDirty) return { icon: 'bi-exclamation-circle', text: 'Unsaved', class: 'text-warning' }
  return null
})
</script>

<template>
  <div class="editor-toolbar border-top bg-body-tertiary">
    <div class="d-flex align-items-center justify-content-between p-2 px-3">
      <!-- Left: Status -->
      <div class="d-flex align-items-center gap-2">
        <span v-if="statusMessage" :class="statusMessage.class" class="small">
          <i :class="'bi ' + statusMessage.icon" class="me-1"></i>
          {{ statusMessage.text }}
        </span>
        <span v-else-if="rule" class="text-success small">
          <i class="bi bi-check-circle me-1"></i>
          Saved
        </span>
      </div>

      <!-- Center: Secondary Actions -->
      <div class="d-flex align-items-center gap-1">
        <!-- Changelog -->
        <button
          class="btn btn-sm btn-outline-secondary"
          title="View changelog"
          :disabled="!rule"
          @click="emit('changelog')"
        >
          <i class="bi bi-clock-history"></i>
          <span class="d-none d-md-inline ms-1">History</span>
        </button>

        <!-- Satisfies -->
        <button
          class="btn btn-sm btn-outline-secondary"
          title="Manage satisfies relationships"
          :disabled="!rule"
          @click="emit('satisfies')"
        >
          <i class="bi bi-diagram-3"></i>
          <span class="d-none d-md-inline ms-1">Satisfies</span>
        </button>

        <!-- More dropdown -->
        <div class="dropdown">
          <button
            class="btn btn-sm btn-outline-secondary dropdown-toggle"
            type="button"
            data-bs-toggle="dropdown"
            aria-expanded="false"
            :disabled="!rule"
          >
            <i class="bi bi-three-dots"></i>
          </button>
          <ul class="dropdown-menu dropdown-menu-end">
            <!-- Revert -->
            <li>
              <button
                class="dropdown-item"
                :disabled="!canEdit"
                @click="emit('revert')"
              >
                <i class="bi bi-arrow-counterclockwise me-2"></i>
                Revert Changes
              </button>
            </li>
            <li><hr class="dropdown-divider"></li>
            <!-- Lock -->
            <li v-if="canLock">
              <button
                class="dropdown-item"
                @click="emit('lock')"
              >
                <i class="bi bi-lock me-2"></i>
                Lock Control
              </button>
            </li>
            <!-- Unlock -->
            <li v-if="canUnlock">
              <button
                class="dropdown-item"
                @click="emit('unlock')"
              >
                <i class="bi bi-unlock me-2"></i>
                Unlock Control
              </button>
            </li>
          </ul>
        </div>
      </div>

      <!-- Right: Primary Actions -->
      <div class="d-flex align-items-center gap-2">
        <!-- Request Review -->
        <button
          v-if="canRequestReview"
          class="btn btn-sm btn-outline-primary"
          @click="emit('requestReview')"
        >
          <i class="bi bi-send me-1"></i>
          Request Review
        </button>

        <!-- Save -->
        <button
          class="btn btn-sm btn-primary"
          :disabled="!canEdit || !isDirty || loading || !isValid"
          @click="emit('save')"
        >
          <span v-if="loading" class="spinner-border spinner-border-sm me-1"></span>
          <i v-else class="bi bi-check-lg me-1"></i>
          Save
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.editor-toolbar {
  flex-shrink: 0;
}

.dropdown-item:disabled {
  color: var(--bs-secondary);
  pointer-events: none;
}
</style>
