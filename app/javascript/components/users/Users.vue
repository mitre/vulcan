<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <!-- Command Bar -->
    <BaseCommandBar>
      <template #left>
        <b-button size="sm" variant="primary" @click="showCreateModal = true">
          <b-icon icon="person-plus" class="mr-1" />
          Create User
        </b-button>
      </template>
      <template #right>
        <b-button-group size="sm">
          <b-button
            :variant="isPanelActive('user-history') ? 'secondary' : 'outline-secondary'"
            @click="togglePanel('user-history')"
          >
            <b-icon icon="clock-history" /> User Activity
          </b-button>
        </b-button-group>
      </template>
    </BaseCommandBar>

    <UsersTable
      :users="localUsers"
      :lockout-enabled="lockoutEnabled"
      @edit-user="openEditModal"
      @user-deleted="onUserDeleted"
    />

    <!-- Create User Modal -->
    <CreateUserModal
      v-model="showCreateModal"
      :smtp-enabled="smtpEnabled"
      :password-policy="passwordPolicy"
      @user-created="onUserCreated"
    />

    <!-- Edit User Modal -->
    <EditUserModal
      v-model="showEditModal"
      :user="selectedUser"
      :smtp-enabled="smtpEnabled"
      :password-policy="passwordPolicy"
      :lockout-enabled="lockoutEnabled"
      @user-updated="onUserUpdated"
    />

    <!-- User History Slideover -->
    <b-sidebar
      id="user-history-sidebar"
      title="User Activity"
      right
      shadow
      backdrop
      :visible="activePanel === 'user-history'"
      @hidden="closePanel"
    >
      <div class="px-3 py-2">
        <History :histories="histories" :revertable="false" />
      </div>
    </b-sidebar>
  </div>
</template>

<script>
import UsersTable from "./UsersTable.vue";
import CreateUserModal from "./CreateUserModal.vue";
import EditUserModal from "./EditUserModal.vue";
import History from "../shared/History.vue";
import BaseCommandBar from "../shared/BaseCommandBar.vue";
import { useSidebar } from "../../composables";

export default {
  name: "Users",
  components: { UsersTable, CreateUserModal, EditUserModal, History, BaseCommandBar },
  props: {
    users: {
      type: Array,
      required: true,
    },
    histories: {
      type: Array,
      required: true,
    },
    smtpEnabled: {
      type: Boolean,
      default: false,
    },
    passwordPolicy: {
      type: Object,
      default: null,
    },
    lockoutEnabled: {
      type: Boolean,
      default: false,
    },
  },
  setup() {
    const { activePanel, togglePanel, closePanel } = useSidebar();
    return { activePanel, togglePanel, closePanel };
  },
  data() {
    return {
      localUsers: [...this.users],
      showCreateModal: false,
      showEditModal: false,
      selectedUser: null,
    };
  },
  computed: {
    breadcrumbs() {
      return [{ text: "Users", active: true }];
    },
    isPanelActive() {
      return (panel) => this.activePanel === panel;
    },
  },
  mounted() {
    const params = new URLSearchParams(globalThis.location.search);
    const unlockId = params.get("unlock");
    if (unlockId) {
      const user = this.localUsers.find((u) => u.id === Number.parseInt(unlockId, 10));
      if (user) {
        this.openEditModal(user);
      }
    }
  },
  methods: {
    openEditModal(user) {
      this.selectedUser = user;
      this.showEditModal = true;
    },
    onUserCreated(user) {
      this.localUsers.push(user);
    },
    onUserUpdated(updatedUser) {
      const idx = this.localUsers.findIndex((u) => u.id === updatedUser.id);
      if (idx !== -1) {
        this.$set(this.localUsers, idx, updatedUser);
      }
    },
    onUserDeleted(user) {
      this.localUsers = this.localUsers.filter((u) => u.id !== user.id);
    },
  },
};
</script>

<style scoped></style>
