<template>
  <div class="m-3 p-3">
    <b-row>
      <b-col>
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
            :filter="memberSearchFilter"
            display-attribute="email"
            placeholder="Search for a user by email..."
            :styles="userSearchStyles"
            @select="setSelectedUser"
          />
        </b-input-group>
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
          <div class="mb-3">
            <span>
              <input
                class="form-check-input role-input ml-0 mt-0 mr-3"
                type="radio"
                name="roles"
                :value="role"
                @click="setSelectedRole(role)"
              />
            </span>
            <div>
              <h5 class="d-flex flex-items-center role-label mb-0">{{ capitalizeRole(role) }}</h5>
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
        <form :action="formAction" method="post">
          <input
            id="NewProjectMemberAuthenticityToken"
            type="hidden"
            name="authenticity_token"
            :value="authenticityToken"
          />
          <input
            id="NewProjectMemberEmail"
            v-model="selectedUser"
            type="hidden"
            name="project_member[user_id]"
          />
          <input
            id="NewProjectMemberRole"
            v-model="selectedRole"
            type="hidden"
            name="project_member[role]"
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
import FormMixinVue from "../../mixins/FormMixin.vue";
import VueSimpleSuggest from "vue-simple-suggest";
import "vue-simple-suggest/dist/styles.css";
import capitalize from "lodash/capitalize";

export default {
  name: "NewProjectMember",
  components: {
    VueSimpleSuggest,
  },
  mixins: [FormMixinVue],
  props: {
    project: {
      type: Object,
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
        "Full control of a Project. Lock Controls, revert controls, and manage project members.",
        "Author and approve changes to a Control.",
        "Edit, comment, and mark Controls as requiring review. Cannot sign-off or approve changes to a Control. Great for individual contributors.",
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
    isSubmitDisabled: function () {
      return !(this.selectedUser !== null && this.selectedRole !== null);
    },
    formAction: function () {
      return "/projects/" + this.project.id + "/project_members";
    },
  },
  methods: {
    memberSearchFilter: function (user, search) {
      if (user && search) {
        let downcaseSearch = search.toLowerCase();
        return (
          user.email.toLowerCase().includes(downcaseSearch) ||
          user.name.toLowerCase().includes(downcaseSearch)
        );
      }
      return false;
    },
    capitalizeRole: function (roleString) {
      return capitalize(roleString);
    },
    setSelectedRole: function (role) {
      this.selectedRole = role;
    },
    setSelectedUser: function () {
      this.selectedUser = this.$refs.userSearch.selected?.id;
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
</style>
