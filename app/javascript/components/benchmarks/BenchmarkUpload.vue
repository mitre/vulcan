<script setup lang="ts">
/**
 * BenchmarkUpload.vue
 *
 * Unified upload modal for both STIGs and SRGs.
 * Exposes show/hide methods for parent to call.
 *
 * Usage:
 *   <BenchmarkUpload
 *     ref="uploadModal"
 *     type="stig"
 *     @uploaded="handleUpload"
 *   />
 *   // Then call: uploadModal.value?.show()
 */
import type { BenchmarkType } from '@/types'
import { BButton, BFormFile, BModal } from 'bootstrap-vue-next'
import { computed, ref, useTemplateRef } from 'vue'

const props = withDefaults(
  defineProps<{
    type?: BenchmarkType
  }>(),
  {
    type: 'srg',
  },
)

const emit = defineEmits<{
  uploaded: [file: File]
}>()

// Template ref for the modal
const modalRef = useTemplateRef<InstanceType<typeof BModal>>('modalRef')

// Local state
const file = ref<File | null>(null)
const loading = ref(false)

// Expose show/hide methods to parent
function show() {
  console.log('[BenchmarkUpload] show() called')
  modalRef.value?.show()
}

function hide() {
  console.log('[BenchmarkUpload] hide() called')
  modalRef.value?.hide()
}

defineExpose({ show, hide })

// Label based on type
const typeLabel = computed(() => (props.type === 'stig' ? 'a STIG' : 'an SRG'))

/**
 * Clear selected file
 */
function clearFile() {
  file.value = null
}

/**
 * Submit upload - emit file to parent, let parent handle API call
 */
function submitUpload() {
  console.log('[BenchmarkUpload] submitUpload called, file:', file.value?.name)
  if (!file.value) {
    console.log('[BenchmarkUpload] No file selected, returning')
    return
  }

  loading.value = true
  console.log('[BenchmarkUpload] Emitting uploaded event with file:', file.value.name)
  emit('uploaded', file.value)

  // Reset state after emitting
  // Parent will close modal via v-model after handling
  setTimeout(() => {
    loading.value = false
    clearFile()
  }, 500)
}
</script>

<template>
  <BModal
    id="upload-benchmark-modal"
    ref="modalRef"
    size="lg"
    :title="`Upload ${typeLabel}`"
    @hidden="clearFile"
  >
    <BFormFile
      v-model="file"
      :placeholder="`Choose or drop ${typeLabel} XML here...`"
      :drop-placeholder="`Drop ${typeLabel} XML here...`"
      accept="text/xml, application/xml"
    />
    <template #footer>
      <div class="row w-100">
        <div class="col-8 ps-0">
          <p class="text-start">
            Selected file: {{ file ? file.name : 'No file selected' }}
          </p>
        </div>
        <div class="col-4 pe-0">
          <BButton
            variant="primary"
            class="float-end"
            :disabled="!file || loading"
            @click="submitUpload"
          >
            {{ loading ? 'Uploading...' : 'Upload' }}
          </BButton>
          <BButton variant="secondary" class="float-end me-2" @click="clearFile">
            Clear
          </BButton>
        </div>
      </div>
    </template>
  </BModal>
</template>
