<script setup lang="ts">
import { computed } from 'vue'
import { marked } from 'marked'
import DOMPurify from 'dompurify'

const props = defineProps<{
  show: boolean
  content: string
}>()

const emit = defineEmits<{
  acknowledge: []
}>()

/**
 * Convert markdown to sanitized HTML
 */
const htmlContent = computed(() => {
  const raw = marked.parse(props.content) as string
  return DOMPurify.sanitize(raw)
})

function handleAcknowledge() {
  emit('acknowledge')
}
</script>

<template>
  <BOverlay :show="show" variant="dark" blur="8px" opacity="0.85" no-wrap fixed>
    <BModal
      :model-value="show"
      title="Terms of Use"
      size="lg"
      backdrop="static"
      :no-close-on-backdrop="true"
      :no-close-on-esc="true"
      :hide-header-close="true"
      :hide-footer="true"
      centered
    >
      <!-- Markdown content -->
      <div class="consent-content" v-html="htmlContent" />

      <!-- Footer with acknowledge button -->
      <template #footer>
        <div class="d-flex justify-content-end w-100">
          <BButton variant="primary" size="lg" @click="handleAcknowledge">
            I Agree
          </BButton>
        </div>
      </template>
    </BModal>
  </BOverlay>
</template>

<style scoped>
.consent-content {
  font-size: 1rem;
  line-height: 1.6;
  max-height: 60vh;
  overflow-y: auto;
}

/* Style markdown elements with Bootstrap classes */
.consent-content :deep(h2) {
  font-size: 1.5rem;
  font-weight: 600;
  margin-top: 1rem;
  margin-bottom: 0.75rem;
}

.consent-content :deep(h3) {
  font-size: 1.25rem;
  font-weight: 600;
  margin-top: 0.75rem;
  margin-bottom: 0.5rem;
}

.consent-content :deep(p) {
  margin-bottom: 1rem;
}

.consent-content :deep(ul),
.consent-content :deep(ol) {
  margin-bottom: 1rem;
  padding-left: 1.5rem;
}

.consent-content :deep(li) {
  margin-bottom: 0.5rem;
}

.consent-content :deep(strong) {
  font-weight: 600;
}

.consent-content :deep(code) {
  padding: 0.2rem 0.4rem;
  background-color: #f8f9fa;
  border-radius: 0.25rem;
  font-family: monospace;
}
</style>
