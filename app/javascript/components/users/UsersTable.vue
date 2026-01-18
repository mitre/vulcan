<script setup lang="ts">
/**
 * UsersTable.vue
 *
 * Displays a table of users with search, pagination, role management, and delete actions.
 * Uses BaseTable for consistent table UI.
 */
import type { IUser } from '@/types'
import { computed } from 'vue'
import ActionMenu from '@/components/shared/ActionMenu.vue'
import BaseTable from '@/components/shared/BaseTable.vue'
import DeleteModal from '@/components/shared/DeleteModal.vue'
import { useBaseTable, useDeleteConfirmation, useRailsForm } from '@/composables'

const props = defineProps<{
  users: IUser[]
}>()

// Rails form utilities (CSRF token + form submission)
const { csrfToken, submitDelete } = useRailsForm()

// Use composable for table state
const { search, currentPage, paginatedItems, totalRows } = useBaseTable({
  items: computed(() => props.users),
  searchFields: ['name', 'email'] as (keyof IUser)[],
})

// Delete confirmation with composable
const {
  showModal: showDeleteModal,
  itemToDelete: userToDelete,
  isDeleting: deleting,
  confirmDelete,
  executeDelete,
} = useDeleteConfirmation<IUser>({
  onDelete: (user) => {
    submitDelete(`/users/${user.id}`)
  },
})

// Column definitions
const columns = [
  { key: 'name', label: 'User' },
  { key: 'provider', label: 'Type' },
  { key: 'role', label: 'Role' },
  { key: 'actions', label: '', thClass: 'text-end', tdClass: 'text-end' },
]

// Action menu items
function getActions() {
  return [
    { id: 'delete', label: 'Remove User', icon: 'bi-trash', variant: 'danger' as const },
  ]
}

/**
 * Get provider display text
 */
function getProviderText(user: IUser) {
  return user.provider ? `${user.provider.toUpperCase()} User` : 'Local User'
}

/**
 * Handle role change - submit form
 */
function handleRoleChange(user: IUser) {
  const form = document.getElementById(`User-${user.id}`) as HTMLFormElement | null
  if (form) {
    form.submit()
  }
}

/**
 * Handle action menu selection
 */
function handleAction(actionId: string, user: IUser) {
  if (actionId === 'delete') {
    confirmDelete(user)
  }
}
</script>

<template>
  <div>
    <!-- Table information -->
    <p class="mb-3">
      <strong>User Count:</strong> <span>{{ props.users.length }}</span>
    </p>

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
      <!-- Name column with email -->
      <template #cell-name="{ item }">
        {{ item.name }}
        <br>
        <small class="text-body-secondary">{{ item.email }}</small>
      </template>

      <!-- Provider column -->
      <template #cell-provider="{ item }">
        {{ getProviderText(item) }}
      </template>

      <!-- Role column with inline select -->
      <template #cell-role="{ item }">
        <form :id="`User-${item.id}`" :action="`/users/${item.id}`" method="post">
          <input type="hidden" name="_method" value="put">
          <input type="hidden" name="authenticity_token" :value="csrfToken">
          <select
            v-model="item.admin"
            class="form-select form-select-sm"
            name="user[admin]"
            style="width: auto;"
            @change="handleRoleChange(item)"
          >
            <option :value="false">
              user
            </option>
            <option :value="true">
              admin
            </option>
          </select>
        </form>
      </template>

      <!-- Actions column -->
      <template #cell-actions="{ item }">
        <ActionMenu
          :actions="getActions()"
          @action="handleAction($event, item)"
        />
      </template>
    </BaseTable>

    <!-- Delete Confirmation Modal -->
    <DeleteModal
      v-model="showDeleteModal"
      title="Remove User"
      :item-name="userToDelete?.name"
      message="Are you sure you want to permanently remove this user?"
      :loading="deleting"
      confirm-button-text="Remove"
      @confirm="executeDelete"
    />
  </div>
</template>
