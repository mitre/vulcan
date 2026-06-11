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
        <UserBadge :name="data.item.name" :email="data.item.email" :show-name="true" />
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
        <b-badge
          v-if="apiTokensEnabled && data.item.active_token_count > 0"
          variant="info"
          class="ml-1"
        >
          <b-icon icon="key" scale="0.8" /> {{ data.item.active_token_count }}
        </b-badge>
      </template>

      <!-- Column template for Last Sign In -->
      <template #cell(last_sign_in_at)="data">
        {{ formatDate(data.item.last_sign_in_at) }}
      </template>

      <!-- Column template for Actions -->
      <template #cell(actions)="data">
        <TableActionButtons
          :item-name="data.item.name"
          :show-edit="true"
          @edit="$emit('edit-user', data.item)"
          @delete="confirmDelete(data.item)"
        />
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
      @cancel="cancelDelete"
    />
  </div>
</template>

<script>
import { deleteUser } from "../../api/usersApi";
import { useToast } from "../../composables/useToast";
import ConfirmDeleteModal from "../shared/ConfirmDeleteModal.vue";
import TableActionButtons from "../shared/TableActionButtons.vue";
import UserBadge from "../shared/UserBadge.vue";
import { useDeleteConfirmation } from "../../composables/useDeleteConfirmation";
import { useTableSearch } from "../../composables/useTableSearch";

export default {
  name: "UsersTable",
  components: { ConfirmDeleteModal, TableActionButtons, UserBadge },
  props: {
    users: {
      type: Array,
      required: true,
    },
    lockoutEnabled: {
      type: Boolean,
      default: false,
    },
    apiTokensEnabled: {
      type: Boolean,
      default: false,
    },
  },
  setup(props) {
    const {
      showModal: showDeleteModal,
      itemToDelete: userToDelete,
      isDeleting,
      openModal: openDeleteModal,
      cancel: cancelDelete,
      confirm: confirmDeleteAction,
    } = useDeleteConfirmation();

    const { search, perPage, currentPage, filteredItems, totalRows } = useTableSearch(
      () => props.users,
      (user, q) =>
        (user.email || "").toLowerCase().includes(q) || (user.name || "").toLowerCase().includes(q),
    );

    const { alertOrNotifyResponse } = useToast();

    return {
      showDeleteModal,
      userToDelete,
      isDeleting,
      openDeleteModal,
      cancelDelete,
      confirmDeleteAction,
      search,
      perPage,
      currentPage,
      searchedUsers: filteredItems,
      rows: totalRows,
      alertOrNotifyResponse,
    };
  },
  data: function () {
    return {
      fields: [
        { key: "name", label: "User", sortable: true },
        { key: "provider", label: "Type", sortable: true },
        { key: "role", label: "Role", sortable: true },
        { key: "last_sign_in_at", label: "Last Sign In", sortable: true },
        { key: "actions", label: "", tdClass: "text-center align-middle" },
      ],
    };
  },
  computed: {
    userCount: function () {
      return this.users.length;
    },
  },
  methods: {
    typeColumn: function (user) {
      return user.provider ? user.provider.toUpperCase() + " User" : "Local User";
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
      this.openDeleteModal(user);
    },
    async handleDelete() {
      const { success, error } = await this.confirmDeleteAction(async (user) => {
        const response = await deleteUser(user.id);
        this.alertOrNotifyResponse(response);
        this.$emit("user-deleted", user);
      });

      if (error) {
        this.alertOrNotifyResponse(error);
      }
    },
  },
};
</script>

<style scoped></style>
