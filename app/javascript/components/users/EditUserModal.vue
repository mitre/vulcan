<template>
  <b-modal :visible="visible" title="Edit User" centered @hidden="onHidden" @ok="onSubmit">
    <b-form v-if="localUser" @submit.prevent="onSubmit">
      <!-- Name -->
      <b-form-group label="Name" label-for="edit-user-name">
        <b-form-input id="edit-user-name" v-model="localUser.name" required autocomplete="off" />
      </b-form-group>

      <!-- Email -->
      <b-form-group label="Email" label-for="edit-user-email">
        <b-form-input
          id="edit-user-email"
          v-model="localUser.email"
          type="email"
          required
          autocomplete="off"
        />
      </b-form-group>

      <!-- Provider (read-only) -->
      <b-form-group label="Authentication Provider">
        <b-badge :variant="providerVariant">{{ providerLabel }}</b-badge>
      </b-form-group>

      <!-- Admin -->
      <b-form-group>
        <b-form-checkbox id="edit-user-admin" v-model="localUser.admin">
          Admin privileges
        </b-form-checkbox>
      </b-form-group>

      <!-- Password Management (local users only) -->
      <template v-if="isLocalUser">
        <hr />
        <p class="font-weight-bold mb-2">Password Management</p>

        <!-- SMTP available: send reset email -->
        <div v-if="smtpEnabled">
          <b-button
            variant="outline-secondary"
            size="sm"
            :disabled="resetSending"
            data-testid="send-reset-btn"
            @click="sendPasswordReset"
          >
            <b-spinner v-if="resetSending" small class="mr-1" />
            <b-icon v-else icon="envelope" class="mr-1" />
            Send Password Reset Email
          </b-button>
        </div>

        <!-- No SMTP: generate link or set password -->
        <div v-else>
          <!-- Option 1: Generate reset link -->
          <div class="mb-3">
            <b-button
              variant="outline-secondary"
              size="sm"
              :disabled="resetLinkGenerating"
              data-testid="generate-reset-link-btn"
              @click="generateResetLink"
            >
              <b-spinner v-if="resetLinkGenerating" small class="mr-1" />
              <b-icon v-else icon="link-45deg" class="mr-1" />
              Generate Reset Link
            </b-button>
            <p class="small text-muted mt-1 mb-0">
              Creates a link the user can use to set their own password.
            </p>
          </div>

          <!-- Show generated link -->
          <div v-if="generatedResetUrl" class="mb-3" data-testid="reset-url-display">
            <b-input-group size="sm">
              <b-form-input :value="generatedResetUrl" readonly />
              <b-input-group-append>
                <b-button variant="outline-secondary" @click="copyResetUrl">
                  <b-icon icon="clipboard" />
                </b-button>
              </b-input-group-append>
            </b-input-group>
          </div>

          <!-- Option 2: Set password directly (collapsed by default) -->
          <div>
            <b-button
              variant="link"
              size="sm"
              class="p-0 text-muted"
              @click="showManualPassword = !showManualPassword"
            >
              <b-icon :icon="showManualPassword ? 'chevron-down' : 'chevron-right'" class="mr-1" />
              Set password manually
            </b-button>

            <b-collapse :visible="showManualPassword" class="mt-2">
              <b-form-group label="New Password" label-for="edit-user-password" label-sr-only>
                <PasswordField
                  id="edit-user-password"
                  v-model="directPassword"
                  name="user[password]"
                  autocomplete="new-password"
                  :policy="passwordPolicy"
                />
              </b-form-group>
              <b-form-group
                label="Confirm Password"
                label-for="edit-user-password-confirm"
                label-sr-only
              >
                <PasswordField
                  id="edit-user-password-confirm"
                  v-model="directPasswordConfirm"
                  name="user[password_confirmation]"
                  autocomplete="new-password"
                  :must-match="directPassword"
                />
              </b-form-group>
              <b-button
                variant="outline-warning"
                size="sm"
                :disabled="!directPassword || !passwordsMatch || settingPassword"
                data-testid="set-password-btn"
                @click="setPasswordDirectly"
              >
                <b-spinner v-if="settingPassword" small class="mr-1" />
                <b-icon v-else icon="key" class="mr-1" />
                Set Password
              </b-button>
            </b-collapse>
          </div>
        </div>
      </template>
    </b-form>
  </b-modal>
</template>

<script>
import axios from "axios";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import PasswordField from "../shared/PasswordField.vue";

export default {
  name: "EditUserModal",
  components: { PasswordField },
  mixins: [FormMixinVue, AlertMixinVue],
  model: {
    prop: "visible",
    event: "update:visible",
  },
  props: {
    visible: {
      type: Boolean,
      default: false,
    },
    user: {
      type: Object,
      default: null,
    },
    smtpEnabled: {
      type: Boolean,
      default: false,
    },
    passwordPolicy: {
      type: Object,
      default: null,
    },
  },
  data() {
    return {
      localUser: null,
      resetSending: false,
      resetLinkGenerating: false,
      generatedResetUrl: null,
      directPassword: "",
      directPasswordConfirm: "",
      settingPassword: false,
      showManualPassword: false,
    };
  },
  computed: {
    isLocalUser() {
      return !this.localUser || !this.localUser.provider;
    },
    providerLabel() {
      if (!this.localUser || !this.localUser.provider) return "Local";
      return this.localUser.provider.toUpperCase();
    },
    passwordsMatch() {
      return this.directPassword && this.directPassword === this.directPasswordConfirm;
    },
    providerVariant() {
      if (!this.localUser || !this.localUser.provider) return "secondary";
      const variants = {
        github: "dark",
        ldap: "info",
        oidc: "primary",
      };
      return variants[this.localUser.provider] || "secondary";
    },
  },
  watch: {
    user: {
      handler(newUser) {
        if (newUser) {
          this.localUser = { ...newUser };
          this.resetSending = false;
          this.generatedResetUrl = null;
          this.directPassword = "";
          this.directPasswordConfirm = "";
          this.showManualPassword = false;
        }
      },
      immediate: true,
    },
  },
  methods: {
    async onSubmit(event) {
      if (event) event.preventDefault();
      if (!this.localUser) return;

      try {
        const response = await axios.put(`/users/${this.localUser.id}`, {
          user: {
            name: this.localUser.name,
            email: this.localUser.email,
            admin: this.localUser.admin,
          },
        });
        this.alertOrNotifyResponse(response);
        this.$emit("user-updated", response.data.user);
        this.$emit("update:visible", false);
      } catch (error) {
        this.alertOrNotifyResponse(error);
      }
    },
    async sendPasswordReset() {
      if (!this.localUser) return;
      this.resetSending = true;

      try {
        const response = await axios.post(`/users/${this.localUser.id}/send_password_reset`);
        this.alertOrNotifyResponse(response);
      } catch (error) {
        this.alertOrNotifyResponse(error);
      } finally {
        this.resetSending = false;
      }
    },
    async generateResetLink() {
      if (!this.localUser) return;
      this.resetLinkGenerating = true;

      try {
        const response = await axios.post(`/users/${this.localUser.id}/generate_reset_link`);
        this.alertOrNotifyResponse(response);
        this.generatedResetUrl = response.data.reset_url;
      } catch (error) {
        this.alertOrNotifyResponse(error);
      } finally {
        this.resetLinkGenerating = false;
      }
    },
    async setPasswordDirectly() {
      if (!this.localUser || !this.directPassword) return;
      if (!this.passwordsMatch) return;
      this.settingPassword = true;

      try {
        const response = await axios.post(`/users/${this.localUser.id}/set_password`, {
          user: { password: this.directPassword },
        });
        this.alertOrNotifyResponse(response);
        this.directPassword = "";
        this.directPasswordConfirm = "";
      } catch (error) {
        this.alertOrNotifyResponse(error);
      } finally {
        this.settingPassword = false;
      }
    },
    copyResetUrl() {
      navigator.clipboard.writeText(this.generatedResetUrl);
    },
    onHidden() {
      this.$emit("update:visible", false);
    },
  },
};
</script>
