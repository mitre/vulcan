<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <!-- Command Bar -->
    <BaseCommandBar>
      <template #left>
        <b-button variant="primary" size="sm" :disabled="saving" @click="saveProfile">
          <b-spinner v-if="saving" small class="mr-1" />
          <b-icon v-else icon="check" /> {{ saving ? "Saving..." : "Save Profile" }}
        </b-button>
      </template>
      <template #right>
        <b-button-group size="sm" class="mr-2">
          <b-button
            :variant="isPanelActive('user-activity') ? 'secondary' : 'outline-secondary'"
            @click="togglePanel('user-activity')"
          >
            <b-icon icon="clock-history" /> My Activity
          </b-button>
        </b-button-group>
        <b-button variant="outline-danger" size="sm" @click="openDeleteAccount">
          <b-icon icon="trash" /> Delete Account
        </b-button>
      </template>
    </BaseCommandBar>

    <b-alert show :variant="isProviderManaged ? 'info' : 'success'" class="mb-3">
      <b-icon icon="shield-check" /> Authenticated via <strong>{{ authProvider }}</strong>
      <span v-if="isProviderManaged">
        - Some settings are managed externally and cannot be changed here.</span
      >
    </b-alert>

    <b-alert v-if="isPendingConfirmation" show variant="warning" class="mb-3">
      <b-icon icon="exclamation-triangle" /> Your email address is pending confirmation. Check your
      email for the confirmation link.
    </b-alert>

    <b-row>
      <b-col md="6">
        <b-card title="Profile Information">
          <b-form @submit.prevent="saveProfile">
            <!-- Name -->
            <b-form-group label="Your Name" label-for="user-name">
              <b-form-input
                id="user-name"
                v-model="form.name"
                :disabled="isProviderManaged"
                required
                autocomplete="name"
              />
            </b-form-group>

            <!-- Email -->
            <b-form-group label="Email" label-for="user-email">
              <b-form-input
                id="user-email"
                v-model="form.email"
                type="email"
                :disabled="isProviderManaged"
                required
                autocomplete="email"
              />
            </b-form-group>

            <!-- Slack User ID -->
            <b-form-group
              label="Slack User ID (Optional)"
              label-for="user-slack"
              description="Provide your Slack user ID (e.g., U123456) for notifications"
            >
              <b-form-input
                id="user-slack"
                v-model="form.slack_user_id"
                :disabled="isProviderManaged"
                autocomplete="off"
              />
            </b-form-group>

            <!-- Password fields (local auth only) -->
            <template v-if="!isProviderManaged">
              <hr class="my-4" />
              <h5 class="mb-3">Change Password</h5>

              <b-form-group
                label="New Password"
                label-for="user-password"
                description="Leave blank if you don't want to change it"
              >
                <b-form-input
                  id="user-password"
                  v-model="form.password"
                  type="password"
                  autocomplete="new-password"
                />
              </b-form-group>

              <b-form-group label="Confirm New Password" label-for="user-password-confirmation">
                <b-form-input
                  id="user-password-confirmation"
                  v-model="form.password_confirmation"
                  type="password"
                  autocomplete="new-password"
                />
              </b-form-group>

              <b-form-group
                label="Current Password"
                label-for="user-current-password"
                description="Required to confirm your changes"
              >
                <b-form-input
                  id="user-current-password"
                  v-model="form.current_password"
                  type="password"
                  required
                  autocomplete="current-password"
                />
              </b-form-group>
            </template>
          </b-form>
        </b-card>
      </b-col>
    </b-row>

    <!-- User Activity Sidebar -->
    <b-sidebar
      id="user-activity-sidebar"
      title="My Activity"
      right
      shadow
      backdrop
      :visible="activePanel === 'user-activity'"
      @hidden="closePanel"
    >
      <div class="px-3 py-2">
        <p v-if="userHistories.length === 0" class="text-muted">
          No activity yet. Your actions (creating projects, editing components, etc.) will appear
          here.
        </p>
        <History v-else :histories="userHistories" :revertable="false" />
      </div>
    </b-sidebar>

    <!-- Delete Account Confirmation Modal -->
    <ConfirmDeleteModal
      v-model="showDeleteModal"
      item-name="your account"
      item-type="account"
      :is-deleting="isDeleting"
      warning-message="This will permanently delete your account and all associated data. This action cannot be undone."
      confirm-button-text="Delete My Account"
      @confirm="confirmDeleteAccount"
      @cancel="showDeleteModal = false"
    />
  </div>
</template>

<script>
import axios from "axios";
import BaseCommandBar from "../shared/BaseCommandBar.vue";
import ConfirmDeleteModal from "../shared/ConfirmDeleteModal.vue";
import History from "../shared/History.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import { useSidebar } from "../../composables";

export default {
  name: "UserProfile",
  components: { BaseCommandBar, ConfirmDeleteModal, History },
  mixins: [FormMixinVue, AlertMixinVue],
  props: {
    user: {
      type: Object,
      required: true,
    },
    histories: {
      type: Array,
      default: () => [],
    },
  },
  setup() {
    const { activePanel, togglePanel, closePanel } = useSidebar();
    return { activePanel, togglePanel, closePanel };
  },
  data() {
    return {
      form: {
        name: this.user.name || "",
        email: this.user.email || "",
        slack_user_id: this.user.slack_user_id || "",
        password: "",
        password_confirmation: "",
        current_password: "",
      },
      saving: false,
      showDeleteModal: false,
      isDeleting: false,
    };
  },
  computed: {
    breadcrumbs() {
      return [
        { text: "Users", href: "/users" },
        { text: "Profile", active: true },
      ];
    },
    isProviderManaged() {
      return !!this.user.provider;
    },
    authProvider() {
      if (!this.user.provider) return "Local";
      // Capitalize first letter
      return this.user.provider.charAt(0).toUpperCase() + this.user.provider.slice(1);
    },
    isPendingConfirmation() {
      return !!(this.user.unconfirmed_email && this.user.unconfirmed_email.length > 0);
    },
    isPanelActive() {
      return (panel) => this.activePanel === panel;
    },
    userHistories() {
      // Filter histories to only show actions by this user
      return this.histories.filter((h) => h.user_id === this.user.id);
    },
  },
  methods: {
    async saveProfile() {
      if (this.saving) return;

      this.saving = true;
      try {
        const response = await axios.put(`/users`, {
          user: this.form,
        });
        this.alertOrNotifyResponse(response);
        // Clear password fields after successful save
        this.form.password = "";
        this.form.password_confirmation = "";
        this.form.current_password = "";
      } catch (error) {
        this.alertOrNotifyResponse(error);
        // Auto-focus the current password field if that's the error
        const errorMsg = error.response?.data?.toast?.message;
        if (errorMsg && errorMsg.some((msg) => msg.includes("Current password"))) {
          this.$nextTick(() => {
            const input = document.getElementById("user-current-password");
            if (input) input.focus();
          });
        }
      } finally {
        this.saving = false;
      }
    },
    openDeleteAccount() {
      this.showDeleteModal = true;
    },
    async confirmDeleteAccount() {
      this.isDeleting = true;
      try {
        await axios.delete("/users");
        // Redirect to home after account deletion
        window.location.href = "/";
      } catch (error) {
        this.alertOrNotifyResponse(error);
        this.isDeleting = false;
      }
    },
  },
};
</script>
