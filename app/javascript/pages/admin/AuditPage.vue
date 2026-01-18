<script setup lang="ts">
/**
 * Admin Audit Log Page
 *
 * Audit log viewer with filters, search, and pagination.
 * Uses: API → Store → Composable → Page architecture
 */

import { onMounted, ref, watch } from 'vue'
import PageSpinner from '@/components/shared/PageSpinner.vue'
import { useAudits } from '@/composables'
import { formatRelative } from '@/composables/useDateTime'
import { getActionVariant } from '@/types'

const {
  audits,
  pagination,
  filterOptions,
  filters,
  loading,
  error,
  auditCount,
  currentPage,
  totalPages,
  auditableTypes,
  auditActions,
  fetchAudits,
  setFilters,
  clearFilters,
  goToPage,
} = useAudits()

// Local filter state (bound to inputs, synced to store)
const selectedUser = ref<string>('')
const selectedAction = ref<string>('')
const selectedType = ref<string>('')
const startDate = ref<string>('')
const endDate = ref<string>('')

// Watch local filters and sync to store
watch([selectedUser, selectedAction, selectedType, startDate, endDate], () => {
  setFilters({
    user_id: selectedUser.value || undefined,
    action_type: selectedAction.value || undefined,
    auditable_type: selectedType.value || undefined,
    from_date: startDate.value || undefined,
    to_date: endDate.value || undefined,
  })
})

// Reset filters
function resetFilters() {
  selectedUser.value = ''
  selectedAction.value = ''
  selectedType.value = ''
  startDate.value = ''
  endDate.value = ''
  clearFilters()
}

// Format changes summary for display
function formatChanges(summary: string | undefined): string {
  if (!summary) return ''
  return summary.length > 50 ? `${summary.slice(0, 50)}...` : summary
}

onMounted(() => fetchAudits())
</script>

<template>
  <div class="admin-audit">
    <div class="d-flex justify-content-between align-items-center mb-4">
      <h1 class="h3 mb-0">
        <i class="bi bi-journal-text me-2" />
        Audit Log
      </h1>

      <BButton variant="outline-secondary" disabled title="Coming soon">
        <i class="bi bi-download me-1" />
        Export CSV
      </BButton>
    </div>

    <!-- Filters -->
    <div class="row g-2 mb-3">
      <div class="col-md-2">
        <BFormSelect v-model="selectedType" size="sm">
          <option value="">
            All Types
          </option>
          <option v-for="type in auditableTypes" :key="type" :value="type">
            {{ type }}
          </option>
        </BFormSelect>
      </div>
      <div class="col-md-2">
        <BFormSelect v-model="selectedAction" size="sm">
          <option value="">
            All Actions
          </option>
          <option v-for="action in auditActions" :key="action" :value="action">
            {{ action }}
          </option>
        </BFormSelect>
      </div>
      <div class="col-md-2">
        <BFormInput
          v-model="startDate"
          type="date"
          size="sm"
          placeholder="Start date"
        />
      </div>
      <div class="col-md-2">
        <BFormInput
          v-model="endDate"
          type="date"
          size="sm"
          placeholder="End date"
        />
      </div>
      <div class="col-md-2">
        <BButton variant="outline-secondary" size="sm" class="w-100" @click="resetFilters">
          <i class="bi bi-x-lg me-1" />
          Reset
        </BButton>
      </div>
      <div class="col-md-2 text-end text-muted small align-self-center">
        {{ auditCount }} entries
      </div>
    </div>

    <!-- Loading state -->
    <PageSpinner v-if="loading" message="Loading audit log..." />

    <!-- Error state -->
    <BAlert v-else-if="error" variant="danger" show>
      {{ error }}
      <BButton size="sm" variant="outline-danger" class="ms-2" @click="fetchAudits()">
        Retry
      </BButton>
    </BAlert>

    <!-- Audit table -->
    <template v-else>
      <div class="table-responsive">
        <table class="table table-hover table-sm align-middle">
          <thead class="table-light">
            <tr>
              <th style="width: 120px">
                Time
              </th>
              <th style="width: 150px">
                User
              </th>
              <th style="width: 80px">
                Action
              </th>
              <th>Entity</th>
              <th>Changes</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="audit in audits" :key="audit.id">
              <td class="small text-muted text-nowrap">
                {{ formatRelative(audit.created_at) }}
              </td>
              <td class="small">
                {{ audit.user_name }}
              </td>
              <td>
                <BBadge :variant="getActionVariant(audit.action)" class="text-uppercase">
                  {{ audit.action }}
                </BBadge>
              </td>
              <td>
                <span class="text-muted">{{ audit.auditable_type }}</span>
                <span class="ms-1 small text-secondary">
                  #{{ audit.auditable_id }}
                </span>
              </td>
              <td class="small text-muted text-truncate" style="max-width: 200px">
                {{ formatChanges(audit.changes_summary) }}
              </td>
            </tr>
            <tr v-if="!audits.length">
              <td colspan="5" class="text-center text-muted py-4">
                No audit entries found
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination -->
      <div v-if="pagination && totalPages > 1" class="d-flex justify-content-between align-items-center mt-3">
        <small class="text-muted">
          Page {{ currentPage }} of {{ totalPages }} ({{ auditCount }} total)
        </small>
        <BPagination
          :model-value="currentPage"
          :total-rows="pagination.total"
          :per-page="pagination.per_page"
          size="sm"
          class="mb-0"
          @update:model-value="goToPage"
        />
      </div>
    </template>
  </div>
</template>
