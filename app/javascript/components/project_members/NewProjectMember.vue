<template>
  <div id="NewProjectMemberCard">
    <b-row>
      <b-col class="d-flex">
        <b-input-group>
          <b-input-group-prepend>
            <b-input-group-text><i class="mdi mdi-magnify" aria-hidden="true"></i></b-input-group-text>
          </b-input-group-prepend>
          <vue-simple-suggest
            v-model="search"
            :list="available_members"
            :filter-by-query="true"
            display-attribute="email"
            placeholder="Search for a user by email..."
            @select="setSelectedUser"
            ref="userSearch"
          />
        </b-input-group>
      </b-col>
    </b-row>
    <div v-if="selectedUser">
      <br />
      <b-row>
        <b-col>
          Choose a role
          <hr id="RoleDivider"/>
        </b-col>
      </b-row>
      <b-row :key="role" v-for="(role, index) in available_roles">
        <b-col>
          <!-- <b-form-radio :key="role" v-for="role in available_roles"  name="role" :value="role">{{ role }}</b-form-radio> -->
          <div class="d-flex role-row">
            <span>
              <input class="form-check-input role-input"
                     type="radio"
                     name="roles"
                     :value="role"
                     @click="setSelectedRole(role)"
              >
            </span>
            <div>
              <h5 class="d-flex flex-items-center role-label">{{ capitalizeRole(role) }}</h5>
              <span><small class="muted role-description">{{ roleDescriptions[index] }}</small></span>
            </div>
          </div>
        </b-col>
      </b-row>
    </div>
    <br />
    <b-row>
      <b-col>
        <form :action="formAction()" method="post">
          <input type="hidden" id="NewProjectMemberAuthenticityToken" name="authenticity_token" :value="authenticityToken"/>
          <input type="hidden" id="NewProjectMemberEmail" name="user_id" v-model="selectedRole"/>
          <input type="hidden" id="NewProjectMemberRole" name="role" v-model="selectedUser"/>
          <b-button block
                    type="submit"
                    variant="primary"
                    :disabled="isSubmitDisabled"
                    :href="formAction()"
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
import VueSimpleSuggest from 'vue-simple-suggest';
import 'vue-simple-suggest/dist/styles.css';
import capitalize from 'lodash/capitalize';

export default {
  name: 'NewProjectMember',
  components: {
    VueSimpleSuggest
  },
  props: {
    project: {
      type: Object,
      required: true
    },
    available_members: {
      type: Array,
      required: true,
    },
    available_roles: {
      type: Array,
      required: true,
    }
  },
  data: function () {
    return {
      search: "",
      selectedUser: null,
      selectedRole: null,
      roleDescriptions: [
        'Edit, comment, and mark Controls as requiring review. Cannot sign-off or approve changes to a Control. Great for individual contributors.',
        'Author and approve changes to a Control.',
        'Full control of a Project. Lock Controls, revert controls, and manage project members.'
      ]
    }
  },
  computed: {
    authenticityToken: function() {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    },
    searchedAvailableMembers: function() {
      let downcaseSearch = this.search.toLowerCase()
      return this.available_members.filter(pm => pm.email.toLowerCase().includes(downcaseSearch));
    },
    isSubmitDisabled: function() {
      return !((this.selectedUser !== null) && (this.selectedRole !== null))
    }
  },
  methods: {
    capitalizeRole: function(roleString) {
      return capitalize(roleString);
    },
    setSelectedRole: function(role) {
      this.selectedRole = role;
    },
    setSelectedUser: function() {
      this.selectedUser = this.$refs.userSearch.selected
    },
    formAction: function() {
      return `/projects/${this.project.id}/project_members`
    }
  }
}
</script>

<style scoped>
#NewProjectMemberCard {
  padding: 1em;
  margin: 1em;
}

#RoleDivider {
  margin-top: 0.25rem;
}

.role-row {
  margin-bottom: 1rem;
}

.role-input {
  margin-left: 0rem;
  margin-right: 1rem;
  margin-top: 0rem;
  position: inherit;
}

.role-label {
  margin-bottom: 0;
  line-height: 1;
  font-size: 14px;
  font-weight: 700;
}

.role-description {
  line-height: 1;
}
</style>
