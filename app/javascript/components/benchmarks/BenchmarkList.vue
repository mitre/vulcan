<script setup lang="ts">
/**
 * BenchmarkList.vue
 *
 * Unified list component for both STIGs and SRGs.
 * Displays a header with count badge, upload button (if admin), and a searchable table.
 *
 * Usage:
 *   <BenchmarkList
 *     type="stig"
 *     :items="stigs"
 *     :is-admin="isAdmin"
 *     @upload="handleUpload"
 *     @delete="handleDelete"
 *   />
 */
import type { BenchmarkType, IBenchmarkListItem } from '@/types'
import { BBadge, BButton, BCol, BFormFile, BModal, BRow } from 'bootstrap-vue-next'
import { computed, ref } from 'vue'
import BenchmarkTable from './BenchmarkTable.vue'

const props = withDefaults(
  defineProps<{
    type: BenchmarkType
    items: IBenchmarkListItem[]
    isAdmin: boolean
  }>(),
  {},
)

const emit = defineEmits<{
  refresh: []
  upload: [file: File]
  delete: [id: number]
}>()

// Modal state
const showUploadModal = ref(false)
const selectedFile = ref<File | null>(null)

// Type-specific labels
const labels = computed(() => {
  switch (props.type) {
    case 'stig':
      return {
        title: 'Security Technical Implementation Guides',
        subtitle: 'Published STIGs',
        uploadButton: 'Upload STIG',
      }
    case 'srg':
      return {
        title: 'Security Requirements Guides',
        subtitle: 'Use the following guides to start a new Project',
        uploadButton: 'Upload SRG',
      }
    case 'component':
      return {
        title: 'Released Components',
        subtitle: 'Published security guidance components',
        uploadButton: '', // Components don't support upload
      }
    default:
      return { title: '', subtitle: '', uploadButton: '' }
  }
})

// Components don't support file upload
const showUploadButton = computed(() => props.isAdmin && props.type !== 'component')

/**
 * Handle file upload from modal
 */
function handleUpload() {
  if (!selectedFile.value) return
  emit('upload', selectedFile.value)
  showUploadModal.value = false
  selectedFile.value = null
}

/**
 * Handle delete request from table
 */
function handleDelete(id: number) {
  emit('delete', id)
}
</script>

<template>
  <div>
    <BRow>
      <BCol md="10">
        <h1>
          {{ labels.title }}
          <BBadge variant="secondary">
            {{ items.length }}
          </BBadge>
        </h1>
        <h6 class="card-subtitle text-muted mb-2">
          {{ labels.subtitle }}
        </h6>
      </BCol>
      <BCol v-if="showUploadButton" md="2" class="align-self-center">
        <BButton variant="primary" class="float-end" @click="showUploadModal = true">
          <i class="bi bi-cloud-upload" aria-hidden="true" />
          {{ labels.uploadButton }}
        </BButton>
      </BCol>
    </BRow>
    <BenchmarkTable
      :type="type"
      :items="items"
      :is-admin="isAdmin"
      @delete="handleDelete"
    />
    <!-- Upload Modal -->
    <BModal
      v-model="showUploadModal"
      size="lg"
      :title="`Upload ${type === 'stig' ? 'a STIG' : 'an SRG'}`"
      @hidden="selectedFile = null"
    >
      <BFormFile
        v-model="selectedFile"
        :placeholder="`Choose or drop ${type === 'stig' ? 'a STIG' : 'an SRG'} XML here...`"
        accept="text/xml, application/xml"
      />
      <template #footer>
        <BButton variant="secondary" @click="selectedFile = null">
          Clear
        </BButton>
        <BButton
          variant="primary"
          :disabled="!selectedFile"
          @click="handleUpload"
        >
          Upload
        </BButton>
      </template>
    </BModal>
  </div>
</template>
