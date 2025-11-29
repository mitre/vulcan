<script setup lang="ts">
import { computed, ref } from 'vue'
import { BButton, BCol, BFormGroup, BFormInput, BModal, BRow } from 'bootstrap-vue-next'
import type { IFieldMatch, ITextSegment } from '@/composables/useFindReplace'

interface Props {
  fieldMatch: IFieldMatch
  replaceText: string
  disabled?: boolean
  resultIndex?: number
  isCurrent?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  disabled: false,
  resultIndex: -1,
  isCurrent: false,
})

const emit = defineEmits<{
  (e: 'replace'): void
  (e: 'replaceCustom', customText: string): void
}>()

const showCustomModal = ref(false)
const customText = ref('')

/**
 * Preview of text after replacement
 */
const preview = computed(() => {
  return props.fieldMatch.segments.map((segment: ITextSegment) => ({
    text: segment.text,
    highlighted: segment.highlighted,
    replacement: segment.highlighted ? props.replaceText : segment.text,
  }))
})

function openCustomReplace() {
  customText.value = props.replaceText
  showCustomModal.value = true
}

function handleCustomReplace() {
  if (customText.value.trim()) {
    emit('replaceCustom', customText.value.trim())
    showCustomModal.value = false
  }
}
</script>

<template>
  <div class="find-replace-result mb-3" :class="{ 'current-result': isCurrent }">
    <BRow>
      <BCol lg="2" class="mb-2">
        <h6 class="mb-0 field-name">
          {{ fieldMatch.field }}
        </h6>
      </BCol>
      <BCol lg="8" class="mb-2">
        <div :id="`match-${resultIndex}`" class="preview-text">
          <span v-for="(item, index) in preview" :key="index">
            <template v-if="item.highlighted">
              <del>
                <span class="match-highlight-old">{{ item.text }}</span>
              </del>
              <span class="match-highlight-new">{{ item.replacement }}</span>
            </template>
            <span v-else>{{ item.text }}</span>
          </span>
        </div>
      </BCol>
      <BCol lg="2" class="text-end">
        <div class="d-flex gap-1 justify-content-end">
          <BButton
            variant="secondary"
            size="sm"
            :disabled="disabled"
            @click="emit('replace')"
          >
            Replace
          </BButton>
          <BButton
            variant="outline-secondary"
            size="sm"
            :disabled="disabled"
            title="Replace with custom text"
            @click="openCustomReplace"
          >
            <i class="bi bi-pencil" />
          </BButton>
        </div>
      </BCol>
    </BRow>

    <!-- Custom replacement modal -->
    <BModal v-model="showCustomModal" title="Replace with Custom Text" @ok="handleCustomReplace">
      <BFormGroup label="Custom Replacement Text">
        <BFormInput
          v-model="customText"
          placeholder="Enter custom replacement..."
          autofocus
        />
      </BFormGroup>
    </BModal>
  </div>
</template>

<style scoped>
.find-replace-result {
  padding: 0.5rem 0;
  border-bottom: 1px solid var(--bs-border-color);
  transition: background-color 0.2s ease, border-left 0.2s ease;
}

.find-replace-result:last-child {
  border-bottom: none;
}

.current-result {
  background-color: var(--bs-warning-bg-subtle);
  border-left: 3px solid var(--bs-warning);
  padding-left: 0.5rem;
  margin-left: -0.5rem;
}

.field-name {
  color: var(--bs-secondary-color);
  font-weight: 600;
}

.preview-text {
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', 'Consolas', monospace;
  font-size: 0.875rem;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-word;
}

.match-highlight-old {
  background-color: var(--bs-danger-bg-subtle);
  color: var(--bs-danger-text-emphasis);
  padding: 0.125rem 0.25rem;
  border-radius: 0.25rem;
}

.match-highlight-new {
  background-color: var(--bs-success-bg-subtle);
  color: var(--bs-success-text-emphasis);
  padding: 0.125rem 0.25rem;
  border-radius: 0.25rem;
  font-weight: 600;
}
</style>
