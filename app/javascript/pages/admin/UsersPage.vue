<script setup lang="ts">
/**
 * Admin Users Page
 *
 * User management with list, search, filters, and actions.
 * Uses: API → Store → Composable → Page architecture
 */

import type { IUser } from '@/types'
import { onMounted } from 'vue'
import PageSpinner from '@/components/shared/PageSpinner.vue'
import { useConfirmModal, useUsers } from '@/composables'

const {
  users,
  pagination,
  filters,
  loading,
  error,
  userCount,
  currentPage,
  totalPages,
  fetchUsers,
  setFilters,
  goToPage,
  lockUser,
  unlockUser,
  resetPassword,
  deleteUser,
} = useUsers()

// Confirmation modals
const { confirm, confirmDelete, confirmWarning } = useConfirmModal()

// Format date
function formatDate(dateStr: string | null | undefined): string {
  if (!dateStr) return 'Never'
  return new Date(dateStr).toLocaleDateString()
}

// Provider badge color
function providerVariant(provider: string | null | undefined): string {
  const p = provider || 'local'
  const variants: Record<string, string> = {
    local: 'primary',
    oidc: 'success',
    ldap: 'info',
    github: 'dark',
  }
  return variants[p] || 'secondary'
}

// Actions
async function handleLock(user: IUser) {
  const confirmed = await confirmWarning(`Lock account for ${user.name}?`, 'Lock User Account')
  if (!confirmed) return
  await lockUser(user.id)
}

async function handleUnlock(user: IUser) {
  await unlockUser(user.id)
}

async function handleResetPassword(user: IUser) {
  const confirmed = await confirm(`Send password reset email to ${user.email}?`, 'Reset Password')
  if (!confirmed) return
  await resetPassword(user.id)
}

async function handleDelete(user: IUser) {
  const confirmed = await confirmDelete(`This cannot be undone.`, user.name)
  if (!confirmed) return
  await deleteUser(user.id)
}

// Filter handlers
function handleSearch(e: Event) {
  const target = e.target as HTMLInputElement
  setFilters({ search: target.value })
}

function handleProviderFilter(e: Event) {
  const target = e.target as HTMLSelectElement
  setFilters({ provider: target.value as 'all' | 'local' | 'external' })
}

function handleRoleFilter(e: Event) {
  const target = e.target as HTMLSelectElement
  setFilters({ role: target.value as 'all' | 'admin' | 'user' })
}

onMounted(() => fetchUsers())
</script>

<template>
  <div class="admin-users">
    <div class="d-flex justify-content-between align-items-center mb-4">
      <h1 class="h3 mb-0">
        <i class="bi bi-people me-2" />
        Users
      </h1>

      <BButton variant="primary" disabled title="Coming soon">
        <i class="bi bi-person-plus me-1" />
        Invite User
      </BButton>
    </div>

    <!-- Filters -->
    <div class="row g-2 mb-3">
      <div class="col-md-4">
        <BFormInput
          :model-value="filters.search"
          placeholder="Search users..."
          type="search"
          @input="handleSearch"
        />
      </div>
      <div class="col-md-3">
        <BFormSelect :model-value="filters.provider" @change="handleProviderFilter">
          <option value="all">
            All Types
          </option>
          <option value="local">
            Local
          </option>
          <option value="external">
            External (OIDC/LDAP)
          </option>
        </BFormSelect>
      </div>
      <div class="col-md-3">
        <BFormSelect :model-value="filters.role" @change="handleRoleFilter">
          <option value="all">
            All Roles
          </option>
          <option value="admin">
            Admins
          </option>
          <option value="user">
            Users
          </option>
        </BFormSelect>
      </div>
      <div class="col-md-2 text-end text-muted small align-self-center">
        {{ userCount }} users
      </div>
    </div>

    <!-- Loading state -->
    <PageSpinner v-if="loading" message="Loading users..." />

    <!-- Error state -->
    <BAlert v-else-if="error" variant="danger" show>
      {{ error }}
      <BButton size="sm" variant="outline-danger" class="ms-2" @click="fetchUsers()">
        Retry
      </BButton>
    </BAlert>

    <!-- Users table -->
    <div v-else class="table-responsive">
      <table class="table table-hover align-middle">
        <thead class="table-light">
          <tr>
            <th>Name</th>
            <th>Email</th>
            <th>Type</th>
            <th>Role</th>
            <th>Status</th>
            <th>Last Sign In</th>
            <th class="text-end">
              Actions
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="user in users" :key="user.id">
            <td>{{ user.name }}</td>
            <td>
              <code class="small">{{ user.email }}</code>
            </td>
            <td>
              <BBadge :variant="providerVariant(user.provider)">
                {{ user.provider || 'local' }}
              </BBadge>
            </td>
            <td>
              <BBadge v-if="user.admin" variant="warning">
                Admin
              </BBadge>
              <span v-else class="text-muted">User</span>
            </td>
            <td>
              <BBadge v-if="user.locked" variant="danger">
                Locked
              </BBadge>
              <BBadge v-else-if="!user.confirmed" variant="secondary">
                Unconfirmed
              </BBadge>
              <BBadge v-else variant="success">
                Active
              </BBadge>
            </td>
            <td class="small text-muted">
              {{ formatDate(user.last_sign_in_at) }}
            </td>
            <td class="text-end">
              <BDropdown size="sm" variant="outline-secondary" no-caret>
                <template #button-content>
                  <i class="bi bi-three-dots-vertical" />
                </template>

                <BDropdownItem v-if="user.locked" @click="handleUnlock(user)">
                  <i class="bi bi-unlock me-2" />
                  Unlock
                </BDropdownItem>
                <BDropdownItem v-else @click="handleLock(user)">
                  <i class="bi bi-lock me-2" />
                  Lock
                </BDropdownItem>

                <BDropdownItem
                  v-if="!user.provider || user.provider === 'local'"
                  @click="handleResetPassword(user)"
                >
                  <i class="bi bi-key me-2" />
                  Reset Password
                </BDropdownItem>

                <BDropdownDivider />

                <BDropdownItem class="text-danger" @click="handleDelete(user)">
                  <i class="bi bi-trash me-2" />
                  Delete
                </BDropdownItem>
              </BDropdown>
            </td>
          </tr>
          <tr v-if="!users.length">
            <td colspan="7" class="text-center text-muted py-4">
              No users found
            </td>
          </tr>
        </tbody>
      </table>

      <!-- Pagination -->
      <div v-if="pagination && totalPages > 1" class="d-flex justify-content-between align-items-center mt-3">
        <div class="text-muted small">
          Page {{ currentPage }} of {{ totalPages }}
        </div>
        <BPagination
          :model-value="currentPage"
          :total-rows="pagination.total"
          :per-page="pagination.per_page"
          @update:model-value="goToPage"
        />
      </div>
    </div>
  </div>
</template>
