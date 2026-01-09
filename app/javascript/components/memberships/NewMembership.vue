<script setup lang="ts">
/**
 * NewMembership.vue
 *
 * Form for adding a new member to a project/component.
 * Uses typeahead search for user selection and radio buttons for role selection.
 */
import type { IAvailableMember, MemberRole, MembershipType } from '@/types'
import { BAlert, BButton, BCol, BInputGroup, BInputGroupText, BRow } from 'bootstrap-vue-next'
import capitalize from 'lodash/capitalize'
import { computed, ref } from 'vue'
import SimpleTypeahead from 'vue3-simple-typeahead'
import 'vue3-simple-typeahead/dist/vue3-simple-typeahead.css'
import { useRailsForm } from '@/composables'

const props = withDefaults(
  defineProps<{
    membership_type: MembershipType
    membership_id: number
    available_members: IAvailableMember[]
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
const userSearch = ref<InstanceType<typeof SimpleTypeahead> | null>(null)

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

function setSelectedUser(user: IAvailableMember) {
  selectedUser.value = user
}

function clearSelectedUser() {
  selectedUser.value = null
  if (userSearch.value) {
    userSearch.value.clearInput()
  }
}

function userProjection(user: IAvailableMember) {
  return user.email || ''
}

function formAction() {
  return `/memberships/`
}
</script>

<template>
  <div>
    <BRow>
      <BCol class="d-flex">
        <template v-if="!selectedUser">
          <BInputGroup>
            <BInputGroupText><i class="bi bi-search" aria-hidden="true" /></BInputGroupText>
            <SimpleTypeahead
              id="userSearch"
              ref="userSearch"
              class="flex-grow-1"
              placeholder="Search for a user by email..."
              :items="available_members"
              :min-input-length="1"
              :item-projection="userProjection"
              @select-item="setSelectedUser"
            />
          </BInputGroup>
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
    <br>
    <BRow>
      <BCol>
        <form :action="formAction()" method="post">
          <input id="NewProjectMemberAuthenticityToken" type="hidden" name="authenticity_token" :value="csrfToken">
          <input id="NewMembershipMembershipType" type="hidden" name="membership[membership_type]" :value="membership_type">
          <input id="NewMembershipMembershipId" type="hidden" name="membership[membership_id]" :value="membership_id">
          <input id="NewMembershipEmail" type="hidden" name="membership[user_id]" :value="selectedUserId">
          <input id="access_request_id" type="hidden" name="membership[access_request_id]" :value="access_request_id">
          <input id="NewMembershipRole" type="hidden" name="membership[role]" :value="selectedRole">
          <BButton block type="submit" variant="primary" :disabled="isSubmitDisabled" rel="nofollow">
            Add User to Project
          </BButton>
        </form>
      </BCol>
    </BRow>
  </div>
</template>

<style scoped>
.flex-grow-1 { flex-grow: 1; }
.role-input { position: inherit; }
.role-label { line-height: 1; font-size: 14px; font-weight: 700; }
.role-description { line-height: 1; }
</style>
