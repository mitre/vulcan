<template>
  <b-modal :visible="visible" title="Edit User" centered @hidden="onHidden" @ok="onSubmit">
    <b-form v-if="localUser" @submit.prevent="onSubmit">
      <!-- ── User Identity ── -->
      <b-form-group label="Name" label-for="edit-user-name">
        <b-form-input id="edit-user-name" v-model="localUser.name" required autocomplete="off" />
      </b-form-group>

      <b-form-group label="Email" label-for="edit-user-email">
        <b-form-input
          id="edit-user-email"
          v-model="localUser.email"
          type="email"
          required
          autocomplete="off"
        />
      </b-form-group>

      <b-form-group label="Authentication Provider">
        <b-badge :variant="providerVariant">{{ providerLabel }}</b-badge>
      </b-form-group>

      <!-- ── Permissions ── -->
      <b-form-group>
        <b-form-checkbox id="edit-user-admin" v-model="localUser.admin">
          Admin privileges
        </b-form-checkbox>
      </b-form-group>

      <!-- ── Account Security ── -->
      <template v-if="lockoutEnabled || isLocalUser">
        <hr />
        <p class="font-weight-bold mb-2">
          <b-icon icon="shield-lock" class="mr-1" />
          Account Security
        </p>

        <!-- Account Status -->
        <div v-if="lockoutEnabled" class="mb-3">
          <div class="d-flex align-items-center justify-content-between">
            <span>
              <span class="text-muted mr-1">Status:</span>
              <template v-if="isLocked">
                <b-badge variant="warning">
                  <b-icon icon="lock" class="mr-1" />
                  Locked
                </b-badge>
                <small class="text-muted ml-1">
                  ({{ localUser.failed_attempts }} failed
                  {{ localUser.failed_attempts === 1 ? "attempt" : "attempts" }})
                </small>
              </template>
              <template v-else>
                <b-badge variant="success">
                  <b-icon icon="check-circle" class="mr-1" />
                  Active
                </b-badge>
              </template>
            </span>
            <b-button
              v-if="isLocked"
              variant="outline-warning"
              size="sm"
              :disabled="unlocking"
              data-testid="unlock-btn"
              @click="unlockUser"
            >
              <b-spinner v-if="unlocking" small class="mr-1" />
              <b-icon v-else icon="unlock" class="mr-1" />
              Unlock
            </b-button>
            <b-button
              v-else
              variant="outline-danger"
              size="sm"
              :disabled="locking"
              data-testid="lock-btn"
              @click="lockUser"
            >
              <b-spinner v-if="locking" small class="mr-1" />
              <b-icon v-else icon="lock" class="mr-1" />
              Lock Account
            </b-button>
          </div>
        </div>

        <!-- Password Management (local users only) -->
        <template v-if="isLocalUser">
          <p class="font-weight-bold mb-2 mt-3">Password Management</p>

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

            <div>
              <b-button
                variant="link"
                size="sm"
                class="p-0 text-muted"
                @click="showManualPassword = !showManualPassword"
              >
                <b-icon
                  :icon="showManualPassword ? 'chevron-down' : 'chevron-right'"
                  class="mr-1"
                />
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
    lockoutEnabled: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      localUser: null,
      unlocking: false,
      locking: false,
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
    isLocked() {
      return this.localUser && !!this.localUser.locked_at;
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
    async lockUser() {
      if (!this.localUser) return;
      this.locking = true;

      try {
        const response = await axios.post(`/users/${this.localUser.id}/lock`);
        this.alertOrNotifyResponse(response);
        this.$emit("user-updated", response.data.user);
        this.localUser.locked_at = response.data.user.locked_at;
        this.localUser.failed_attempts = response.data.user.failed_attempts;
        document.dispatchEvent(
          new CustomEvent("vulcan:lockout-changed", {
            detail: { action: "locked", user: response.data.user },
          }),
        );
      } catch (error) {
        this.alertOrNotifyResponse(error);
      } finally {
        this.locking = false;
      }
    },
    async unlockUser() {
      if (!this.localUser) return;
      this.unlocking = true;

      try {
        const response = await axios.post(`/users/${this.localUser.id}/unlock`);
        this.alertOrNotifyResponse(response);
        this.$emit("user-updated", response.data.user);
        this.localUser.locked_at = null;
        this.localUser.failed_attempts = 0;
        document.dispatchEvent(
          new CustomEvent("vulcan:lockout-changed", {
            detail: { action: "unlocked", user: response.data.user },
          }),
        );
      } catch (error) {
        this.alertOrNotifyResponse(error);
      } finally {
        this.unlocking = false;
      }
    },
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
