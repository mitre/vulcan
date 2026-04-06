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
      <b-icon icon="shield-check" /> Signed in via
      <strong>{{ currentSessionMethod }}</strong>
      <span v-if="linkedProvider && sessionAuthMethod === 'local'">
        &middot; Account also linked to <strong>{{ linkedProvider }}</strong>
        <b-button
          data-test="unlink-identity-button"
          size="sm"
          variant="outline-danger"
          class="ml-2"
          @click="openUnlinkIdentity"
        >
          <b-icon icon="link-45deg" /> Unlink
        </b-button>
      </span>
      <span v-else-if="linkedProvider">
        &middot; Some settings are managed by your identity provider and cannot be changed here.
        <b-button
          data-test="unlink-identity-button"
          size="sm"
          variant="outline-danger"
          class="ml-2"
          @click="openUnlinkIdentity"
        >
          <b-icon icon="link-45deg" /> Unlink {{ linkedProvider }}
        </b-button>
      </span>
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
                <PasswordField
                  id="user-password"
                  v-model="form.password"
                  name="user[password]"
                  autocomplete="new-password"
                  :policy="passwordPolicy"
                />
              </b-form-group>

              <b-form-group label="Confirm New Password" label-for="user-password-confirmation">
                <PasswordField
                  id="user-password-confirmation"
                  v-model="form.password_confirmation"
                  name="user[password_confirmation]"
                  autocomplete="new-password"
                  :must-match="form.password"
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

    <!-- Unlink Identity Confirmation Modal -->
    <b-modal
      id="unlink-identity-modal"
      v-model="showUnlinkModal"
      title="Unlink External Identity"
      :ok-disabled="isUnlinking"
      ok-title="Unlink"
      ok-variant="danger"
      cancel-title="Cancel"
      @ok.prevent="submitUnlink"
      @hidden="resetUnlinkForm"
    >
      <p>
        You are about to unlink <strong>{{ linkedProvider }}</strong> from your account. After
        unlinking, you can only sign in with your email and password.
      </p>
      <p class="text-muted small">
        Enter your current password to confirm you can still access this account.
      </p>
      <b-form-group label="Current Password" label-for="unlink-current-password">
        <b-form-input
          id="unlink-current-password"
          v-model="unlinkForm.current_password"
          type="password"
          autocomplete="current-password"
          :disabled="isUnlinking"
        />
      </b-form-group>
    </b-modal>

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
import PasswordField from "../shared/PasswordField.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import { useSidebar } from "../../composables";

export default {
  name: "UserProfile",
  components: { BaseCommandBar, ConfirmDeleteModal, History, PasswordField },
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
    passwordPolicy: {
      type: Object,
      default: null,
    },
    // How the user signed in THIS session: "local", "oidc", "ldap", "github".
    // Distinct from user.provider which records linked identities.
    sessionAuthMethod: {
      type: String,
      default: "local",
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
      unlinkForm: {
        current_password: "",
      },
      showUnlinkModal: false,
      isUnlinking: false,
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
    // The identity currently linked to this account (nil for local-only accounts).
    linkedProvider() {
      if (!this.user.provider) return null;
      return this.humanizeProvider(this.user.provider);
    },
    // How the user signed in during THIS session.
    currentSessionMethod() {
      return this.humanizeProvider(this.sessionAuthMethod);
    },
    // Retained for backward-compat with existing template code.
    authProvider() {
      return this.linkedProvider || "Local";
    },
    isPendingConfirmation() {
      return !!(this.user.unconfirmed_email && this.user.unconfirmed_email.length > 0);
    },
    isPanelActive() {
      return (panel) => this.activePanel === panel;
    },
    userHistories() {
      // The controller already scopes histories to the current user via
      // `Audited.audit_class.where(user_id: current_user.id)` in registrations#edit.
      // No further filtering needed here (VulcanAudit#format does not include user_id).
      return this.histories;
    },
  },
  methods: {
    humanizeProvider(provider) {
      if (!provider) return "Local";
      const map = {
        local: "Email and password",
        oidc: "OIDC (SSO)",
        ldap: "LDAP",
        github: "GitHub",
      };
      return map[provider.toString().toLowerCase()] || provider;
    },
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
        globalThis.location.href = "/";
      } catch (error) {
        this.alertOrNotifyResponse(error);
        this.isDeleting = false;
      }
    },
    openUnlinkIdentity() {
      this.showUnlinkModal = true;
    },
    resetUnlinkForm() {
      this.unlinkForm.current_password = "";
      this.isUnlinking = false;
    },
    async submitUnlink() {
      if (this.isUnlinking) return;
      this.isUnlinking = true;
      try {
        const response = await axios.post("/users/unlink_identity", {
          current_password: this.unlinkForm.current_password,
        });
        this.alertOrNotifyResponse(response);
        // Reload so the page reflects the unlinked state (provider nulled out)
        globalThis.location.reload();
      } catch (error) {
        this.alertOrNotifyResponse(error);
        this.isUnlinking = false;
      }
    },
  },
};
</script>
