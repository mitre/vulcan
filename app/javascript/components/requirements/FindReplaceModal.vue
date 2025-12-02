<script setup lang="ts">
/**
 * Find & Replace Modal
 * Provides UI for finding and replacing text across rule fields
 *
 * Uses the Pinia store for state management:
 * - Store handles navigation (currentIndex, nextMatch, prevMatch)
 * - Store handles all API calls
 * - Composable provides toast feedback
 */
import type { FlatMatch } from '@/composables/useFindReplace'
import { onKeyStroke } from '@vueuse/core'
import { BButton, BCard, BFormCheckbox, BFormGroup, BFormInput, BModal } from 'bootstrap-vue-next'
import { computed, nextTick, ref, toRef, watch } from 'vue'
import ActionCommentModal from '@/components/shared/ActionCommentModal.vue'
import { FIELD_LABELS, FIND_REPLACE_FIELDS, useFindReplace } from '@/composables/useFindReplace'
import { getKeySymbol, isInputFocused, isPrimaryModifier } from '@/composables/useKeyboardShortcuts'

interface Props {
  modelValue: boolean
  componentId: number
  projectPrefix: string
  readOnly?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  readOnly: false,
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
  (e: 'replaced'): void
}>()

// Use the composable (thin wrapper around store with toast integration)
const {
  // State
  searchText,
  replaceText,
  caseSensitive,
  selectedFields,
  matches,
  currentIndex,
  totalMatches,
  isLoading,

  // Computed
  currentMatch,
  hasNext,
  hasPrev,
  progress,
  summary,
  canUndo,
  hasResults,

  // Navigation actions
  nextMatch,
  prevMatch,
  firstMatch,
  lastMatch,
  goToMatch,

  // State management
  reset,

  // Toast-wrapped actions
  executeSearch,
  executeReplaceOne,
  executeReplaceAll,
  executeUndo,
} = useFindReplace()

// Mode toggle - Find only vs Find & Replace (default to Find only - safer)
const replaceMode = ref(false)
const showConfirmModal = ref(false)

// "Select All" checkbox state
const allFieldsSelected = ref(true)
const indeterminate = ref(false)

// Watch for changes in selected fields to update "Select All" state
watch(
  selectedFields,
  (newValue) => {
    if (newValue.length === 0) {
      indeterminate.value = false
      allFieldsSelected.value = false
    }
    else if (newValue.length === FIND_REPLACE_FIELDS.length) {
      indeterminate.value = false
      allFieldsSelected.value = true
    }
    else {
      indeterminate.value = true
      allFieldsSelected.value = false
    }
  },
  { immediate: true },
)

// Toggle all fields on/off
function toggleAllFields(checked: boolean) {
  selectedFields.value = checked ? [...FIND_REPLACE_FIELDS] : []
}

// Execute find
async function handleFind() {
  if (!searchText.value || searchText.value.trim().length < 2) return
  await executeSearch(props.componentId)
  // Move focus out of input so keyboard nav works immediately
  if (hasResults.value) {
    ;(document.activeElement as HTMLElement)?.blur()
  }
}

// Reference to search input for focus management
const searchInputRef = ref<HTMLInputElement | null>(null)

// Clear search and refocus input
function handleClear() {
  searchText.value = ''
  reset()
  // Return focus to search input
  nextTick(() => {
    searchInputRef.value?.focus()
  })
}

// Focus search input helper
function focusSearchInput() {
  nextTick(() => {
    searchInputRef.value?.focus()
  })
}

// Replace current match
async function handleReplaceOne() {
  await executeReplaceOne(props.componentId)
  emit('replaced')
}

// Replace all matches
async function handleReplaceAll(comment: string) {
  await executeReplaceAll(props.componentId, comment)
  emit('replaced')
  showConfirmModal.value = false
}

// Undo last replacement
async function handleUndo() {
  await executeUndo(props.componentId)
  emit('replaced')
}

// Format rule ID with project prefix
function formatRuleId(ruleIdentifier: string): string {
  return `${props.projectPrefix}-${ruleIdentifier}`
}

// Get field label
function getFieldLabel(field: string): string {
  return FIELD_LABELS[field] || field
}

// Group matches by rule for display (but use flat navigation)
const groupedMatches = computed(() => {
  const groups = new Map<number, { ruleIdentifier: string, matches: FlatMatch[] }>()

  for (const match of matches.value) {
    if (!groups.has(match.ruleId)) {
      groups.set(match.ruleId, {
        ruleIdentifier: match.ruleIdentifier,
        matches: [],
      })
    }
    groups.get(match.ruleId)!.matches.push(match)
  }

  return Array.from(groups.entries())
})

// Check if a match is the current one
function isCurrentMatch(match: FlatMatch): boolean {
  if (!currentMatch.value) return false
  return (
    match.ruleId === currentMatch.value.ruleId
    && match.field === currentMatch.value.field
    && match.index === currentMatch.value.index
  )
}

// Navigate to a specific match
function navigateToMatch(match: FlatMatch) {
  const idx = matches.value.findIndex(
    m => m.ruleId === match.ruleId && m.field === match.field && m.index === match.index,
  )
  if (idx !== -1) {
    goToMatch(idx)
    scrollToCurrentMatch()
  }
}

// Scroll to current match in the results list
function scrollToCurrentMatch() {
  requestAnimationFrame(() => {
    const matchElement = document.querySelector('.match-current')
    if (matchElement) {
      matchElement.scrollIntoView({ behavior: 'smooth', block: 'center' })
    }
  })
}

// Modal visibility handlers
function handleShow() {
  reset()
  // Initialize selectedFields with all fields if empty (so UI matches store state)
  if (selectedFields.value.length === 0) {
    selectedFields.value = [...FIND_REPLACE_FIELDS]
  }
}

function handleHidden() {
  reset()
  emit('update:modelValue', false)
}

// Can replace?
const canReplace = computed(() => {
  return !props.readOnly && replaceMode.value && hasResults.value && replaceText.value.trim().length > 0
})

// ============================================
// Keyboard Shortcuts (using VueUse onKeyStroke)
// ============================================

// Modal must be open for shortcuts to work
const modalOpen = toRef(props, 'modelValue')

// Enter - Execute find (when in input field)
onKeyStroke('Enter', (e) => {
  if (!modalOpen.value) return
  if (!isInputFocused()) return
  e.preventDefault()
  handleFind()
}, { dedupe: true })

// Escape - Close modal (always works)
onKeyStroke('Escape', (e) => {
  if (!modalOpen.value) return
  e.preventDefault()
  reset()
  emit('update:modelValue', false)
}, { dedupe: true })

// Primary+Backspace - Clear search (Cmd on Mac, Ctrl on Win/Linux)
onKeyStroke('Backspace', (e) => {
  if (!modalOpen.value) return
  if (!isPrimaryModifier(e)) return
  e.preventDefault()
  handleClear() // handleClear already refocuses the input
}, { dedupe: true })

// n - Next match (only when not typing)
onKeyStroke('n', (e) => {
  if (!modalOpen.value || !hasResults.value) return
  if (isInputFocused()) return
  e.preventDefault()
  nextMatch()
  scrollToCurrentMatch()
}, { dedupe: true })

// p - Previous match (only when not typing)
onKeyStroke('p', (e) => {
  if (!modalOpen.value || !hasResults.value) return
  if (isInputFocused()) return
  e.preventDefault()
  prevMatch()
  scrollToCurrentMatch()
}, { dedupe: true })

// Home - First match
onKeyStroke('Home', (e) => {
  if (!modalOpen.value || !hasResults.value) return
  if (isInputFocused()) return
  e.preventDefault()
  firstMatch()
  scrollToCurrentMatch()
}, { dedupe: true })

// End - Last match
onKeyStroke('End', (e) => {
  if (!modalOpen.value || !hasResults.value) return
  if (isInputFocused()) return
  e.preventDefault()
  lastMatch()
  scrollToCurrentMatch()
}, { dedupe: true })

// r - Replace current match (only when not typing and can replace)
onKeyStroke('r', (e) => {
  if (!modalOpen.value || !canReplace.value) return
  if (isInputFocused()) return
  e.preventDefault()
  handleReplaceOne()
}, { dedupe: true })

// u - Undo (only when not typing and can undo)
onKeyStroke('u', (e) => {
  if (!modalOpen.value || !canUndo.value) return
  if (isInputFocused()) return
  e.preventDefault()
  handleUndo()
}, { dedupe: true })
</script>

<template>
  <BModal
    :model-value="modelValue"
    size="xl"
    title="Find & Replace"
    scrollable
    @show="handleShow"
    @hidden="handleHidden"
  >
    <!-- Mode Toggle -->
    <div class="mb-3 d-flex gap-2">
      <BButton
        :variant="!replaceMode ? 'primary' : 'outline-secondary'"
        size="sm"
        @click="replaceMode = false"
      >
        <i class="bi bi-search me-1" />Find Only
      </BButton>
      <BButton
        :variant="replaceMode ? 'primary' : 'outline-secondary'"
        size="sm"
        @click="replaceMode = true"
      >
        <i class="bi bi-arrow-left-right me-1" />Find & Replace
      </BButton>
    </div>

    <!-- Find Input -->
    <BFormGroup label="Find">
      <div class="find-input-wrapper">
        <BFormInput
          ref="searchInputRef"
          v-model="searchText"
          autocomplete="off"
          placeholder="Enter text to find..."
        />
        <div class="input-actions">
          <button
            v-if="searchText"
            type="button"
            class="clear-btn"
            title="Clear search (Ctrl+Backspace)"
            @click="handleClear"
          >
            <i class="bi bi-x-lg" />
          </button>
          <BFormCheckbox
            v-model="caseSensitive"
            class="match-case-checkbox"
            title="Match case"
          >
            Aa
          </BFormCheckbox>
        </div>
      </div>
    </BFormGroup>

    <!-- Replace Input (only in replace mode) -->
    <BFormGroup v-if="replaceMode" label="Replace">
      <BFormInput
        v-model="replaceText"
        autocomplete="off"
        placeholder="Enter replacement text..."
      />
    </BFormGroup>

    <!-- Field Selection -->
    <BFormGroup>
      <template #label>
        <span>Fields to include</span><br>
        <BFormCheckbox
          v-model="allFieldsSelected"
          :indeterminate="indeterminate"
          class="mt-1"
          @update:model-value="toggleAllFields"
        >
          {{ allFieldsSelected ? 'Unselect All' : 'Select All' }}
        </BFormCheckbox>
      </template>
      <div class="field-checkboxes">
        <BFormCheckbox
          v-for="field in FIND_REPLACE_FIELDS"
          :key="field"
          v-model="selectedFields"
          :value="field"
          class="field-checkbox"
        >
          {{ getFieldLabel(field) }}
        </BFormCheckbox>
      </div>
    </BFormGroup>

    <!-- Results Summary & Navigation -->
    <div v-if="hasResults" class="results-summary mb-3 d-flex justify-content-between align-items-center">
      <div>
        <span class="fw-bold">{{ summary }}</span>
        <span v-if="matches.length > 0" class="ms-2 text-muted">
          ({{ progress }})
        </span>
      </div>
      <div class="d-flex gap-2 align-items-center">
        <!-- Undo button -->
        <BButton
          v-if="canUndo && !readOnly"
          variant="outline-secondary"
          size="sm"
          title="Undo last replacement (u)"
          @click="handleUndo"
        >
          <i class="bi bi-arrow-counterclockwise" />
        </BButton>
        <!-- Navigation buttons -->
        <div class="btn-group">
          <BButton
            variant="outline-secondary"
            size="sm"
            :disabled="currentIndex === 0"
            title="First match (Home)"
            @click="firstMatch(); scrollToCurrentMatch()"
          >
            <i class="bi bi-chevron-bar-up" />
          </BButton>
          <BButton
            variant="outline-secondary"
            size="sm"
            :disabled="!hasPrev"
            title="Previous match (p)"
            @click="prevMatch(); scrollToCurrentMatch()"
          >
            <i class="bi bi-chevron-up" />
          </BButton>
          <BButton
            variant="outline-secondary"
            size="sm"
            :disabled="!hasNext"
            title="Next match (n)"
            @click="nextMatch(); scrollToCurrentMatch()"
          >
            <i class="bi bi-chevron-down" />
          </BButton>
          <BButton
            variant="outline-secondary"
            size="sm"
            :disabled="currentIndex === matches.length - 1"
            title="Last match (End)"
            @click="lastMatch(); scrollToCurrentMatch()"
          >
            <i class="bi bi-chevron-bar-down" />
          </BButton>
        </div>
      </div>
    </div>

    <div v-else-if="totalMatches === 0 && searchText.trim().length >= 2" class="results-summary mb-3">
      <small class="text-muted">No results found.</small>
    </div>

    <hr v-if="hasResults">

    <!-- Results List (grouped by rule) -->
    <div v-if="hasResults" class="results-list">
      <BCard
        v-for="[ruleId, group] in groupedMatches"
        :key="ruleId"
        class="mb-3"
      >
        <template #header>
          <div class="d-flex justify-content-between align-items-center">
            <span class="fw-bold">{{ formatRuleId(group.ruleIdentifier) }}</span>
            <span class="badge bg-secondary">{{ group.matches.length }} match{{ group.matches.length !== 1 ? 'es' : '' }}</span>
          </div>
        </template>

        <div
          v-for="match in group.matches"
          :key="`${match.field}-${match.index}`"
          class="match-item"
          :class="{ 'match-current': isCurrentMatch(match) }"
          @click="navigateToMatch(match)"
        >
          <div class="d-flex justify-content-between align-items-start">
            <div class="flex-grow-1">
              <div class="match-field text-muted small mb-1">
                {{ getFieldLabel(match.field) }}
              </div>
              <div class="match-context">
                <!-- Show context with highlighted match -->
                <span class="context-before">{{ match.context.substring(0, match.context.indexOf(match.text)) }}</span>
                <mark class="match-highlight">{{ match.text }}</mark>
                <span class="context-after">{{ match.context.substring(match.context.indexOf(match.text) + match.text.length) }}</span>
              </div>
              <div v-if="replaceMode && replaceText.trim()" class="match-preview text-success small mt-1">
                → {{ replaceText }}
              </div>
            </div>
            <div v-if="replaceMode && !readOnly" class="match-actions ms-2">
              <BButton
                variant="outline-primary"
                size="sm"
                :disabled="isLoading || !isCurrentMatch(match)"
                @click.stop="handleReplaceOne"
              >
                Replace
              </BButton>
            </div>
          </div>
        </div>
      </BCard>
    </div>

    <!-- Footer Actions -->
    <template #footer>
      <div class="footer-content">
        <!-- Keyboard shortcuts - organized in groups (cross-platform) -->
        <div class="shortcuts-section">
          <div class="shortcut-group">
            <span class="shortcut-label">Search:</span>
            <kbd>{{ getKeySymbol('Enter') }}</kbd> Find
            <span class="separator">·</span>
            <span :class="{ 'text-muted': !searchText }">
              <kbd>{{ getKeySymbol('Meta') }}{{ getKeySymbol('Backspace') }}</kbd> Clear
            </span>
            <span class="separator">·</span>
            <kbd>{{ getKeySymbol('Escape') }}</kbd> Close
          </div>
          <div v-if="hasResults" class="shortcut-group">
            <span class="shortcut-label">Navigate:</span>
            <kbd>n</kbd> Next
            <span class="separator">·</span>
            <kbd>p</kbd> Prev
            <span class="separator">·</span>
            <kbd>Home</kbd> First
            <span class="separator">·</span>
            <kbd>End</kbd> Last
          </div>
          <div v-if="hasResults && !readOnly && replaceMode" class="shortcut-group">
            <span class="shortcut-label">Actions:</span>
            <kbd>r</kbd> Replace
            <span class="separator">·</span>
            <span :class="{ 'text-muted': !canUndo }"><kbd>u</kbd> Undo</span>
          </div>
        </div>

        <!-- Action buttons -->
        <div class="action-buttons">
          <BButton
            variant="primary"
            :disabled="!searchText.trim() || searchText.trim().length < 2 || isLoading"
            @click="handleFind"
          >
            <span v-if="isLoading" class="spinner-border spinner-border-sm me-1" />
            Find
          </BButton>
          <BButton
            v-if="replaceMode && !readOnly"
            variant="secondary"
            :disabled="!canReplace || isLoading"
            @click="handleReplaceOne"
          >
            Replace
          </BButton>
          <BButton
            v-if="replaceMode && !readOnly"
            variant="primary"
            :disabled="!canReplace || isLoading"
            @click="showConfirmModal = true"
          >
            Replace All
          </BButton>
        </div>
      </div>
    </template>

    <!-- Replace All Confirmation Modal -->
    <ActionCommentModal
      v-model="showConfirmModal"
      title="Replace All"
      message="Provide a comment that summarizes your changes to these requirements."
      confirm-text="Replace All"
      confirm-variant="primary"
      :require-comment="false"
      comment-label="Audit Comment"
      comment-placeholder="Find & Replace (all)"
      :loading="isLoading"
      @confirm="handleReplaceAll"
      @cancel="showConfirmModal = false"
    />
  </BModal>
</template>

<style scoped>
.find-input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}

.find-input-wrapper :deep(input) {
  padding-right: 5rem; /* Space for clear btn and match case */
}

.input-actions {
  position: absolute;
  right: 0.5rem;
  display: flex;
  align-items: center;
  gap: 0.25rem;
}

.clear-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 1.5rem;
  height: 1.5rem;
  padding: 0;
  border: none;
  background: transparent;
  color: var(--bs-secondary-color);
  cursor: pointer;
  border-radius: 0.25rem;
  transition: all 0.15s ease;
}

.clear-btn:hover {
  background-color: var(--bs-tertiary-bg);
  color: var(--bs-body-color);
}

.match-case-checkbox {
  font-family: monospace;
  font-size: 0.875rem;
  font-weight: 600;
  padding: 0.125rem 0.375rem;
  border-radius: 0.25rem;
  cursor: pointer;
  user-select: none;
}

.match-case-checkbox :deep(.form-check-input) {
  display: none;
}

.match-case-checkbox :deep(.form-check-label) {
  padding: 0.125rem 0.375rem;
  border-radius: 0.25rem;
  color: var(--bs-secondary-color);
  transition: all 0.15s ease;
}

.match-case-checkbox :deep(.form-check-input:checked + .form-check-label) {
  background-color: var(--bs-primary);
  color: white;
}

.field-checkboxes {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem 1rem;
  margin-left: 1rem;
}

.field-checkbox {
  flex: 0 0 calc(33.333% - 1rem);
  min-width: 150px;
}

.results-summary {
  padding: 0.5rem 0;
}

.results-list {
  max-height: 400px;
  overflow-y: auto;
}

.match-item {
  padding: 0.75rem;
  border-bottom: 1px solid var(--bs-border-color);
  cursor: pointer;
  transition: background-color 0.15s ease;
}

.match-item:last-child {
  border-bottom: none;
}

.match-item:hover {
  background-color: var(--bs-tertiary-bg);
}

.match-current {
  background-color: var(--bs-warning-bg-subtle) !important;
  border-left: 3px solid var(--bs-warning);
  margin-left: -3px;
  padding-left: calc(0.75rem + 3px);
}

.match-field {
  font-weight: 500;
}

.match-context {
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', 'Consolas', monospace;
  font-size: 0.875rem;
  line-height: 1.5;
  white-space: pre-wrap;
  word-break: break-word;
}

.match-highlight {
  background-color: var(--bs-warning-bg-subtle);
  color: var(--bs-warning-text-emphasis);
  padding: 0.125rem 0.25rem;
  border-radius: 0.25rem;
}

.match-current .match-highlight {
  background-color: var(--bs-warning);
  color: var(--bs-dark);
  font-weight: 600;
}

.match-preview {
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', 'Consolas', monospace;
}

/* Footer layout with container queries */
.footer-content {
  container-type: inline-size;
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  width: 100%;
  gap: 1rem;
}

.shortcuts-section {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  font-size: 0.8125rem;
  color: var(--bs-secondary-color);
}

.shortcut-group {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  flex-wrap: wrap;
}

.shortcut-label {
  font-weight: 600;
  color: var(--bs-body-color);
  min-width: 5rem;
}

.separator {
  color: var(--bs-tertiary-color);
  margin: 0 0.125rem;
}

.action-buttons {
  display: flex;
  gap: 0.5rem;
  flex-shrink: 0;
}

kbd {
  display: inline-block;
  padding: 0.25rem 0.5rem;
  font-size: 0.875rem;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
  font-weight: 500;
  line-height: 1.2;
  color: var(--bs-body-color);
  background-color: var(--bs-tertiary-bg);
  border: 1px solid var(--bs-border-color);
  border-radius: 0.375rem;
  box-shadow: 0 1px 0 rgba(0, 0, 0, 0.1);
  min-width: 1.5rem;
  text-align: center;
}

@media (min-width: 992px) {
  .modal-xl {
    max-width: 90% !important;
  }
}

/* Container query: stack footer when container is narrow */
@container (max-width: 600px) {
  .footer-content {
    flex-direction: column;
    align-items: stretch;
    gap: 0.75rem;
  }

  .action-buttons {
    justify-content: flex-end;
  }

  .shortcut-label {
    min-width: auto;
  }
}

/* Fallback media query for browsers without container query support */
@supports not (container-type: inline-size) {
  @media (max-width: 768px) {
    .footer-content {
      flex-direction: column;
      align-items: stretch;
      gap: 0.75rem;
    }

    .action-buttons {
      justify-content: flex-end;
    }

    .shortcut-label {
      min-width: auto;
    }
  }
}

/* Modal header/footer sticky with darker background for separation */
:deep(.modal-header) {
  position: sticky;
  top: 0;
  z-index: 10;
  background-color: var(--bs-secondary-bg);
  border-bottom: 1px solid var(--bs-border-color);
}

:deep(.modal-footer) {
  position: sticky;
  bottom: 0;
  z-index: 10;
  background-color: var(--bs-secondary-bg);
  border-top: 1px solid var(--bs-border-color);
}

:deep(.modal-body) {
  background-color: var(--bs-body-bg);
}
</style>
