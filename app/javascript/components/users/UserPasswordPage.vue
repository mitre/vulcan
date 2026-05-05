<template>
  <div>
    <BaseCommandBar>
      <template #left>
        <b-button variant="primary" size="sm" :disabled="saving" @click="savePassword">
          <b-spinner v-if="saving" small class="mr-1" />
          <b-icon v-else icon="check" /> {{ saving ? "Saving..." : "Update Password" }}
        </b-button>
      </template>
    </BaseCommandBar>

    <b-alert v-if="isProviderManaged" show variant="info">
      <b-icon icon="shield-check" /> Password changes are managed by your identity provider (<strong
        >{{ linkedProvider }}</strong
      >). This page is unavailable for SSO accounts.
    </b-alert>

    <b-card v-else no-body>
      <b-card-header>
        <h5 class="mb-0"><b-icon icon="shield-lock" class="mr-1" /> Change Password</h5>
      </b-card-header>
      <b-card-body>
        <b-form @submit.prevent="savePassword">
          <b-form-row>
            <b-col md="6">
              <b-form-group
                label="New Password"
                label-for="user-password"
                description="Leave blank to keep your current password."
              >
                <PasswordField
                  id="user-password"
                  v-model="form.password"
                  name="user[password]"
                  autocomplete="new-password"
                  :policy="passwordPolicy"
                />
              </b-form-group>
            </b-col>
            <b-col md="6">
              <b-form-group label="Confirm New Password" label-for="user-password-confirmation">
                <PasswordField
                  id="user-password-confirmation"
                  v-model="form.password_confirmation"
                  name="user[password_confirmation]"
                  autocomplete="new-password"
                  :must-match="form.password"
                />
              </b-form-group>
            </b-col>
          </b-form-row>
          <b-form-group
            label="Current Password"
            label-for="user-current-password"
            description="Required to confirm your changes."
          >
            <b-form-input
              id="user-current-password"
              v-model="form.current_password"
              type="password"
              required
              autocomplete="current-password"
            />
          </b-form-group>
        </b-form>
      </b-card-body>
    </b-card>
  </div>
</template>

<script>
import axios from "axios";
import BaseCommandBar from "../shared/BaseCommandBar.vue";
import PasswordField from "../shared/PasswordField.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "UserPasswordPage",
  components: { BaseCommandBar, PasswordField },
  mixins: [FormMixinVue, AlertMixinVue],
  props: {
    user: { type: Object, required: true },
    passwordPolicy: { type: Object, default: null },
  },
  data() {
    return {
      form: { password: "", password_confirmation: "", current_password: "" },
      saving: false,
    };
  },
  computed: {
    isProviderManaged() {
      return !!this.user.provider;
    },
    linkedProvider() {
      if (!this.user.provider) return null;
      const map = { oidc: "OIDC (SSO)", ldap: "LDAP", github: "GitHub" };
      return map[this.user.provider.toString().toLowerCase()] || this.user.provider;
    },
  },
  methods: {
    async savePassword() {
      if (this.saving || this.isProviderManaged) return;
      this.saving = true;
      try {
        const response = await axios.put("/users", { user: this.form });
        this.alertOrNotifyResponse(response);
        this.form.password = "";
        this.form.password_confirmation = "";
        this.form.current_password = "";
      } catch (error) {
        this.alertOrNotifyResponse(error);
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
  },
};
</script>
