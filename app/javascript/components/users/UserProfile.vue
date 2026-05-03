<template>
  <div>
    <BaseCommandBar>
      <template #left>
        <b-button variant="primary" size="sm" :disabled="saving" @click="saveProfile">
          <b-spinner v-if="saving" small class="mr-1" />
          <b-icon v-else icon="check" /> {{ saving ? "Saving..." : "Save Profile" }}
        </b-button>
      </template>
      <template #right>
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

    <b-card no-body>
      <b-card-header>
        <h5 class="mb-0"><b-icon icon="person" class="mr-1" /> Profile Information</h5>
      </b-card-header>
      <b-card-body>
        <b-form @submit.prevent="saveProfile">
          <b-form-row>
            <b-col md="6">
              <b-form-group label="Your Name" label-for="user-name">
                <b-form-input
                  id="user-name"
                  v-model="form.name"
                  :disabled="isProviderManaged"
                  required
                  autocomplete="name"
                />
              </b-form-group>
            </b-col>
            <b-col md="6">
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
            </b-col>
          </b-form-row>
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
        </b-form>
      </b-card-body>
    </b-card>

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
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "UserProfile",
  components: { BaseCommandBar, ConfirmDeleteModal },
  mixins: [FormMixinVue, AlertMixinVue],
  props: {
    user: {
      type: Object,
      required: true,
    },
    sessionAuthMethod: {
      type: String,
      default: "local",
    },
  },
  data() {
    return {
      form: {
        name: this.user.name || "",
        email: this.user.email || "",
        slack_user_id: this.user.slack_user_id || "",
      },
      unlinkForm: { current_password: "" },
      showUnlinkModal: false,
      isUnlinking: false,
      saving: false,
      showDeleteModal: false,
      isDeleting: false,
    };
  },
  computed: {
    isProviderManaged() {
      return !!this.user.provider;
    },
    linkedProvider() {
      if (!this.user.provider) return null;
      return this.humanizeProvider(this.user.provider);
    },
    currentSessionMethod() {
      return this.humanizeProvider(this.sessionAuthMethod);
    },
    isPendingConfirmation() {
      return !!(this.user.unconfirmed_email && this.user.unconfirmed_email.length > 0);
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
        const response = await axios.put(`/users`, { user: this.form });
        this.alertOrNotifyResponse(response);
      } catch (error) {
        this.alertOrNotifyResponse(error);
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
        globalThis.location.reload();
      } catch (error) {
        this.alertOrNotifyResponse(error);
        this.isUnlinking = false;
      }
    },
  },
};
</script>
