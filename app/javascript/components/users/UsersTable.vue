<script>
import FormMixinVue from '../../mixins/FormMixin.vue'

export default {
  name: 'UsersTable',
  mixins: [FormMixinVue],
  props: {
    users: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      search: '',
      perPage: 10,
      currentPage: 1,
      fields: [
        { key: 'name', label: 'User' },
        { key: 'provider', label: 'Type' },
        'role',
        { key: 'actions', label: '' },
      ],
    }
  },
  computed: {
    // Search users based on name and email
    searchedUsers() {
      const downcaseSearch = this.search.toLowerCase()
      return this.users.filter(
        user =>
          user.email.toLowerCase().includes(downcaseSearch)
          || user.name.toLowerCase().includes(downcaseSearch),
      )
    },
    // Used by b-pagination to know how many total rows there are
    rows() {
      return this.searchedUsers.length
    },
    // Total number of users in the system
    userCount() {
      return this.users.length
    },
  },
  methods: {
    // Automatically submit the form when a user selects a form option
    adminStatusChanged(event, user) {
      document.getElementById(this.formId(user)).submit()
    },
    // The text that should appear in the 'Type' column
    typeColumn(user) {
      return user.provider === null ? 'Local User' : `${user.provider.toUpperCase()} User`
    },
    // Generator for a unique form id for the user role dropdown
    formId(user) {
      return `User-${user.id}`
    },
    // Path to POST/DELETE to when updating/deleting a user
    formAction(user) {
      return `/users/${user.id}`
    },
  },
}
</script>

<template>
  <div>
    <!-- Table information -->
    <p>
      <b>User Count:</b> <span>{{ userCount }}</span>
    </p>

    <!-- User search -->
    <div class="row">
      <div class="col-6">
        <b-input-group>
          <template #prepend>
            <b-input-group-text>
              <i class="bi bi-search" aria-hidden="true" />
            </b-input-group-text>
          </template>
          <input
            id="userSearch"
            v-model="search"
            type="text"
            class="form-control"
            placeholder="Search users by name or email..."
          >
        </b-input-group>
      </div>
    </div>

    <br>

    <!-- User table -->
    <b-table
      id="users-table"
      :items="searchedUsers"
      :fields="fields"
      :per-page="perPage"
      :current-page="currentPage"
    >
      <!-- Column template for Name -->
      <template #cell(name)="data">
        {{ data.item.name }}
        <br>
        <small>{{ data.item.email }}</small>
      </template>

      <!-- Column template for Type -->
      <template #cell(provider)="data">
        {{ typeColumn(data.item) }}
      </template>

      <!-- Column template for Role -->
      <template #cell(role)="data">
        <form :id="formId(data.item)" :action="formAction(data.item)" method="post">
          <input type="hidden" name="_method" value="put">
          <input type="hidden" name="authenticity_token" :value="authenticityToken">
          <select
            v-model="data.item.admin"
            class="form-control"
            name="user[admin]"
            @change="adminStatusChanged($event, data.item)"
          >
            <option value="false">
              user
            </option>
            <option value="true">
              admin
            </option>
          </select>
        </form>
      </template>

      <!-- Column template for Actions -->
      <template #cell(actions)="data">
        <b-button
          class="float-end"
          variant="danger"
          data-confirm="Are you sure you want to permanently remove this user?"
          data-method="delete"
          :href="formAction(data.item)"
          rel="nofollow"
        >
          <i class="bi bi-trash" aria-hidden="true" />
          Remove
        </b-button>
      </template>
    </b-table>

    <!-- Pagination controls -->
    <b-pagination
      v-model="currentPage"
      :total-rows="rows"
      :per-page="perPage"
      aria-controls="users-table"
    />
  </div>
</template>

<style scoped></style>
