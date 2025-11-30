<script setup lang="ts">
/**
 * ChangelogModal - Rule history viewer with revert functionality
 *
 * Features:
 * - Grouped history entries by user/time
 * - Expandable changes view
 * - Field selection for revert
 * - Comment input for revert reason
 */

import type { IHistory, IRule } from '@/types'
import { BCollapse, BModal } from 'bootstrap-vue-next'
import { computed, ref, watch } from 'vue'
import { useRules } from '@/composables/useRules'

// Props
interface Props {
  modelValue: boolean
  rule: IRule | null
}

const props = defineProps<Props>()

// Emits
const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'reverted'): void
}>()

const { revertRule } = useRules()

// State
const expandedId = ref<number | null>(null)
const selectedFields = ref<string[]>([])
const revertComment = ref('')
const reverting = ref(false)
const showRevertPanel = ref(false)
const selectedHistory = ref<IHistory | null>(null)

// Group histories by user + time (within 1 minute)
interface IHistoryGroup {
  id: string
  primary: IHistory
  histories: IHistory[]
}

const groupedHistories = computed<IHistoryGroup[]>(() => {
  if (!props.rule?.histories) return []

  const grouped: Record<string, IHistoryGroup> = {}

  // Sort histories newest first
  const sorted = [...props.rule.histories].sort(
    (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
  )

  sorted.forEach((history) => {
    const date = new Date(history.created_at)
    date.setSeconds(0)
    date.setMilliseconds(0)
    const key = `${history.name}-${date.toISOString()}-${history.comment || ''}`

    if (!grouped[key]) {
      grouped[key] = {
        id: key,
        primary: history,
        histories: [],
      }
    }
    grouped[key].histories.push(history)
  })

  return Object.values(grouped)
})

// Format date for display
function formatDate(dateStr: string): string {
  const date = new Date(dateStr)
  return date.toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  })
}

// Humanize field names
function humanizeField(field: string): string {
  return field
    .replace(/_/g, ' ')
    .replace(/\b\w/g, c => c.toUpperCase())
}

// Humanize auditable type
function humanizeType(type: string): string {
  const typeMap: Record<string, string> = {
    Rule: 'Control',
    RuleDescription: 'Description',
    DisaRuleDescription: 'DISA Description',
    Check: 'Check',
    AdditionalAnswer: 'Additional Answer',
  }
  return typeMap[type] || type
}

// Get action badge class
function getActionClass(action: string): string {
  switch (action) {
    case 'create':
      return 'bg-success'
    case 'update':
      return 'bg-info'
    case 'destroy':
      return 'bg-danger'
    default:
      return 'bg-secondary'
  }
}

// Toggle expand
function toggleExpand(historyId: number) {
  expandedId.value = expandedId.value === historyId ? null : historyId
}

// Start revert process
function startRevert(history: IHistory) {
  selectedHistory.value = history
  selectedFields.value = []
  revertComment.value = ''
  showRevertPanel.value = true
}

// Toggle field selection
function toggleField(field: string) {
  const idx = selectedFields.value.indexOf(field)
  if (idx === -1) {
    selectedFields.value.push(field)
  }
  else {
    selectedFields.value.splice(idx, 1)
  }
}

// Select all fields
function selectAllFields() {
  if (!selectedHistory.value) return
  selectedFields.value = selectedHistory.value.audited_changes.map(c => c.field)
}

// Clear field selection
function clearFieldSelection() {
  selectedFields.value = []
}

// Cancel revert
function cancelRevert() {
  showRevertPanel.value = false
  selectedHistory.value = null
  selectedFields.value = []
  revertComment.value = ''
}

// Submit revert
async function submitRevert() {
  if (!props.rule || !selectedHistory.value || selectedFields.value.length === 0) return

  reverting.value = true
  const success = await revertRule(
    props.rule.id,
    selectedHistory.value.id,
    selectedFields.value,
    revertComment.value || undefined,
  )

  reverting.value = false
  if (success) {
    cancelRevert()
    emit('reverted')
  }
}

// Reset state when modal opens
watch(
  () => props.modelValue,
  (isOpen) => {
    if (isOpen) {
      expandedId.value = null
      cancelRevert()
    }
  },
)

// Truncate long values
function truncateValue(value: unknown, maxLen = 100): string {
  if (value === null || value === undefined) return '(empty)'
  const str = typeof value === 'object' ? JSON.stringify(value) : String(value)
  if (str.length > maxLen) return `${str.slice(0, maxLen)}...`
  return str
}
</script>

<template>
  <BModal
    :model-value="modelValue"
    title="Change History"
    size="xl"
    scrollable
    centered
    @update:model-value="emit('update:modelValue', $event)"
  >
    <div v-if="!rule?.histories?.length" class="text-center text-muted py-4">
      <i class="bi bi-clock-history fs-1 d-block mb-2" />
      No history available for this control.
    </div>

    <!-- Revert Panel -->
    <div v-else-if="showRevertPanel && selectedHistory" class="revert-panel">
      <div class="d-flex align-items-center justify-content-between mb-3">
        <h5 class="mb-0">
          <i class="bi bi-arrow-counterclockwise me-2" />
          Revert Changes
        </h5>
        <button class="btn btn-sm btn-outline-secondary" @click="cancelRevert">
          <i class="bi bi-x-lg" />
        </button>
      </div>

      <!-- Selected history info -->
      <div class="alert alert-info small mb-3">
        <strong>{{ selectedHistory.name }}</strong>
        <span class="text-muted ms-2">{{ formatDate(selectedHistory.created_at) }}</span>
        <p v-if="selectedHistory.comment" class="mb-0 mt-1">
          <em>"{{ selectedHistory.comment }}"</em>
        </p>
      </div>

      <!-- Field selection -->
      <div class="mb-3">
        <div class="d-flex justify-content-between align-items-center mb-2">
          <label class="form-label mb-0">Select fields to revert:</label>
          <div class="btn-group btn-group-sm">
            <button class="btn btn-outline-secondary" @click="selectAllFields">
              Select All
            </button>
            <button class="btn btn-outline-secondary" @click="clearFieldSelection">
              Clear
            </button>
          </div>
        </div>

        <div class="list-group">
          <label
            v-for="change in selectedHistory.audited_changes"
            :key="change.field"
            class="list-group-item list-group-item-action d-flex align-items-start gap-2"
            :class="{ active: selectedFields.includes(change.field) }"
          >
            <input
              type="checkbox"
              class="form-check-input mt-1"
              :checked="selectedFields.includes(change.field)"
              @change="toggleField(change.field)"
            >
            <div class="flex-grow-1">
              <div class="fw-medium">{{ humanizeField(change.field) }}</div>
              <div class="small">
                <span class="text-danger">{{ truncateValue(change.new_value, 50) }}</span>
                <i class="bi bi-arrow-right mx-1" />
                <span class="text-success">{{ truncateValue(change.prev_value, 50) }}</span>
              </div>
            </div>
          </label>
        </div>
      </div>

      <!-- Comment -->
      <div class="mb-3">
        <label class="form-label">Reason for revert (optional):</label>
        <textarea
          v-model="revertComment"
          class="form-control"
          rows="2"
          placeholder="Enter a reason for this revert..."
        />
      </div>

      <!-- Revert button -->
      <div class="d-flex justify-content-end gap-2">
        <button class="btn btn-secondary" @click="cancelRevert">
          Cancel
        </button>
        <button
          class="btn btn-warning"
          :disabled="selectedFields.length === 0 || reverting"
          @click="submitRevert"
        >
          <span v-if="reverting" class="spinner-border spinner-border-sm me-1" />
          <i v-else class="bi bi-arrow-counterclockwise me-1" />
          Revert {{ selectedFields.length }} Field{{ selectedFields.length !== 1 ? 's' : '' }}
        </button>
      </div>
    </div>

    <!-- History list -->
    <div v-else class="history-list">
      <div
        v-for="group in groupedHistories"
        :key="group.id"
        class="history-group mb-3"
      >
        <!-- Group header -->
        <div class="d-flex align-items-center gap-2 mb-1">
          <strong>{{ group.primary.name || 'Unknown' }}</strong>
          <small class="text-muted">{{ formatDate(group.primary.created_at) }}</small>
        </div>

        <p v-if="group.primary.comment" class="text-muted small mb-2 ms-3">
          <em>"{{ group.primary.comment }}"</em>
        </p>

        <!-- Individual histories in group -->
        <div
          v-for="history in group.histories"
          :key="history.id"
          class="history-item ms-3 mb-2"
        >
          <div
            class="d-flex align-items-center gap-2 clickable"
            @click="toggleExpand(history.id)"
          >
            <span class="badge" :class="getActionClass(history.action)">
              {{ history.action }}
            </span>
            <span>{{ humanizeType(history.auditable_type) }}</span>
            <span v-if="history.audited_name" class="text-muted">
              ({{ history.audited_name }})
            </span>
            <i
              class="bi ms-auto"
              :class="expandedId === history.id ? 'bi-chevron-up' : 'bi-chevron-down'"
            />
          </div>

          <!-- Expanded changes -->
          <BCollapse :visible="expandedId === history.id">
            <div class="changes-panel mt-2 p-2 bg-body-secondary rounded">
              <div
                v-for="change in history.audited_changes"
                :key="change.field"
                class="change-item mb-2"
              >
                <div class="fw-medium small">
                  {{ humanizeField(change.field) }}
                </div>
                <div class="d-flex gap-2 small">
                  <div v-if="history.action !== 'create'" class="flex-fill">
                    <span class="text-muted">From:</span>
                    <pre class="mb-0 bg-body p-1 rounded text-wrap">{{ truncateValue(change.prev_value, 200) }}</pre>
                  </div>
                  <div class="flex-fill">
                    <span class="text-muted">To:</span>
                    <pre class="mb-0 bg-body p-1 rounded text-wrap">{{ truncateValue(change.new_value, 200) }}</pre>
                  </div>
                </div>
              </div>

              <!-- Revert button for update actions -->
              <button
                v-if="history.action === 'update'"
                class="btn btn-sm btn-outline-warning mt-2"
                @click.stop="startRevert(history)"
              >
                <i class="bi bi-arrow-counterclockwise me-1" />
                Revert This Change
              </button>
            </div>
          </BCollapse>
        </div>
      </div>
    </div>

    <template #footer>
      <button class="btn btn-secondary" @click="emit('update:modelValue', false)">
        Close
      </button>
    </template>
  </BModal>
</template>

<style scoped>
.history-list {
  max-height: 60vh;
  overflow-y: auto;
}

.history-item .clickable {
  cursor: pointer;
}

.history-item .clickable:hover {
  background-color: var(--bs-tertiary-bg);
  border-radius: 0.25rem;
  padding: 0.25rem;
  margin: -0.25rem;
}

.changes-panel pre {
  font-size: 0.75rem;
  white-space: pre-wrap;
  word-break: break-word;
}

.revert-panel .list-group-item.active {
  background-color: var(--bs-warning-bg-subtle);
  border-color: var(--bs-warning-border-subtle);
  color: var(--bs-body-color);
}

.revert-panel .list-group-item.active .form-check-input {
  background-color: var(--bs-warning);
  border-color: var(--bs-warning);
}
</style>
