# BaseTable Architecture Plan

## Overview

Unified table infrastructure to eliminate duplication across 5 table components.

## Current State Analysis

### Tables Inventory

| Table | Vue Version | Location |
|-------|-------------|----------|
| ProjectsTable | Vue 2 | `components/projects/ProjectsTable.vue` |
| UsersTable | Vue 2 | `components/users/UsersTable.vue` |
| MembershipsTable | Vue 2 | `components/memberships/MembershipsTable.vue` |
| BenchmarkTable | Vue 3 | `components/benchmarks/BenchmarkTable.vue` |
| RequirementsTable | Vue 3 | `components/requirements/RequirementsTable.vue` |

### Common Patterns (DRY Opportunities)

1. **Search Input** - All 5 tables have identical search with icon + input
2. **Pagination** - All use `perPage: 10`, `currentPage`, `totalRows`
3. **Computed Filtering** - Same pattern: `items.filter(item => field.toLowerCase().includes(term))`
4. **Delete Confirmation** - Modal or Rails data attributes

### Table-Specific Features

#### ProjectsTable
- **Search fields**: name
- **Filters**: 3 toggles (All/My/Discoverable) with localStorage persistence
- **Actions**: View, Edit (modal), Request Access, Cancel Request, Delete
- **Special**: Text truncation with expand/collapse

#### UsersTable
- **Search fields**: name, email
- **Filters**: None
- **Actions**: Change Role (inline select), Remove User
- **Special**: Inline role dropdown with form submission

#### MembershipsTable
- **Search fields**: name, email
- **Filters**: None
- **Actions**: Change Role, Remove Member, Accept/Reject Request
- **Special**: Two sub-tables (pending requests + members)

#### BenchmarkTable (already Vue 3)
- **Search fields**: title, benchmark_id
- **Filters**: None
- **Actions**: View, Delete (ActionMenu ✓)
- **Special**: Type-aware labels (STIG vs SRG)

#### RequirementsTable (complex, migrate later)
- **Search fields**: title, rule_id
- **Filters**: Multiple (status, severity, group)
- **Actions**: Inline status select, various controls
- **Special**: Grouping, sorting, progress bar, nested rows

---

## Architecture Design

### 1. Composable: `useBaseTable.ts`

```typescript
// app/javascript/composables/useBaseTable.ts

import type { Ref, ComputedRef } from 'vue'
import { ref, computed, watch } from 'vue'

export interface BaseTableConfig<T> {
  items: Ref<T[]> | ComputedRef<T[]>
  searchFields: (keyof T)[]
  perPage?: number
  persistKey?: string // localStorage key for filter state
}

export function useBaseTable<T extends { id: number }>(config: BaseTableConfig<T>) {
  const search = ref('')
  const currentPage = ref(1)
  const perPage = ref(config.perPage ?? 10)

  // Filter by search term
  const filteredItems = computed(() => {
    const term = search.value.toLowerCase()
    if (!term) return config.items.value

    return config.items.value.filter(item =>
      config.searchFields.some(field => {
        const value = item[field]
        return String(value ?? '').toLowerCase().includes(term)
      })
    )
  })

  // Paginate results
  const paginatedItems = computed(() => {
    const start = (currentPage.value - 1) * perPage.value
    return filteredItems.value.slice(start, start + perPage.value)
  })

  const totalRows = computed(() => filteredItems.value.length)
  const totalPages = computed(() => Math.ceil(totalRows.value / perPage.value))
  const isEmpty = computed(() => filteredItems.value.length === 0)
  const hasResults = computed(() => filteredItems.value.length > 0)

  // Reset to page 1 when search changes
  watch(search, () => {
    currentPage.value = 1
  })

  // Optional localStorage persistence
  if (config.persistKey) {
    const stored = localStorage.getItem(config.persistKey)
    if (stored) {
      try {
        const parsed = JSON.parse(stored)
        if (parsed.search) search.value = parsed.search
        if (parsed.perPage) perPage.value = parsed.perPage
      } catch (e) {
        localStorage.removeItem(config.persistKey)
      }
    }

    watch([search, perPage], () => {
      localStorage.setItem(config.persistKey!, JSON.stringify({
        search: search.value,
        perPage: perPage.value,
      }))
    })
  }

  return {
    // State
    search,
    currentPage,
    perPage,

    // Computed
    filteredItems,
    paginatedItems,
    totalRows,
    totalPages,
    isEmpty,
    hasResults,
  }
}
```

### 2. Component: `BaseTable.vue`

```vue
<!-- app/javascript/components/shared/BaseTable.vue -->
<script setup lang="ts" generic="T extends { id: number }">
import { computed } from 'vue'
import { BPagination, BTable } from 'bootstrap-vue-next'
import ActionMenu from './ActionMenu.vue'
import type { ActionItem } from './ActionMenu.vue'

export interface ColumnDef<Item> {
  key: keyof Item | 'actions'
  label?: string
  sortable?: boolean
  class?: string
  thClass?: string
  tdClass?: string
}

const props = withDefaults(defineProps<{
  items: T[]
  columns: ColumnDef<T>[]
  totalRows: number
  currentPage: number
  perPage?: number
  search?: string
  searchPlaceholder?: string
  searchFields?: string[]
  loading?: boolean
  striped?: boolean
  hover?: boolean
  emptyText?: string
  showSearch?: boolean
  showPagination?: boolean
}>(), {
  perPage: 10,
  striped: true,
  hover: true,
  emptyText: 'No items found',
  showSearch: true,
  showPagination: true,
})

const emit = defineEmits<{
  'update:search': [value: string]
  'update:currentPage': [value: number]
  'action': [actionId: string, item: T]
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
  }))
)

function handleSearch(event: Event) {
  emit('update:search', (event.target as HTMLInputElement).value)
}

function handlePageChange(page: number) {
  emit('update:currentPage', page)
}
</script>

<template>
  <div class="base-table">
    <!-- Header with search and slot for actions -->
    <div class="d-flex justify-content-between align-items-center mb-3">
      <!-- Search Input -->
      <div v-if="showSearch" class="col-md-6">
        <div class="input-group">
          <span class="input-group-text">
            <i class="bi bi-search" />
          </span>
          <input
            type="text"
            class="form-control"
            :placeholder="searchPlaceholder || 'Search...'"
            :value="search"
            @input="handleSearch"
          >
        </div>
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
      @row-clicked="emit('row-click', $event)"
    >
      <!-- Dynamic cell slots -->
      <template v-for="col in columns" :key="col.key" #[`cell(${col.key})`]="{ item }">
        <slot :name="`cell-${String(col.key)}`" :item="item" :column="col">
          {{ item[col.key as keyof T] }}
        </slot>
      </template>

      <!-- Empty state -->
      <template #empty>
        <slot name="empty">
          <div class="text-center py-4 text-body-secondary">
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
      @update:model-value="handlePageChange"
    />
  </div>
</template>
```

### 3. Component: `SearchInput.vue`

```vue
<!-- app/javascript/components/shared/SearchInput.vue -->
<script setup lang="ts">
const props = withDefaults(defineProps<{
  modelValue: string
  placeholder?: string
  debounce?: number
}>(), {
  placeholder: 'Search...',
  debounce: 0,
})

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

let timeout: ReturnType<typeof setTimeout>

function handleInput(event: Event) {
  const value = (event.target as HTMLInputElement).value

  if (props.debounce > 0) {
    clearTimeout(timeout)
    timeout = setTimeout(() => emit('update:modelValue', value), props.debounce)
  } else {
    emit('update:modelValue', value)
  }
}
</script>

<template>
  <div class="input-group">
    <span class="input-group-text">
      <i class="bi bi-search" />
    </span>
    <input
      type="text"
      class="form-control"
      :placeholder="placeholder"
      :value="modelValue"
      @input="handleInput"
    >
  </div>
</template>
```

### 4. Component: `DeleteModal.vue`

```vue
<!-- app/javascript/components/shared/DeleteModal.vue -->
<script setup lang="ts">
import { BModal } from 'bootstrap-vue-next'

const props = withDefaults(defineProps<{
  modelValue: boolean
  title?: string
  itemName?: string
  loading?: boolean
}>(), {
  title: 'Confirm Delete',
})

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  'confirm': []
  'cancel': []
}>()

function handleConfirm() {
  emit('confirm')
}

function handleCancel() {
  emit('update:modelValue', false)
  emit('cancel')
}
</script>

<template>
  <BModal
    :model-value="modelValue"
    :title="title"
    @update:model-value="emit('update:modelValue', $event)"
    @hidden="handleCancel"
  >
    <p>
      Are you sure you want to delete
      <strong v-if="itemName">{{ itemName }}</strong>
      <span v-else>this item</span>?
    </p>
    <p class="text-body-secondary small">This action cannot be undone.</p>

    <template #footer>
      <button class="btn btn-secondary" @click="handleCancel">
        Cancel
      </button>
      <button
        class="btn btn-danger"
        :disabled="loading"
        @click="handleConfirm"
      >
        <span v-if="loading" class="spinner-border spinner-border-sm me-2" />
        Delete
      </button>
    </template>
  </BModal>
</template>
```

---

## Migration Examples

### BenchmarkTable Migration (simplest)

```vue
<!-- After migration -->
<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import BaseTable from '@/components/shared/BaseTable.vue'
import DeleteModal from '@/components/shared/DeleteModal.vue'
import { useBaseTable } from '@/composables/useBaseTable'

const props = defineProps<{
  type: 'stig' | 'srg'
  items: IBenchmarkListItem[]
  isAdmin: boolean
}>()

const emit = defineEmits<{ delete: [id: number] }>()
const router = useRouter()

const { search, currentPage, paginatedItems, totalRows } = useBaseTable({
  items: computed(() => props.items),
  searchFields: ['title', 'benchmark_id'],
})

const typeLabel = computed(() => props.type === 'stig' ? 'STIG' : 'SRG')
const routeBase = computed(() => props.type === 'stig' ? '/stigs' : '/srgs')

const columns = computed(() => [
  { key: 'benchmark_id', label: `${typeLabel.value} ID` },
  { key: 'title', label: 'Title' },
  { key: 'version', label: 'Version' },
  { key: 'date', label: props.type === 'stig' ? 'Benchmark Date' : 'Release Date' },
  ...(props.isAdmin ? [{ key: 'actions', label: '', tdClass: 'text-end' }] : []),
])

function getActions(item: IBenchmarkListItem) {
  return [
    { id: 'view', label: `View ${typeLabel.value}`, icon: 'bi-eye' },
    { id: 'delete', label: `Remove ${typeLabel.value}`, icon: 'bi-trash', variant: 'danger', dividerBefore: true },
  ]
}

function handleAction(actionId: string, item: IBenchmarkListItem) {
  if (actionId === 'view') router.push(`${routeBase.value}/${item.id}`)
  if (actionId === 'delete') showDeleteModal(item)
}
</script>

<template>
  <BaseTable
    :items="paginatedItems"
    :columns="columns"
    :total-rows="totalRows"
    :current-page="currentPage"
    :search="search"
    :search-placeholder="`Search ${typeLabel} by title or ID...`"
    @update:search="search = $event"
    @update:current-page="currentPage = $event"
    @action="handleAction"
  >
    <template #cell-benchmark_id="{ item }">
      <router-link :to="`${routeBase}/${item.id}`">
        {{ item.benchmark_id }}
      </router-link>
    </template>

    <template #cell-actions="{ item }">
      <ActionMenu
        v-if="isAdmin"
        :actions="getActions(item)"
        @action="handleAction($event, item)"
      />
    </template>
  </BaseTable>
</template>
```

### UsersTable Migration

```vue
<script setup lang="ts">
import { computed, ref } from 'vue'
import BaseTable from '@/components/shared/BaseTable.vue'
import DeleteModal from '@/components/shared/DeleteModal.vue'
import { useBaseTable } from '@/composables/useBaseTable'
import { useUsers } from '@/composables'

const props = defineProps<{ users: IUser[] }>()

const { search, currentPage, paginatedItems, totalRows } = useBaseTable({
  items: computed(() => props.users),
  searchFields: ['name', 'email'],
})

const columns = [
  { key: 'name', label: 'User' },
  { key: 'provider', label: 'Type' },
  { key: 'role', label: 'Role' },
  { key: 'actions', label: '', tdClass: 'text-end' },
]

function getActions(user: IUser) {
  return [
    { id: 'delete', label: 'Remove User', icon: 'bi-trash', variant: 'danger' },
  ]
}
</script>

<template>
  <BaseTable
    :items="paginatedItems"
    :columns="columns"
    :total-rows="totalRows"
    :current-page="currentPage"
    :search="search"
    search-placeholder="Search users by name or email..."
    @update:search="search = $event"
    @update:current-page="currentPage = $event"
  >
    <template #cell-name="{ item }">
      {{ item.name }}<br>
      <small class="text-body-secondary">{{ item.email }}</small>
    </template>

    <template #cell-provider="{ item }">
      {{ item.provider ? `${item.provider.toUpperCase()} User` : 'Local User' }}
    </template>

    <template #cell-role="{ item }">
      <select v-model="item.admin" class="form-select form-select-sm" @change="updateRole(item)">
        <option :value="false">user</option>
        <option :value="true">admin</option>
      </select>
    </template>

    <template #cell-actions="{ item }">
      <ActionMenu :actions="getActions(item)" @action="handleAction($event, item)" />
    </template>
  </BaseTable>
</template>
```

---

## Migration Order

1. **Create infrastructure** (1 hour)
   - `useBaseTable.ts`
   - `BaseTable.vue`
   - `SearchInput.vue`
   - `DeleteModal.vue`

2. **BenchmarkTable** (15-20 min) - Already Vue 3, simplest

3. **UsersTable** (20-30 min) - Simple, convert to Vue 3

4. **ProjectsTable** (30-45 min) - Multiple actions, filter toggles

5. **MembershipsTable** (30-40 min) - Two sub-tables

6. **RequirementsTable** - Keep separate for now (too complex)

**Total: 3-4 hours**

---

## Files to Create

```
app/javascript/
├── composables/
│   └── useBaseTable.ts          # NEW
├── components/
│   └── shared/
│       ├── ActionMenu.vue       # EXISTS ✓
│       ├── BaseTable.vue        # NEW
│       ├── SearchInput.vue      # NEW
│       └── DeleteModal.vue      # NEW
```

## Exports to Add

```typescript
// composables/index.ts
export { useBaseTable } from './useBaseTable'
```
