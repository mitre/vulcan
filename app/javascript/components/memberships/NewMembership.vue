<script>
import capitalize from 'lodash/capitalize'
import SimpleTypeahead from 'vue3-simple-typeahead'
import 'vue3-simple-typeahead/dist/vue3-simple-typeahead.css'

export default {
  name: 'NewMembership',
  components: {
    SimpleTypeahead,
  },
  props: {
    membership_type: {
      type: String,
      required: true,
    },
    membership_id: {
      type: Number,
      required: true,
    },
    available_members: {
      type: Array,
      required: true,
    },
    available_roles: {
      type: Array,
      required: true,
    },
    selected_member: {
      type: Object,
      required: false,
    },
    access_request_id: {
      type: Number,
      required: false,
    },
  },
  data() {
    return {
      selectedUser: this.selected_member,
      selectedRole: null,
      roleDescriptions: [
        'Read only access to the Project or Component',
        'Edit, comment, and mark Controls as requiring review. Cannot sign-off or approve changes to a Control. Great for individual contributors.',
        'Author and approve changes to a Control.',
        'Full control of a Project or Component. Lock Controls, revert controls, and manage members.',
      ],
    }
  },
  computed: {
    authenticityToken() {
      return document.querySelector('meta[name=\'csrf-token\']').getAttribute('content')
    },
    isSubmitDisabled() {
      return !(this.selectedUser !== null && this.selectedRole !== null)
    },
    selectedUserId() {
      return this.selectedUser?.id
    },
  },
  methods: {
    capitalizeRole(roleString) {
      return capitalize(roleString)
    },
    setSelectedRole(role) {
      this.selectedRole = role
    },
    setSelectedUser(user) {
      this.selectedUser = user
    },
    clearSelectedUser() {
      this.selectedUser = null
      if (this.$refs.userSearch) {
        this.$refs.userSearch.clearInput()
      }
    },
    userProjection(user) {
      return user.email || ''
    },
    formAction() {
      return `/memberships/`
    },
  },
}
</script>

<template>
  <div>
    <b-row>
      <b-col class="d-flex">
        <template v-if="!selectedUser">
          <b-input-group>
            <b-input-group-text><i class="bi bi-search" aria-hidden="true" /></b-input-group-text>
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
          </b-input-group>
        </template>
        <template v-else>
          <b-alert
            show
            variant="info"
            dismissible
            class="w-100 mb-0"
            @dismissed="clearSelectedUser"
          >
            <p class="mb-0">
              <b>{{ selectedUser.name }}</b>
            </p>
            <p class="mb-0">
              {{ selectedUser.email }}
            </p>
          </b-alert>
        </template>
      </b-col>
    </b-row>
    <div v-if="selectedUser">
      <br>
      <b-row>
        <b-col>
          Choose a role
          <hr class="mt-1">
        </b-col>
      </b-row>
      <b-row v-for="(role, index) in available_roles" :key="role">
        <b-col>
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
        </b-col>
      </b-row>
    </div>
    <br>
    <b-row>
      <b-col>
        <form :action="formAction()" method="post">
          <input id="NewProjectMemberAuthenticityToken" type="hidden" name="authenticity_token" :value="authenticityToken">
          <input id="NewMembershipMembershipType" type="hidden" name="membership[membership_type]" :value="membership_type">
          <input id="NewMembershipMembershipId" type="hidden" name="membership[membership_id]" :value="membership_id">
          <input id="NewMembershipEmail" type="hidden" name="membership[user_id]" :value="selectedUserId">
          <input id="access_request_id" type="hidden" name="membership[access_request_id]" :value="access_request_id">
          <input id="NewMembershipRole" type="hidden" name="membership[role]" :value="selectedRole">
          <b-button block type="submit" variant="primary" :disabled="isSubmitDisabled" rel="nofollow">
            Add User to Project
          </b-button>
        </form>
      </b-col>
    </b-row>
  </div>
</template>

<style scoped>
.flex-grow-1 { flex-grow: 1; }
.role-input { position: inherit; }
.role-label { line-height: 1; font-size: 14px; font-weight: 700; }
.role-description { line-height: 1; }
</style>
