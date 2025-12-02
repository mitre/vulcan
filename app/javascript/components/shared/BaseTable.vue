<script setup lang="ts" generic="T extends Record<string, unknown> & { id: number }">
/**
 * BaseTable.vue
 *
 * Unified table component providing consistent table UI across the application.
 * Includes built-in search, pagination, and slot-based cell customization.
 *
 * Usage:
 *   <BaseTable
 *     :items="paginatedItems"
 *     :columns="columns"
 *     :total-rows="totalRows"
 *     v-model:search="search"
 *     v-model:current-page="currentPage"
 *     search-placeholder="Search users..."
 *   >
 *     <template #cell-name="{ item }">
 *       <router-link :to="`/users/${item.id}`">{{ item.name }}</router-link>
 *     </template>
 *     <template #cell-actions="{ item }">
 *       <ActionMenu :actions="getActions(item)" @action="handleAction($event, item)" />
 *     </template>
 *   </BaseTable>
 */
import type { ColumnDef } from '@/types'
import { BPagination, BTable } from 'bootstrap-vue-next'
import { computed } from 'vue'
import SearchInput from './SearchInput.vue'

// Re-export for convenience
export type { ColumnDef } from '@/types'

const props = withDefaults(
  defineProps<{
    /** Items to display (should be paginated slice) */
    items: T[]
    /** Column definitions */
    columns: ColumnDef<T>[]
    /** Total rows for pagination (before pagination) */
    totalRows: number
    /** Current page (v-model) */
    currentPage?: number
    /** Items per page */
    perPage?: number
    /** Search term (v-model) */
    search?: string
    /** Placeholder for search input */
    searchPlaceholder?: string
    /** Show loading state */
    loading?: boolean
    /** Striped rows */
    striped?: boolean
    /** Hover highlight */
    hover?: boolean
    /** Text shown when table is empty */
    emptyText?: string
    /** Show search input */
    showSearch?: boolean
    /** Show pagination */
    showPagination?: boolean
    /** Make table responsive */
    responsive?: boolean
    /** Caption for accessibility (screen readers) */
    caption?: string
  }>(),
  {
    currentPage: 1,
    perPage: 10,
    search: '',
    searchPlaceholder: 'Search...',
    loading: false,
    striped: true,
    hover: true,
    emptyText: 'No items found',
    showSearch: true,
    showPagination: true,
    responsive: true,
  },
)

const emit = defineEmits<{
  'update:search': [value: string]
  'update:currentPage': [value: number]
  'row-click': [item: T]
}>()

// Convert columns to BTable fields format
const tableFields = computed(() =>
  props.columns.map(col => ({
    key: String(col.key),
    label: col.label ?? String(col.key),
    sortable: col.sortable ?? false,
    class: col.class,
    thClass: col.thClass,
    tdClass: col.tdClass,
  })),
)

function handlePageChange(page: number) {
  emit('update:currentPage', page)
}

function handleRowClick(item: T) {
  emit('rowClick', item)
}
</script>

<template>
  <div class="base-table">
    <!-- Header with search and slot for custom actions -->
    <div class="d-flex justify-content-between align-items-center mb-3">
      <!-- Search Input -->
      <div v-if="showSearch" class="col-md-6">
        <SearchInput
          :model-value="search"
          :placeholder="searchPlaceholder"
          @update:model-value="emit('update:search', $event)"
        />
      </div>

      <!-- Header actions slot -->
      <div>
        <slot name="header-actions" />
      </div>
    </div>

    <!-- Filters slot -->
    <slot name="filters" />

    <!-- Loading overlay -->
    <div v-if="loading" class="text-center py-4">
      <div class="spinner-border text-primary" role="status">
        <span class="visually-hidden">Loading...</span>
      </div>
    </div>

    <!-- Table -->
    <BTable
      v-else
      :items="items"
      :fields="tableFields"
      :striped="striped"
      :hover="hover"
      :responsive="responsive"
      :caption="caption"
      caption-top
      @row-clicked="handleRowClick"
    >
      <!-- Dynamic cell slots - allow parent to customize any column -->
      <template
        v-for="col in columns"
        :key="col.key"
        #[`cell(${col.key})`]="{ item }"
      >
        <slot :name="`cell-${String(col.key)}`" :item="(item as T)" :column="col">
          {{ item[col.key as keyof T] }}
        </slot>
      </template>

      <!-- Empty state -->
      <template #empty>
        <slot name="empty">
          <div class="text-center py-4 text-body-secondary">
            <i class="bi bi-inbox display-4 d-block mb-2" />
            {{ emptyText }}
          </div>
        </slot>
      </template>
    </BTable>

    <!-- Pagination -->
    <BPagination
      v-if="showPagination && totalRows > perPage"
      :model-value="currentPage"
      :total-rows="totalRows"
      :per-page="perPage"
      class="mt-3"
      @update:model-value="handlePageChange"
    />
  </div>
</template>
