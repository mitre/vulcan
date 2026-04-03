<template>
  <div>
    <!-- Table information -->
    <p>
      <b>User Count:</b> <span>{{ userCount }}</span>
    </p>

    <!-- User search -->
    <div class="row">
      <div class="col-6">
        <div class="input-group">
          <div class="input-group-prepend">
            <div class="input-group-text">
              <b-icon icon="search" aria-hidden="true" />
            </div>
          </div>
          <input
            id="userSearch"
            v-model="search"
            type="text"
            class="form-control"
            placeholder="Search users by name or email..."
            aria-label="Search users"
          />
        </div>
      </div>
    </div>

    <br />

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
        <br />
        <small>{{ data.item.email }}</small>
      </template>

      <!-- Column template for Type -->
      <template #cell(provider)="data">
        {{ typeColumn(data.item) }}
      </template>

      <!-- Column template for Role -->
      <template #cell(role)="data">
        <b-badge :variant="data.item.admin ? 'danger' : 'secondary'">
          {{ data.item.admin ? "Admin" : "User" }}
        </b-badge>
        <b-badge v-if="lockoutEnabled && data.item.locked_at" variant="warning" class="ml-1">
          Locked
        </b-badge>
      </template>

      <!-- Column template for Last Sign In -->
      <template #cell(last_sign_in_at)="data">
        {{ formatDate(data.item.last_sign_in_at) }}
      </template>

      <!-- Column template for Actions -->
      <template #cell(actions)="data">
        <b-button
          size="sm"
          variant="outline-secondary"
          class="mr-1"
          :aria-label="'Edit ' + data.item.name"
          @click="$emit('edit-user', data.item)"
        >
          <b-icon icon="pencil" aria-hidden="true" />
        </b-button>
        <b-button
          size="sm"
          variant="outline-danger"
          :aria-label="'Remove ' + data.item.name"
          @click="confirmDelete(data.item)"
        >
          <b-icon icon="trash" aria-hidden="true" />
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

    <!-- Delete Confirmation Modal -->
    <ConfirmDeleteModal
      v-model="showDeleteModal"
      :item-name="userToDelete ? userToDelete.email : ''"
      item-type="user"
      :is-deleting="isDeleting"
      warning-message="This action cannot be undone. All user data will be permanently removed."
      @confirm="handleDelete"
    />
  </div>
</template>

<script>
import axios from "axios";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import ConfirmDeleteModal from "../shared/ConfirmDeleteModal.vue";

export default {
  name: "UsersTable",
  components: { ConfirmDeleteModal },
  mixins: [FormMixinVue, AlertMixinVue],
  props: {
    users: {
      type: Array,
      required: true,
    },
    lockoutEnabled: {
      type: Boolean,
      default: false,
    },
  },
  data: function () {
    return {
      search: "",
      perPage: 10,
      currentPage: 1,
      showDeleteModal: false,
      userToDelete: null,
      isDeleting: false,
      fields: [
        { key: "name", label: "User", sortable: true },
        { key: "provider", label: "Type", sortable: true },
        { key: "role", label: "Role", sortable: true },
        { key: "last_sign_in_at", label: "Last Sign In", sortable: true },
        { key: "actions", label: "" },
      ],
    };
  },
  computed: {
    searchedUsers: function () {
      let downcaseSearch = this.search.toLowerCase();
      return this.users.filter(
        (user) =>
          (user.email || "").toLowerCase().includes(downcaseSearch) ||
          (user.name || "").toLowerCase().includes(downcaseSearch),
      );
    },
    rows: function () {
      return this.searchedUsers.length;
    },
    userCount: function () {
      return this.users.length;
    },
  },
  methods: {
    typeColumn: function (user) {
      return user.provider === null ? "Local User" : user.provider.toUpperCase() + " User";
    },
    formatDate(dateStr) {
      if (!dateStr) return "Never";
      const d = new Date(dateStr);
      return d.toLocaleDateString(undefined, {
        year: "numeric",
        month: "short",
        day: "numeric",
      });
    },
    confirmDelete(user) {
      this.userToDelete = user;
      this.showDeleteModal = true;
    },
    async handleDelete() {
      if (!this.userToDelete) return;
      this.isDeleting = true;

      try {
        const response = await axios.delete(`/users/${this.userToDelete.id}`);
        this.alertOrNotifyResponse(response);
        this.$emit("user-deleted", this.userToDelete);
      } catch (error) {
        this.alertOrNotifyResponse(error);
      } finally {
        this.isDeleting = false;
        this.showDeleteModal = false;
        this.userToDelete = null;
      }
    },
  },
};
</script>

<style scoped></style>
