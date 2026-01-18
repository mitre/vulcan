<script setup lang="ts">
/**
 * NewMembership.vue
 *
 * Form for adding a new member to a project/component.
 * Uses Reka UI Combobox for user selection and radio buttons for role selection.
 *
 * Built with Reka UI (https://reka-ui.com/) - Headless UI primitives
 */
import type { IAvailableMember, MemberRole, MembershipType } from '@/types'
import { useDebounceFn } from '@vueuse/core'
import { BAlert, BCol, BRow, BSpinner } from 'bootstrap-vue-next'
import capitalize from 'lodash/capitalize'
import {
  ComboboxAnchor,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxInput,
  ComboboxItem,
  ComboboxRoot,
} from 'reka-ui'
import { computed, ref, watch } from 'vue'
import { searchUsers } from '@/apis/members.api'
import { useRailsForm } from '@/composables'

const props = withDefaults(
  defineProps<{
    membership_type: MembershipType
    membership_id: number
    available_roles: MemberRole[]
    selected_member?: IAvailableMember | null
    access_request_id?: number | null
  }>(),
  {
    selected_member: null,
    access_request_id: null,
  },
)

const { csrfToken } = useRailsForm()

// State
const selectedUser = ref<IAvailableMember | null>(props.selected_member)
const selectedRole = ref<MemberRole | null>(null)
const searchQuery = ref('')
const searchResults = ref<IAvailableMember[]>([])
const isSearching = ref(false)
const open = ref(false)

// Watch for prop changes (when Accept is clicked, parent passes selected_member)
watch(() => props.selected_member, (newMember) => {
  if (newMember) {
    selectedUser.value = newMember
  }
})

// Debounced search function (Slack model: always search, even on empty)
const performSearch = useDebounceFn(async (query: string) => {
  isSearching.value = true
  try {
    const response = await searchUsers({
      projectId: props.membership_id,
      query,
    })
    searchResults.value = response.users
  }
  catch (error) {
    console.error('Failed to search users:', error)
    searchResults.value = []
  }
  finally {
    isSearching.value = false
  }
}, 300)

// Watch search input
watch(searchQuery, (newQuery) => {
  performSearch(newQuery)
})

// Trigger search on open (Slack model)
watch(open, (isOpen) => {
  if (isOpen && searchResults.value.length === 0) {
    performSearch(searchQuery.value)
  }
})

const roleDescriptions = [
  'Read only access to the Project or Component',
  'Edit, comment, and mark Controls as requiring review. Cannot sign-off or approve changes to a Control. Great for individual contributors.',
  'Author and approve changes to a Control.',
  'Full control of a Project or Component. Lock Controls, revert controls, and manage members.',
]

// Computed
const isSubmitDisabled = computed(() => {
  return !(selectedUser.value !== null && selectedRole.value !== null)
})

const selectedUserId = computed(() => selectedUser.value?.id)

// Methods
function capitalizeRole(roleString: string) {
  return capitalize(roleString)
}

function setSelectedRole(role: MemberRole) {
  selectedRole.value = role
}

function clearSelectedUser() {
  selectedUser.value = null
  searchQuery.value = ''
  searchResults.value = []
}

function formAction() {
  return `/memberships/`
}

// Reset all state (called when modal is canceled)
function reset() {
  selectedUser.value = null
  selectedRole.value = null
  searchQuery.value = ''
  searchResults.value = []
  open.value = false
}

// Form ref for parent to submit
const formRef = ref<HTMLFormElement | null>(null)

// Expose for parent component (and testing)
defineExpose({
  isSubmitDisabled,
  submitForm: () => {
    if (formRef.value) {
      formRef.value.submit()
    }
  },
  reset,
  // For testing Reka UI v-model bindings
  searchQuery,
  open,
})
</script>

<template>
  <div>
    <BRow>
      <BCol class="position-relative">
        <template v-if="!selectedUser">
          <!-- Reka UI Combobox -->
          <ComboboxRoot
            v-model="selectedUser"
            v-model:open="open"
            v-model:search-term="searchQuery"
            :display-value="(user: IAvailableMember) => user?.name || ''"
            class="combobox-root"
          >
            <ComboboxAnchor class="combobox-anchor">
              <div class="input-group">
                <span class="input-group-text">
                  <i class="bi bi-search" aria-hidden="true" />
                </span>
                <ComboboxInput
                  class="form-control"
                  placeholder="Search for a user by name or email..."
                  autocomplete="off"
                />
                <span v-if="isSearching" class="input-group-text">
                  <BSpinner small />
                </span>
              </div>
            </ComboboxAnchor>

            <ComboboxContent
              class="combobox-content shadow-sm"
            >
              <ComboboxEmpty class="combobox-empty">
                <template v-if="searchQuery">
                  No users found matching "{{ searchQuery }}"
                </template>
                <template v-else>
                  No available users to invite
                </template>
              </ComboboxEmpty>

              <ComboboxItem
                v-for="user in searchResults"
                :key="user.id"
                :value="user"
                class="combobox-item"
              >
                <div class="fw-bold">
                  {{ user.name }}
                </div>
                <small class="text-muted">{{ user.email }}</small>
              </ComboboxItem>
            </ComboboxContent>
          </ComboboxRoot>
        </template>

        <template v-else>
          <BAlert
            show
            variant="info"
            dismissible
            class="w-100 mb-0"
            @close="clearSelectedUser"
          >
            <p class="mb-0">
              <b>{{ selectedUser.name }}</b>
            </p>
            <p class="mb-0">
              {{ selectedUser.email }}
            </p>
          </BAlert>
        </template>
      </BCol>
    </BRow>

    <div v-if="selectedUser">
      <br>
      <BRow>
        <BCol>
          Choose a role
          <hr class="mt-1">
        </BCol>
      </BRow>
      <BRow v-for="(role, index) in available_roles" :key="role">
        <BCol>
          <div class="d-flex mb-3">
            <span>
              <input
                class="form-check-input role-input mt-0 ml-0 mr-3"
                type="radio"
                name="roles"
                :value="role"
                @click="setSelectedRole(role)"
              >
            </span>
            <div>
              <h5 class="d-flex flex-items-center mb-0 role-label">
                {{ capitalizeRole(role) }}
              </h5>
              <span><small class="muted role-description">{{ roleDescriptions[index] }}</small></span>
            </div>
          </div>
        </BCol>
      </BRow>
    </div>

    <!-- Hidden form for submission (parent will submit via modal footer) -->
    <form ref="formRef" :action="formAction()" method="post" style="display: none;">
      <input id="NewProjectMemberAuthenticityToken" type="hidden" name="authenticity_token" :value="csrfToken">
      <input id="NewMembershipMembershipType" type="hidden" name="membership[membership_type]" :value="membership_type">
      <input id="NewMembershipMembershipId" type="hidden" name="membership[membership_id]" :value="membership_id">
      <input id="NewMembershipEmail" type="hidden" name="membership[user_id]" :value="selectedUserId">
      <input id="access_request_id" type="hidden" name="membership[access_request_id]" :value="access_request_id">
      <input id="NewMembershipRole" type="hidden" name="membership[role]" :value="selectedRole">
    </form>
  </div>
</template>

<style scoped>
.flex-grow-1 { flex-grow: 1; }
.role-input { position: inherit; }
.role-label { line-height: 1; font-size: 14px; font-weight: 700; }
.role-description { line-height: 1; }

/* Reka UI Combobox Styling */
.combobox-root {
  position: relative;
  width: 100%;
}

.combobox-anchor {
  width: 100%;
}

.combobox-content {
  position: absolute;
  z-index: 1050;
  left: 0;
  right: 0;
  max-height: 300px;
  overflow-y: auto;
  background-color: var(--bs-body-bg);
  color: var(--bs-body-color);
  border: 1px solid var(--bs-border-color);
  border-radius: var(--bs-border-radius);
  margin-top: 0.5rem;
  box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.15);
}

.combobox-empty {
  padding: 1rem;
  text-align: center;
  color: var(--bs-secondary-color);
}

.combobox-item {
  padding: 0.5rem;
  cursor: pointer;
  border-bottom: 1px solid var(--bs-border-color);
  transition: background-color 0.15s ease-in-out;
}

.combobox-item:last-child {
  border-bottom: none;
}

.combobox-item:hover,
.combobox-item[data-highlighted] {
  background-color: var(--bs-primary);
  color: var(--bs-white);
}

.combobox-item:hover .text-muted,
.combobox-item[data-highlighted] .text-muted {
  color: rgba(255, 255, 255, 0.8) !important;
}
</style>
