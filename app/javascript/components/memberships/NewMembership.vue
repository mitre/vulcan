<template>
  <div>
    <b-row>
      <b-col class="d-flex">
        <template v-if="!selectedUser">
          <b-input-group>
            <b-input-group-prepend>
              <b-input-group-text
                ><i class="mdi mdi-magnify" aria-hidden="true"
              /></b-input-group-text>
            </b-input-group-prepend>
            <vue-simple-suggest
              ref="userSearch"
              v-model="search"
              :list="available_members"
              :filter-by-query="true"
              display-attribute="email"
              placeholder="Search for a user by email..."
              :styles="userSearchStyles"
              @select="setSelectedUser($refs.userSearch.selected)"
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
import VueSimpleSuggest from "vue-simple-suggest";
import "vue-simple-suggest/dist/styles.css";
import capitalize from "lodash/capitalize";

export default {
  name: "NewMembership",
  components: {
    VueSimpleSuggest,
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
  },
  data: function () {
    return {
      search: "",
      selectedUser: null,
      selectedRole: null,
      roleDescriptions: [
        "Read only access to the Project or Component",
        "Edit, comment, and mark Controls as requiring review. Cannot sign-off or approve changes to a Control. Great for individual contributors.",
        "Author and approve changes to a Control.",
        "Full control of a Project or Component. Lock Controls, revert controls, and manage members.",
      ],
      userSearchStyles: {
        vueSimpleSuggest: "userSearchVueSimpleSuggest",
        inputWrapper: "",
        defaultInput: "",
        suggestions: "",
        suggestItem: "",
      },
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

.userSearchVueSimpleSuggest {
  flex: 1;
}

.role-description {
  line-height: 1;
}
</style>
