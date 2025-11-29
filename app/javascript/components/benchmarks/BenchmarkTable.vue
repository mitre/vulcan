<script setup lang="ts">
/**
 * BenchmarkTable.vue
 *
 * Unified table component for both STIGs and SRGs.
 * Provides search, pagination, and row actions.
 *
 * Usage:
 *   <BenchmarkTable
 *     type="stig"
 *     :items="stigs"
 *     :is-admin="isAdmin"
 *     @delete="handleDelete"
 *   />
 */
import type { BenchmarkType, IBenchmarkListItem } from '@/types'
import { BButton, BModal, BPagination, BTable } from 'bootstrap-vue-next'
import { computed, ref } from 'vue'

const props = withDefaults(
  defineProps<{
    type: BenchmarkType
    items: IBenchmarkListItem[]
    isAdmin: boolean
  }>(),
  {},
)

const emit = defineEmits<{
  delete: [id: number]
}>()

// Local UI state
const search = ref('')
const perPage = ref(10)
const currentPage = ref(1)

// Delete confirmation state
const showDeleteModal = ref(false)
const itemToDelete = ref<IBenchmarkListItem | null>(null)

// Type-specific labels
const typeLabel = computed(() => (props.type === 'stig' ? 'STIG' : 'SRG'))

// Computed table fields based on type
const tableFields = computed(() => {
  const fields = [
    {
      key: 'benchmark_id',
      label: `${typeLabel.value} ID`,
    },
    { key: 'title', label: 'Title' },
    { key: 'version', label: 'Version' },
    { key: 'date', label: props.type === 'stig' ? 'Benchmark Date' : 'Release Date' },
  ]

  if (props.isAdmin) {
    fields.push({
      key: 'actions',
      label: 'Actions',
      thClass: 'text-end',
      tdClass: 'p-0 text-end',
    })
  }

  return fields
})

// Filter by search term
const searchedCollection = computed(() => {
  const term = search.value.toLowerCase()
  return props.items.filter(
    item =>
      item.title.toLowerCase().includes(term)
      || item.benchmark_id.toLowerCase().includes(term),
  )
})

// Total rows for pagination
const totalRows = computed(() => searchedCollection.value.length)

// Route path based on type
const routeBase = computed(() => (props.type === 'stig' ? '/stigs' : '/srgs'))

/**
 * Show delete confirmation modal
 */
function showDeleteConfirmation(item: IBenchmarkListItem) {
  itemToDelete.value = item
  showDeleteModal.value = true
}

/**
 * Execute delete after confirmation
 */
function executeDelete() {
  if (itemToDelete.value) {
    emit('delete', itemToDelete.value.id)
    showDeleteModal.value = false
    itemToDelete.value = null
  }
}

/**
 * Cancel delete
 */
function cancelDelete() {
  showDeleteModal.value = false
  itemToDelete.value = null
}
</script>

<template>
  <div>
    <!-- Search -->
    <div class="row">
      <div class="col-6">
        <div class="input-group">
          <span class="input-group-text">
            <i class="bi bi-search" aria-hidden="true" />
          </span>
          <input
            id="benchmarkSearch"
            v-model="search"
            type="text"
            class="form-control"
            :placeholder="`Search ${typeLabel} by title or ID...`"
          >
        </div>
      </div>
    </div>
    <br>
    <BTable
      id="benchmarks-table"
      :items="searchedCollection"
      :fields="tableFields"
      :per-page="perPage"
      :current-page="currentPage"
    >
      <!-- Benchmark ID with router link -->
      <template #cell(benchmark_id)="{ item }">
        <router-link :to="`${routeBase}/${item.id}`">
          {{ item.benchmark_id }}
        </router-link>
      </template>
      <!-- Actions column -->
      <template #cell(actions)="{ item }">
        <BButton
          v-if="isAdmin"
          class="float-end mt-1"
          variant="danger"
          @click="showDeleteConfirmation(item)"
        >
          <i class="bi bi-trash" aria-hidden="true" />
          Remove
        </BButton>
      </template>
    </BTable>
    <!-- Pagination controls -->
    <BPagination
      v-model="currentPage"
      :total-rows="totalRows"
      :per-page="perPage"
      aria-controls="benchmarks-table"
    />
    <!-- Delete Confirmation Modal -->
    <BModal
      v-model="showDeleteModal"
      :title="`Remove ${typeLabel}`"
      ok-variant="danger"
      ok-title="Remove"
      @ok="executeDelete"
      @cancel="cancelDelete"
      @hidden="cancelDelete"
    >
      <p>
        Are you sure you want to remove this {{ typeLabel }} from Vulcan?
      </p>
      <p v-if="itemToDelete" class="text-muted">
        <strong>{{ itemToDelete.benchmark_id }}</strong> - {{ itemToDelete.title }}
      </p>
    </BModal>
  </div>
</template>
