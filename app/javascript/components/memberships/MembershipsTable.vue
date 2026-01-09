<script setup lang="ts">
/**
 * MembershipsTable.vue
 *
 * Displays tables for project/component memberships:
 * - Pending access requests (if editable)
 * - Current members with search, pagination, role management, and delete actions
 * Uses BTable from Bootstrap-Vue-Next with custom cell slots.
 */
import type { IAvailableMember, IMembership, MemberRole, MembershipType } from '@/types'
import type { IProjectAccessRequest } from '@/types/access-request'
import type { TableFieldRaw } from 'bootstrap-vue-next'
import axios from 'axios'
import { BButton, BModal, BPagination, BTable } from 'bootstrap-vue-next'
import { computed, ref } from 'vue'
import ActionMenu from '@/components/shared/ActionMenu.vue'
import DeleteModal from '@/components/shared/DeleteModal.vue'
import SearchInput from '@/components/shared/SearchInput.vue'
import { useAppToast } from '@/composables/useToast'
import { useBaseTable, useDeleteConfirmation, useRailsForm } from '@/composables'
import NewMembership from './NewMembership.vue'

const props = withDefaults(
  defineProps<{
    memberships: IMembership[]
    access_requests?: IProjectAccessRequest[]
    membership_type: MembershipType
    membership_id: number
    editable?: boolean
    available_roles?: MemberRole[]
    available_members?: IAvailableMember[]
    memberships_count: number
    header_text?: string
  }>(),
  {
    access_requests: () => [],
    editable: false,
    available_roles: () => ['viewer', 'author', 'reviewer', 'admin'],
    available_members: () => [],
    header_text: 'Members',
  },
)

// Toast notifications
const toast = useAppToast()

// Rails form utilities (CSRF token + form submission)
const { csrfToken, submitDelete } = useRailsForm()

// Use composable for table state (pagination + search)
const { search, currentPage, paginatedItems, totalRows, perPage } = useBaseTable({
  items: computed(() => props.memberships),
  searchFields: ['name', 'email'] as (keyof IMembership)[],
})

// Modal state
const showNewMemberModal = ref(false)
const selectedMember = ref<IAvailableMember | null>(null)
const accessRequestId = ref<number | null>(null)
const newMembershipRef = ref<InstanceType<typeof NewMembership> | null>(null)

// Delete confirmation with composable
const {
  showModal: showDeleteModal,
  itemToDelete: memberToDelete,
  isDeleting: deleting,
  confirmDelete,
  executeDelete,
} = useDeleteConfirmation<IMembership>({
  onDelete: (member) => {
    submitDelete(`/memberships/${member.id}`)
  },
})

// Column definitions - BTable format
const tableFields = computed<TableFieldRaw<IMembership>[]>(() => {
  const fields: TableFieldRaw<IMembership>[] = [
    { key: 'name', label: 'User', sortable: true },
    { key: 'role', label: 'Role', sortable: true },
  ]

  if (props.editable) {
    fields.push({ key: 'actions', label: '', thClass: 'text-end', tdClass: 'text-end' })
  }

  return fields
})

// Pending access request columns
const requestColumns = [
  { key: 'name', label: 'User', sortable: true },
  { key: 'actions', label: '', thClass: 'text-end', tdClass: 'text-end' },
]

// Users with pending access requests
const pendingMembers = computed(() => {
  return props.available_members.filter(member =>
    props.access_requests.some(request => request.user_id === member.id),
  )
})

/**
 * Get access request ID for a member
 */
function getAccessRequestId(member: IAvailableMember): number | undefined {
  return props.access_requests.find(request => request.user_id === member.id)?.id
}

/**
 * Handle role change - submit form
 */
function handleRoleChange(membership: IMembership) {
  const form = document.getElementById(`ProjectMember-${membership.id}`) as HTMLFormElement | null
  if (form) {
    form.submit()
  }
}

/**
 * Accept access request - open modal with pre-selected member
 */
function acceptRequest(member: IAvailableMember) {
  console.log('MembershipsTable.acceptRequest called with:', member)
  console.log('Available access_requests:', props.access_requests)
  selectedMember.value = member
  accessRequestId.value = getAccessRequestId(member) ?? null
  console.log('Found accessRequestId:', accessRequestId.value)
  showNewMemberModal.value = true
}

/**
 * Reject access request via axios
 */
async function rejectRequest(member: IAvailableMember) {
  const requestId = getAccessRequestId(member)
  if (!requestId) return

  try {
    await axios.delete(`/projects/${props.membership_id}/project_access_requests/${requestId}`)
    toast.success(`${member.name}'s request has been rejected.`, 'Request Rejected')
    // Reload the page to update the access requests list
    window.location.reload()
  }
  catch (error: any) {
    console.error('Failed to reject request:', error)
    toast.error(error.response?.data?.error || 'Failed to reject request. Please try again.')
  }
}

/**
 * Reset modal state
 */
function resetModal() {
  selectedMember.value = null
  accessRequestId.value = null
}

/**
 * Open new member modal
 */
function openNewMemberModal() {
  selectedMember.value = null
  accessRequestId.value = null
  showNewMemberModal.value = true
}

/**
 * Submit the new member form
 */
function submitNewMember() {
  if (newMembershipRef.value) {
    newMembershipRef.value.submitForm()
  }
}

/**
 * Get actions for a member row
 */
function getActions() {
  return [
    { id: 'delete', label: 'Remove Member', icon: 'bi-trash', variant: 'danger' as const },
  ]
}

/**
 * Handle action menu selection
 */
function handleAction(actionId: string, member: IMembership) {
  if (actionId === 'delete') {
    confirmDelete(member)
  }
}

// Expose methods for parent component
defineExpose({
  acceptRequest,
})
</script>

<template>
  <div>
    <!-- Members Header -->
    <div class="d-flex justify-content-between align-items-center mb-3">
      <h2 class="mb-0">
        {{ header_text }}
        <span class="badge bg-info ms-2">{{ memberships_count }}</span>
      </h2>

      <BButton
        v-if="editable && available_members && available_roles"
        variant="primary"
        @click="openNewMemberModal"
      >
        <i class="bi bi-person-plus me-1" aria-hidden="true" />
        Invite Member
      </BButton>
    </div>

    <!-- Members Table -->
    <div class="table-wrapper">
      <!-- Search Input -->
      <div class="d-flex justify-content-between align-items-center mb-3">
        <div class="col-md-6">
          <SearchInput
            :model-value="search"
            placeholder="Search members by name or email..."
            @update:model-value="search = $event"
          />
        </div>
      </div>

      <!-- BTable -->
      <BTable
        :items="paginatedItems"
        :fields="tableFields"
        striped
        hover
        responsive
        @row-clicked="() => {}"
      >
        <!-- Name column -->
        <template #cell(name)="{ item }">
          {{ item.name }}
          <br>
          <small class="text-body-secondary">{{ item.email }}</small>
        </template>

        <!-- Role column -->
        <template #cell(role)="{ item }">
          <template v-if="editable && available_roles">
            <form :id="`ProjectMember-${item.id}`" :action="`/memberships/${item.id}`" method="post">
              <input type="hidden" name="_method" value="put">
              <input type="hidden" name="authenticity_token" :value="csrfToken">
              <select
                v-model="item.role"
                class="form-select form-select-sm"
                name="membership[role]"
                style="width: auto;"
                @click.stop
                @change="handleRoleChange(item)"
              >
                <option v-for="role in available_roles" :key="role" :value="role">
                  {{ role }}
                </option>
              </select>
            </form>
          </template>
          <template v-else>
            {{ item.role }}
          </template>
        </template>

        <!-- Actions column -->
        <template v-if="editable" #cell(actions)="{ item }">
          <ActionMenu
            :actions="getActions()"
            @action="handleAction($event, item)"
          />
        </template>

        <!-- Empty state -->
        <template #empty>
          <div class="text-center text-muted py-4">
            No members found
          </div>
        </template>
      </BTable>

      <!-- Pagination -->
      <BPagination
        v-if="totalRows > perPage"
        :model-value="currentPage"
        :total-rows="totalRows"
        :per-page="perPage"
        class="mt-3"
        @update:model-value="currentPage = $event"
      />
    </div>

    <!-- Invite Member Modal -->
    <BModal
      v-model="showNewMemberModal"
      size="md"
      title="Invite Project Member"
      centered
      ok-title="Add User to Project"
      :ok-disabled="newMembershipRef?.isSubmitDisabled ?? true"
      @ok="submitNewMember"
      @hidden="resetModal"
    >
      <NewMembership
        ref="newMembershipRef"
        :membership_type="membership_type"
        :membership_id="membership_id"
        :available_members="available_members"
        :available_roles="available_roles"
        :selected_member="selectedMember"
        :access_request_id="accessRequestId"
      />
    </BModal>

    <!-- Delete Confirmation Modal -->
    <DeleteModal
      v-model="showDeleteModal"
      title="Remove Member"
      :item-name="memberToDelete?.name"
      message="Are you sure you want to remove this member from the project?"
      :loading="deleting"
      confirm-button-text="Remove"
      @confirm="executeDelete"
    />
  </div>
</template>
