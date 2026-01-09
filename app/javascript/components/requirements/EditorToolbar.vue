<script setup lang="ts">
/**
 * EditorToolbar - Sticky bottom action bar for requirement editor
 *
 * Actions:
 * - Primary: Save, Request Review
 * - Secondary: Lock/Unlock, Revert, Satisfies, Changelog
 * Note: Find/Replace moved to navigator (component-wide scope)
 */

import type { IRule } from '@/types'
import { BDropdown, BDropdownDivider, BDropdownItem } from 'bootstrap-vue-next'
import { computed } from 'vue'

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
  if (props.isMerged) return { icon: 'bi-arrow-left', text: 'Satisfied', class: 'text-info' }
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
          <i :class="`bi ${statusMessage.icon}`" class="me-1" />
          {{ statusMessage.text }}
        </span>
        <span v-else-if="rule" class="text-success small">
          <i class="bi bi-check-circle me-1" />
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
          <i class="bi bi-clock-history" />
          <span class="d-none d-md-inline ms-1">History</span>
        </button>

        <!-- Satisfies -->
        <button
          class="btn btn-sm btn-outline-secondary"
          title="Manage satisfies relationships"
          :disabled="!rule"
          @click="emit('satisfies')"
        >
          <i class="bi bi-diagram-3" />
          <span class="d-none d-md-inline ms-1">Satisfies</span>
        </button>

        <!-- More dropdown -->
        <BDropdown
          size="sm"
          variant="outline-secondary"
          end
          :disabled="!rule"
        >
          <template #button-content>
            <i class="bi bi-three-dots" />
          </template>
          <!-- Revert -->
          <BDropdownItem
            :disabled="!canEdit"
            @click="emit('revert')"
          >
            <i class="bi bi-arrow-counterclockwise me-2" />
            Revert Changes
          </BDropdownItem>
          <BDropdownDivider />
          <!-- Lock -->
          <BDropdownItem
            v-if="canLock"
            @click="emit('lock')"
          >
            <i class="bi bi-lock me-2" />
            Lock Control
          </BDropdownItem>
          <!-- Unlock -->
          <BDropdownItem
            v-if="canUnlock"
            @click="emit('unlock')"
          >
            <i class="bi bi-unlock me-2" />
            Unlock Control
          </BDropdownItem>
        </BDropdown>
      </div>

      <!-- Right: Primary Actions -->
      <div class="d-flex align-items-center gap-2">
        <!-- Request Review -->
        <button
          v-if="canRequestReview"
          class="btn btn-sm btn-outline-primary"
          @click="emit('requestReview')"
        >
          <i class="bi bi-send me-1" />
          Request Review
        </button>

        <!-- Save -->
        <button
          class="btn btn-sm btn-primary"
          :disabled="!canEdit || !isDirty || loading || !isValid"
          @click="emit('save')"
        >
          <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
          <i v-else class="bi bi-check-lg me-1" />
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
