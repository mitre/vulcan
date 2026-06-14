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
      <span v-if="isProviderManaged">
        &middot; Some settings are managed by your identity provider and cannot be changed here.
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
              <b-form-group
                label="Email"
                label-for="user-email"
                :description="isProviderManaged ? 'Managed by your identity provider.' : null"
              >
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
          <!-- Email is the login identifier — changing it requires the current
               password (OWASP re-auth for sensitive changes). The field only
               appears when the email actually differs. -->
          <b-form-group
            v-if="emailChanged"
            label="Current Password"
            label-for="profile-current-password"
            description="Required to change your email address."
          >
            <PasswordField
              id="profile-current-password"
              v-model="form.current_password"
              name="user[current_password]"
              autocomplete="current-password"
            />
          </b-form-group>
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

    <b-card no-body class="mt-3">
      <b-card-header>
        <h5 class="mb-0"><b-icon icon="link-45deg" class="mr-1" /> Connected Accounts</h5>
      </b-card-header>
      <b-card-body>
        <b-table-simple v-if="user.identities && user.identities.length" small hover responsive>
          <b-thead>
            <b-tr>
              <b-th>Provider</b-th>
              <b-th>Email</b-th>
              <b-th>Last Sign-In</b-th>
              <b-th class="text-right">Actions</b-th>
            </b-tr>
          </b-thead>
          <b-tbody>
            <b-tr v-for="identity in user.identities" :key="identity.id">
              <b-td>{{ identity.title }}</b-td>
              <b-td>{{ identity.email || "—" }}</b-td>
              <b-td>{{
                identity.last_sign_in_at
                  ? new Date(identity.last_sign_in_at).toLocaleString()
                  : "Never"
              }}</b-td>
              <b-td class="text-right">
                <b-button
                  v-if="identity.can_unlink"
                  size="sm"
                  variant="outline-danger"
                  :disabled="isUnlinking"
                  @click="openUnlinkIdentity(identity)"
                >
                  <b-icon icon="x-circle" /> Unlink
                </b-button>
                <span
                  v-else
                  v-b-tooltip.hover
                  title="Cannot unlink — this is your only sign-in method"
                >
                  <b-button size="sm" variant="outline-secondary" disabled>
                    <b-icon icon="lock" /> Unlink
                  </b-button>
                </span>
              </b-td>
            </b-tr>
          </b-tbody>
        </b-table-simple>
        <p v-else class="text-muted mb-0">No external identities linked.</p>

        <p v-if="user.identities && user.identities.length" class="text-muted small mt-2 mb-0">
          Connect additional accounts to sign in with multiple methods.
        </p>

        <b-dropdown
          v-if="user.connectable_providers && user.connectable_providers.length"
          size="sm"
          variant="outline-primary"
          class="mt-3"
        >
          <template #button-content>
            <b-icon icon="plus-circle" class="mr-1" />
            Add Account
          </template>
          <b-dropdown-item
            v-for="provider in user.connectable_providers"
            :key="provider.name"
            @click="connectProvider(provider.name)"
          >
            <b-icon icon="shield-lock" class="mr-2 text-muted" />
            <strong>{{ provider.title }}</strong>
            <br />
            <small class="text-muted ml-4">{{
              provider.description || `Sign in with ${provider.title}`
            }}</small>
          </b-dropdown-item>
        </b-dropdown>
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
        You are about to unlink <strong>{{ unlinkTarget ? unlinkTarget.title : "" }}</strong> from
        your account.
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
import { updateProfile, deleteAccount, unlinkIdentity } from "../../api/usersApi";
import BaseCommandBar from "../shared/BaseCommandBar.vue";
import ConfirmDeleteModal from "../shared/ConfirmDeleteModal.vue";
import PasswordField from "../shared/PasswordField.vue";
import { useToast } from "../../composables/useToast";

export default {
  name: "UserProfile",
  components: { BaseCommandBar, ConfirmDeleteModal, PasswordField },
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
  setup() {
    const { alertOrNotifyResponse } = useToast();
    return { alertOrNotifyResponse };
  },
  data() {
    return {
      form: {
        name: this.user.name || "",
        email: this.user.email || "",
        slack_user_id: this.user.slack_user_id || "",
        current_password: "",
      },
      // Tracks the email the SERVER currently has — rebased after each
      // successful save so a follow-up change (e.g. back to the original
      // address) still prompts for the password. The user prop is the
      // initial page render and goes stale after in-page saves.
      baselineEmail: this.user.email || "",
      unlinkForm: { current_password: "" },
      unlinkTarget: null,
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
    // Email change is the only field needing re-authentication; provider
    // users can't change email at all (the input is disabled).
    emailChanged() {
      return !this.isProviderManaged && this.form.email !== this.baselineEmail;
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
        const payload = {
          name: this.form.name,
          email: this.form.email,
          slack_user_id: this.form.slack_user_id,
        };
        if (this.emailChanged) {
          payload.current_password = this.form.current_password;
        }
        const response = await updateProfile(payload);
        this.form.current_password = "";
        this.baselineEmail = this.form.email;
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
        await deleteAccount();
        globalThis.location.href = "/";
      } catch (error) {
        this.alertOrNotifyResponse(error);
        this.isDeleting = false;
      }
    },
    openUnlinkIdentity(identity) {
      this.unlinkTarget = identity;
      this.showUnlinkModal = true;
    },
    resetUnlinkForm() {
      this.unlinkForm.current_password = "";
      this.unlinkTarget = null;
      this.isUnlinking = false;
    },
    async submitUnlink() {
      if (this.isUnlinking || !this.unlinkTarget) return;
      this.isUnlinking = true;
      try {
        const response = await unlinkIdentity({
          identity_id: this.unlinkTarget.id,
          current_password: this.unlinkForm.current_password,
        });
        this.alertOrNotifyResponse(response);
        globalThis.location.reload();
      } catch (error) {
        this.alertOrNotifyResponse(error);
        this.isUnlinking = false;
      }
    },
    connectProvider(providerName) {
      const form = document.createElement("form");
      form.method = "POST";
      form.action = `/users/initiate_link`;
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
      if (csrfToken) {
        const tokenInput = document.createElement("input");
        tokenInput.type = "hidden";
        tokenInput.name = "authenticity_token";
        tokenInput.value = csrfToken;
        form.appendChild(tokenInput);
      }
      const providerInput = document.createElement("input");
      providerInput.type = "hidden";
      providerInput.name = "provider";
      providerInput.value = providerName;
      form.appendChild(providerInput);
      document.body.appendChild(form);
      form.submit();
    },
  },
};
</script>
