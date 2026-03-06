<template>
  <div>
    <b-row>
      <b-col class="d-flex">
        <template v-if="!selectedUser">
          <b-input-group>
            <b-input-group-prepend>
              <b-input-group-text><b-icon icon="search" aria-hidden="true" /></b-input-group-text>
            </b-input-group-prepend>
            <vue-multiselect
              v-model="multiSelectUser"
              :options="available_members"
              label="email"
              track-by="id"
              :searchable="true"
              :allow-empty="true"
              placeholder="Search for a user by email..."
              class="flex-grow-1"
              @input="setSelectedUser($event)"
            />
          </b-input-group>
        </template>
        <template v-else>
          <b-alert
            show
            variant="info"
            dismissible
            class="w-100 mb-0"
            @dismissed="setSelectedUser(null)"
          >
            <p class="mb-0">
              <b>{{ selectedUser.name }}</b>
            </p>
            <p class="mb-0">{{ selectedUser.email }}</p>
          </b-alert>
        </template>
      </b-col>
    </b-row>
    <div v-if="selectedUser">
      <br />
      <b-row>
        <b-col>
          Choose a role
          <hr class="mt-1" />
        </b-col>
      </b-row>
      <b-row v-for="(role, index) in available_roles" :key="role">
        <b-col>
          <!-- <b-form-radio :key="role" v-for="role in available_roles"  name="role" :value="role">{{ role }}</b-form-radio> -->
          <div class="d-flex mb-3">
            <span>
              <input
                class="form-check-input role-input mt-0 ml-0 mr-3"
                type="radio"
                name="roles"
                :value="role"
                @click="setSelectedRole(role)"
              />
            </span>
            <div>
              <h5 class="d-flex flex-items-center mb-0 role-label">{{ capitalizeRole(role) }}</h5>
              <span
                ><small class="muted role-description">{{ roleDescriptions[index] }}</small></span
              >
            </div>
          </div>
        </b-col>
      </b-row>
    </div>
    <br />
    <b-row>
      <b-col>
        <form :action="formAction()" method="post">
          <input
            id="NewProjectMemberAuthenticityToken"
            type="hidden"
            name="authenticity_token"
            :value="authenticityToken"
          />
          <input
            id="NewMembershipMembershipType"
            type="hidden"
            name="membership[membership_type]"
            :value="membership_type"
          />
          <input
            id="NewMembershipMembershipId"
            type="hidden"
            name="membership[membership_id]"
            :value="membership_id"
          />
          <input
            id="NewMembershipEmail"
            type="hidden"
            name="membership[user_id]"
            :value="selectedUserId"
          />
          <input
            id="access_request_id"
            type="hidden"
            name="membership[access_request_id]"
            :value="access_request_id"
          />
          <input
            id="NewMembershipRole"
            type="hidden"
            name="membership[role]"
            :value="selectedRole"
          />
          <b-button
            block
            type="submit"
            variant="primary"
            :disabled="isSubmitDisabled"
            rel="nofollow"
          >
            Add User to Project
          </b-button>
        </form>
      </b-col>
    </b-row>
  </div>
</template>

<script>
import VueMultiselect from "vue-multiselect";
import "vue-multiselect/dist/vue-multiselect.min.css";
import capitalize from "lodash/capitalize";
import { ROLE_DESCRIPTIONS } from "../../constants/terminology";

export default {
  name: "NewMembership",
  components: {
    VueMultiselect,
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
  data: function () {
    return {
      search: "",
      multiSelectUser: null,
      selectedUser: this.selected_member,
      selectedRole: null,
      roleDescriptions: ROLE_DESCRIPTIONS,
    };
  },
  computed: {
    authenticityToken: function () {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    },
    searchedAvailableMembers: function () {
      let downcaseSearch = this.search.toLowerCase();
      return this.available_members.filter((pm) => pm.email.toLowerCase().includes(downcaseSearch));
    },
    isSubmitDisabled: function () {
      return !(this.selectedUser !== null && this.selectedRole !== null);
    },
    selectedUserId: function () {
      return this.selectedUser?.id;
    },
  },
  methods: {
    capitalizeRole: function (roleString) {
      return capitalize(roleString);
    },
    setSelectedRole: function (role) {
      this.selectedRole = role;
    },
    setSelectedUser: function (user) {
      this.selectedUser = user;
      this.search = "";
    },
    formAction: function () {
      return `/memberships/`;
    },
  },
};
</script>

<style scoped>
.role-input {
  position: inherit;
}

.role-label {
  line-height: 1;
  font-size: 14px;
  font-weight: 700;
}

.role-description {
  line-height: 1;
}

.role-description {
  line-height: 1;
}
</style>
