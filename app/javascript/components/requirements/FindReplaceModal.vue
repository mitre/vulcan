<script setup lang="ts">
import type { IRule } from '@/types'
import { BButton, BCard, BFormCheckbox, BFormGroup, BFormInput, BModal } from 'bootstrap-vue-next'
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import ActionCommentModal from '@/components/shared/ActionCommentModal.vue'
import { FIND_REPLACE_FIELDS, useFindReplace } from '@/composables/useFindReplace'
import FindReplaceResultCard from './FindReplaceResultCard.vue'

interface Props {
  modelValue: boolean
  componentId: number
  rules: IRule[]
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

const {
  loading,
  findText,
  replaceText,
  matchCase,
  selectedFields,
  searchResults,
  searchVersion,
  fullRulesCache,
  totalMatches,
  totalControls,
  sortedResults,
  executeFind,
  replaceOne,
  replaceAll,
  reset,
} = useFindReplace()

const showReplaceAllModal = ref(false)
const currentResultIndex = ref(0)

// Mode toggle - Find only vs Find & Replace
const replaceMode = ref(true)  // Default to replace mode

// "Select All" checkbox state
const allFieldsSelected = ref(true)
const indeterminate = ref(false)

// Get flat list of all results for navigation
const flatResults = computed(() => {
  const results: Array<{ ruleId: number, fieldMatch: IFieldMatch, index: number }> = []
  let index = 0
  sortedResults.value.forEach(([ruleId, ruleMatches]) => {
    ruleMatches.results.forEach((fieldMatch) => {
      results.push({ ruleId: Number(ruleId), fieldMatch, index })
      index++
    })
  })
  return results
})

const totalResultsCount = computed(() => flatResults.value.length)
const currentMatch = computed(() => flatResults.value[currentResultIndex.value])

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
  await executeFind(props.componentId, props.rules)
}

// Replace single field in a rule - NO MODAL, just do it
async function handleReplaceOne(ruleId: number, fieldMatch: IFieldMatch) {
  const rule = fullRulesCache.value.get(ruleId)
  if (!rule) {
    console.error('Rule not found in cache:', ruleId)
    return
  }

  await replaceOne(ruleId, rule, fieldMatch, 'Find & Replace', undefined, async () => {
    await handleFind()
    emit('replaced')
  })
}

// Replace with custom text for a specific match
async function handleReplaceCustom(ruleId: number, fieldMatch: IFieldMatch, customReplacement: string) {
  const rule = fullRulesCache.value.get(ruleId)
  if (!rule) {
    console.error('Rule not found in cache:', ruleId)
    return
  }

  await replaceOne(ruleId, rule, fieldMatch, 'Find & Replace (custom)', customReplacement, async () => {
    await handleFind()
    emit('replaced')
  })
}

// Replace all matches
async function handleReplaceAll(comment: string) {
  // Use cached full rules from search results
  const cachedRules = Array.from(fullRulesCache.value.values())
  await replaceAll(cachedRules, comment, async () => {
    // Re-run find to update results
    await handleFind()
    emit('replaced')
  })
  showReplaceAllModal.value = false
}

// Format rule ID with project prefix
function formatRuleId(rule_id: string): string {
  return `${props.projectPrefix}-${rule_id}`
}

// Get global index for a field match
function getGlobalIndex(ruleId: number, fieldMatch: IFieldMatch): number {
  return flatResults.value.findIndex(r => r.ruleId === ruleId && r.fieldMatch === fieldMatch)
}

// Modal visibility handlers
function handleShow() {
  reset()
}

function handleHidden() {
  reset()
  emit('update:modelValue', false)
}

// Computed states
const hasResults = computed(() => Object.keys(searchResults.value).length > 0)
const canReplace = computed(() => !props.readOnly && replaceMode.value && hasResults.value && replaceText.value.trim().length > 0)

// Keyboard shortcuts
function handleKeydown(event: KeyboardEvent) {
  if (!props.modelValue) return

  // Enter - Execute find
  if (event.key === 'Enter' && !event.shiftKey && !event.ctrlKey && !event.metaKey) {
    const activeElement = document.activeElement as HTMLElement
    // Don't trigger if user is in a button or textarea
    if (activeElement?.tagName !== 'BUTTON' && activeElement?.tagName !== 'TEXTAREA') {
      event.preventDefault()
      handleFind()
    }
  }

  // Escape - Clear search and close modal
  if (event.key === 'Escape') {
    event.preventDefault()
    reset()
    emit('update:modelValue', false)
  }

  // n - Next match
  if (event.key === 'n' && hasResults.value) {
    event.preventDefault()
    scrollToNextMatch()
  }

  // p - Previous match
  if (event.key === 'p' && hasResults.value) {
    event.preventDefault()
    scrollToPreviousMatch()
  }

  // r - Replace current match (if not read-only)
  if (event.key === 'r' && canReplace.value) {
    event.preventDefault()
    replaceCurrentMatch()
  }
}

// Navigate to next match
function scrollToNextMatch() {
  if (totalResultsCount.value === 0) return
  currentResultIndex.value = (currentResultIndex.value + 1) % totalResultsCount.value
  scrollToCurrentMatch()
}

// Navigate to previous match
function scrollToPreviousMatch() {
  if (totalResultsCount.value === 0) return
  currentResultIndex.value = (currentResultIndex.value - 1 + totalResultsCount.value) % totalResultsCount.value
  scrollToCurrentMatch()
}

// Scroll to current match (scroll to the actual highlighted text within the result)
function scrollToCurrentMatch() {
  const current = currentMatch.value
  if (!current) return

  // Use requestAnimationFrame to ensure DOM is updated and rendered
  requestAnimationFrame(() => {
    const matchElement = document.querySelector(`#match-${current.index}`)
    if (matchElement) {
      // Scroll the match into the center of the viewport
      matchElement.scrollIntoView({ behavior: 'smooth', block: 'center' })
    }
  })
}

// Replace the currently focused match via 'r' keyboard shortcut
function replaceCurrentMatch() {
  const current = currentMatch.value
  if (!current || !canReplace.value) return
  handleReplaceOne(current.ruleId, current.fieldMatch)
}

// Register/unregister keyboard listeners
onMounted(() => {
  window.addEventListener('keydown', handleKeydown)
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeydown)
})
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
          v-model="findText"
          autocomplete="off"
          placeholder="Enter text to find..."
        />
        <label class="match-case-toggle">
          <BFormCheckbox v-model="matchCase" />
          Match Case
        </label>
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
          {{ field }}
        </BFormCheckbox>
      </div>
    </BFormGroup>

    <!-- Results Summary -->
    <div v-if="searchVersion > 0" class="results-summary mb-3">
      <small v-if="totalMatches > 0">
        {{ totalMatches }} matches in {{ totalControls }} controls
      </small>
      <small v-else class="text-muted">No results found.</small>
    </div>

    <!-- Action Buttons (Top) -->
    <div v-if="hasResults" class="d-flex justify-content-end gap-2 mb-3">
      <BButton
        variant="primary"
        :disabled="!findText.trim() || loading"
        @click="handleFind"
      >
        Find
      </BButton>
      <BButton
        v-if="!readOnly"
        variant="primary"
        :disabled="!canReplace || loading"
        @click="showReplaceAllModal = true"
      >
        Replace All
      </BButton>
    </div>

    <hr v-if="hasResults">

    <!-- Results List -->
    <div v-if="hasResults">
      <BCard
        v-for="[ruleId, ruleMatches] in sortedResults"
        :key="`${searchVersion}-${ruleId}`"
        :title="formatRuleId(ruleMatches.rule_id)"
        class="mb-3"
      >
        <FindReplaceResultCard
          v-for="(fieldMatch, fieldIndex) in ruleMatches.results"
          :key="fieldIndex"
          :field-match="fieldMatch"
          :replace-text="replaceText"
          :disabled="loading || readOnly || !replaceMode"
          :result-index="getGlobalIndex(Number(ruleId), fieldMatch)"
          :is-current="getGlobalIndex(Number(ruleId), fieldMatch) === currentResultIndex"
          @replace="handleReplaceOne(Number(ruleId), fieldMatch)"
          @replace-custom="handleReplaceCustom(Number(ruleId), fieldMatch, $event)"
        />
      </BCard>
    </div>

    <!-- Footer Actions -->
    <template #footer>
      <div class="d-flex justify-content-between align-items-center w-100">
        <!-- Keyboard shortcuts hint -->
        <small class="text-muted">
          <kbd>Enter</kbd> Find
          <span v-if="hasResults">
            · <kbd>n</kbd> Next · <kbd>p</kbd> Prev
            <span v-if="!readOnly">· <kbd>r</kbd> Replace</span>
          </span>
          · <kbd>Esc</kbd> Close
        </small>

        <!-- Action buttons -->
        <div class="d-flex gap-2">
          <BButton
            variant="primary"
            :disabled="!findText.trim() || loading"
            @click="handleFind"
          >
            <span v-if="loading" class="spinner-border spinner-border-sm me-1" />
            Find
          </BButton>
          <BButton
            v-if="replaceMode && !readOnly"
            variant="secondary"
            :disabled="!canReplace || loading || totalResultsCount === 0"
            @click="replaceCurrentMatch"
          >
            Replace
          </BButton>
          <BButton
            v-if="replaceMode && !readOnly"
            variant="primary"
            :disabled="!canReplace || loading"
            @click="showReplaceAllModal = true"
          >
            Replace All
          </BButton>
        </div>
      </div>
    </template>

    <!-- Replace All Confirmation Modal (only modal we keep) -->
    <ActionCommentModal
      v-model="showReplaceAllModal"
      title="Replace All"
      message="Provide a comment that summarizes your changes to these controls."
      confirm-text="Replace All"
      confirm-variant="primary"
      :require-comment="false"
      comment-label="Audit Comment"
      comment-placeholder="Find & Replace (all)"
      :loading="loading"
      @confirm="handleReplaceAll"
      @cancel="showReplaceAllModal = false"
    />
  </BModal>
</template>

<style scoped>
.find-input-wrapper {
  position: relative;
}

.match-case-toggle {
  position: absolute;
  top: 50%;
  right: 0;
  transform: translateY(-50%);
  display: flex;
  align-items: center;
  margin-right: 10px;
  font-size: 0.75rem;
  cursor: pointer;
  user-select: none;
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
  font-weight: 600;
}

kbd {
  display: inline-block;
  padding: 0.125rem 0.375rem;
  font-size: 0.75rem;
  font-family: monospace;
  line-height: 1;
  color: #212529;
  background-color: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 0.25rem;
  box-shadow: 0 1px 0 rgba(0, 0, 0, 0.1);
}

@media (min-width: 992px) {
  .modal-xl {
    max-width: 90% !important;
  }
}
</style>
