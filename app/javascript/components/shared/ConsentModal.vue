<script setup lang="ts">
import DOMPurify from 'dompurify'
import { marked } from 'marked'
import {
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogOverlay,
  DialogPortal,
  DialogRoot,
  DialogTitle,
} from 'reka-ui'
import { computed } from 'vue'

const props = defineProps<{
  show: boolean
  title: string
  titleAlign: 'left' | 'center' | 'right'
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
  <DialogRoot :open="show">
    <DialogPortal>
      <!-- Overlay with blur effect -->
      <DialogOverlay class="consent-overlay" />

      <!-- Dialog content -->
      <DialogContent
        class="consent-dialog"
        :class="`consent-dialog-title-${titleAlign}`"
        @escape-key-down.prevent
        @pointer-down-outside.prevent
        @interact-outside.prevent
      >
        <!-- Title -->
        <DialogTitle class="consent-dialog-title">
          {{ title }}
        </DialogTitle>

        <!-- Hidden description for screen readers -->
        <DialogDescription class="visually-hidden">
          Please read and acknowledge the terms to continue
        </DialogDescription>

        <!-- Markdown content -->
        <div class="consent-content" v-html="htmlContent" />

        <!-- Footer with acknowledge button -->
        <div class="consent-footer">
          <DialogClose as-child>
            <button
              class="btn btn-primary btn-lg consent-agree-btn"
              type="button"
              @click="handleAcknowledge"
            >
              I Agree
            </button>
          </DialogClose>
        </div>
      </DialogContent>
    </DialogPortal>
  </DialogRoot>
</template>

<style>
/* Overlay with blur effect */
.consent-overlay {
  position: fixed;
  inset: 0;
  z-index: 9998;
  background-color: rgba(0, 0, 0, 0.85);
  backdrop-filter: blur(8px);
}

/* Dialog container */
.consent-dialog {
  position: fixed;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  z-index: 9999;
  width: 90vw;
  max-width: 800px;
  max-height: 85vh;
  background-color: var(--bs-body-bg);
  color: var(--bs-body-color);
  border-radius: 0.5rem;
  box-shadow: 0 1rem 3rem rgba(0, 0, 0, 0.175);
  display: flex;
  flex-direction: column;
  padding: 1.5rem;
}

/* Title styling */
.consent-dialog-title {
  font-size: 1.75rem;
  font-weight: 600;
  margin-bottom: 1.5rem;
  color: var(--bs-body-color);
}

/* Title alignment options */
.consent-dialog-title-left .consent-dialog-title {
  text-align: left;
}

.consent-dialog-title-center .consent-dialog-title {
  text-align: center;
}

.consent-dialog-title-right .consent-dialog-title {
  text-align: right;
}

/* Footer */
.consent-footer {
  display: flex;
  justify-content: flex-end;
  margin-top: 1.5rem;
  padding-top: 1rem;
  border-top: 1px solid var(--bs-border-color);
}
</style>

<style scoped>
.consent-content {
  font-size: 1rem;
  line-height: 1.6;
  max-height: 60vh;
  overflow-y: auto;
  color: inherit;
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
