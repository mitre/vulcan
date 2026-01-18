<script setup lang="ts">
/**
 * BenchmarkTable.vue
 *
 * Unified table component for both STIGs and SRGs.
 * Uses BaseTable for consistent table UI with search, pagination, and row actions.
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
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import ActionMenu from '@/components/shared/ActionMenu.vue'
import BaseTable from '@/components/shared/BaseTable.vue'
import DeleteModal from '@/components/shared/DeleteModal.vue'
import { useBaseTable, useDeleteConfirmation } from '@/composables'

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

const router = useRouter()

// Use composable for table state
const { search, currentPage, paginatedItems, totalRows } = useBaseTable({
  items: computed(() => props.items),
  searchFields: ['title', 'benchmark_id'] as (keyof IBenchmarkListItem)[],
})

// Delete confirmation with composable
const {
  showModal: showDeleteModal,
  itemToDelete,
  confirmDelete,
  executeDelete,
} = useDeleteConfirmation<IBenchmarkListItem>({
  onDelete: (item) => {
    emit('delete', item.id)
  },
})

// Type-specific labels
const typeLabel = computed(() => {
  switch (props.type) {
    case 'stig': return 'STIG'
    case 'srg': return 'SRG'
    case 'component': return 'Component'
    default: return ''
  }
})

// Route path based on type - components link to requirements editor
const routeBase = computed(() => {
  switch (props.type) {
    case 'stig': return '/stigs'
    case 'srg': return '/srgs'
    case 'component': return '/components'
    default: return ''
  }
})

// Components link to /controls, STIGs/SRGs link to show page
function getItemRoute(item: IBenchmarkListItem) {
  if (props.type === 'component') {
    return `/components/${item.id}/controls`
  }
  return `${routeBase.value}/${item.id}`
}

// Column definitions
const columns = computed(() => {
  const cols = [
    { key: 'benchmark_id', label: `${typeLabel.value} ID` },
    { key: 'title', label: 'Title' },
    { key: 'version', label: 'Version' },
    { key: 'date', label: props.type === 'stig' ? 'Benchmark Date' : 'Release Date' },
  ]

  if (props.isAdmin) {
    cols.push({ key: 'actions', label: '', thClass: 'text-end', tdClass: 'text-end' })
  }

  return cols
})

// Action menu items
function getActions() {
  return [
    { id: 'view', label: `View ${typeLabel.value}`, icon: 'bi-eye' },
    { id: 'delete', label: `Remove ${typeLabel.value}`, icon: 'bi-trash', variant: 'danger' as const, dividerBefore: true },
  ]
}

/**
 * Handle action menu selection
 */
function handleAction(actionId: string, item: IBenchmarkListItem) {
  switch (actionId) {
    case 'view':
      router.push(getItemRoute(item))
      break
    case 'delete':
      confirmDelete(item)
      break
  }
}
</script>

<template>
  <div>
    <BaseTable
      :items="paginatedItems"
      :columns="columns"
      :total-rows="totalRows"
      :current-page="currentPage"
      :search="search"
      :search-placeholder="`Search ${typeLabel} by title or ID...`"
      @update:search="search = $event"
      @update:current-page="currentPage = $event"
    >
      <!-- Benchmark ID with router link -->
      <template #cell-benchmark_id="{ item }">
        <router-link :to="getItemRoute(item)">
          {{ item.benchmark_id }}
        </router-link>
      </template>

      <!-- Actions column -->
      <template #cell-actions="{ item }">
        <ActionMenu
          v-if="isAdmin"
          :actions="getActions()"
          @action="handleAction($event, item)"
        />
      </template>
    </BaseTable>

    <!-- Delete Confirmation Modal -->
    <DeleteModal
      v-model="showDeleteModal"
      :title="`Remove ${typeLabel}`"
      :item-name="itemToDelete ? `${itemToDelete.benchmark_id} - ${itemToDelete.title}` : ''"
      :message="`Are you sure you want to remove this ${typeLabel} from Vulcan?`"
      confirm-button-text="Remove"
      @confirm="executeDelete"
    />
  </div>
</template>
