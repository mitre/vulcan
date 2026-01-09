<script setup lang="ts">
/**
 * NewMembership.vue
 *
 * Form for adding a new member to a project/component.
 * Uses typeahead search for user selection and radio buttons for role selection.
 */
import type { IAvailableMember, MemberRole, MembershipType } from '@/types'
import { BAlert, BButton, BCol, BFormInput, BInputGroup, BInputGroupText, BRow, BSpinner } from 'bootstrap-vue-next'
import capitalize from 'lodash/capitalize'
import { computed, ref, watch } from 'vue'
import { searchUsers } from '@/apis/members.api'
import { useRailsForm } from '@/composables'
import { useDebounceFn } from '@vueuse/core'

const props = withDefaults(
  defineProps<{
    membership_type: MembershipType
    membership_id: number
    available_members?: IAvailableMember[] // Optional, legacy prop
    available_roles: MemberRole[]
    selected_member?: IAvailableMember | null
    access_request_id?: number | null
  }>(),
  {
    available_members: () => [],
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
const showResults = ref(false)
const highlightedIndex = ref(-1)

// Watch for prop changes (when Accept is clicked, parent passes selected_member)
watch(() => props.selected_member, (newMember) => {
  if (newMember) {
    selectedUser.value = newMember
  }
})

// Debounced search function
const performSearch = useDebounceFn(async (query: string) => {
  if (query.length < 2) {
    searchResults.value = []
    isSearching.value = false
    showResults.value = false
    return
  }

  isSearching.value = true
  try {
    const response = await searchUsers({
      projectId: props.membership_id,
      query,
    })
    searchResults.value = response.users
    showResults.value = true
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

function selectUser(user: IAvailableMember) {
  selectedUser.value = user
  searchQuery.value = ''
  searchResults.value = []
  showResults.value = false
  highlightedIndex.value = -1
}

function clearSelectedUser() {
  selectedUser.value = null
  searchQuery.value = ''
  searchResults.value = []
  showResults.value = false
  highlightedIndex.value = -1
}

function formAction() {
  return `/memberships/`
}

function handleInputFocus() {
  if (searchQuery.value.length >= 2 && searchResults.value.length > 0) {
    showResults.value = true
  }
}

function handleClickOutside() {
  setTimeout(() => {
    showResults.value = false
    highlightedIndex.value = -1
  }, 200)
}

function handleKeyDown(event: KeyboardEvent) {
  if (!showResults.value || searchResults.value.length === 0)
    return

  switch (event.key) {
    case 'ArrowDown':
      event.preventDefault()
      highlightedIndex.value = Math.min(highlightedIndex.value + 1, searchResults.value.length - 1)
      break
    case 'ArrowUp':
      event.preventDefault()
      highlightedIndex.value = Math.max(highlightedIndex.value - 1, 0)
      break
    case 'Enter':
      event.preventDefault()
      if (highlightedIndex.value >= 0 && highlightedIndex.value < searchResults.value.length) {
        selectUser(searchResults.value[highlightedIndex.value])
      }
      break
    case 'Escape':
      event.preventDefault()
      showResults.value = false
      highlightedIndex.value = -1
      break
  }
}

// Watch for results changes and reset highlighted index
watch(searchResults, () => {
  highlightedIndex.value = -1
})

// Form ref for parent to submit
const formRef = ref<HTMLFormElement | null>(null)

// Reset all state (called when modal is canceled)
function reset() {
  selectedUser.value = null
  selectedRole.value = null
  searchQuery.value = ''
  searchResults.value = []
  showResults.value = false
  highlightedIndex.value = -1
}

// Expose for parent component
defineExpose({
  isSubmitDisabled,
  submitForm: () => {
    if (formRef.value) {
      formRef.value.submit()
    }
  },
  reset,
})
</script>

<template>
  <div>
    <BRow>
      <BCol class="position-relative">
        <template v-if="!selectedUser">
          <BInputGroup>
            <BInputGroupText><i class="bi bi-search" aria-hidden="true" /></BInputGroupText>
            <BFormInput
              v-model="searchQuery"
              placeholder="Search for a user by name or email (minimum 2 characters)..."
              autocomplete="off"
              @focus="handleInputFocus"
              @blur="handleClickOutside"
              @keydown="handleKeyDown"
            />
            <BInputGroupText v-if="isSearching">
              <BSpinner small />
            </BInputGroupText>
          </BInputGroup>

          <!-- Search Results Dropdown -->
          <div
            v-if="showResults && searchResults.length > 0"
            class="search-dropdown position-absolute w-100 mt-1 border rounded shadow-sm"
            style="z-index: 1000; max-height: 300px; overflow-y: auto;"
          >
            <div
              v-for="(user, index) in searchResults"
              :key="user.id"
              class="search-result-item p-2 cursor-pointer"
              :class="{ 'highlighted': index === highlightedIndex }"
              @mousedown="selectUser(user)"
              @mouseenter="highlightedIndex = index"
            >
              <div class="fw-bold">
                {{ user.name }}
              </div>
              <small class="text-muted">{{ user.email }}</small>
            </div>
          </div>

          <!-- No Results Message -->
          <div
            v-if="showResults && searchResults.length === 0 && searchQuery.length >= 2 && !isSearching"
            class="search-dropdown position-absolute w-100 mt-1 border rounded shadow-sm p-3 text-muted text-center"
            style="z-index: 1000;"
          >
            No users found matching "{{ searchQuery }}"
          </div>
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
.cursor-pointer { cursor: pointer; }

/* Search dropdown - supports light/dark mode */
.search-dropdown {
  background-color: var(--bs-body-bg);
  color: var(--bs-body-color);
  border-color: var(--bs-border-color);
}

.search-result-item {
  transition: background-color 0.15s ease-in-out;
  border-bottom: 1px solid var(--bs-border-color);
}

.search-result-item:last-child {
  border-bottom: none;
}

.search-result-item:hover,
.search-result-item.highlighted {
  background-color: var(--bs-primary);
  color: var(--bs-white);
}

.search-result-item:hover .text-muted,
.search-result-item.highlighted .text-muted {
  color: rgba(255, 255, 255, 0.8) !important;
}
</style>
