<template>
  <b-modal
    :visible="visible"
    title="Create New User"
    centered
    :no-close-on-backdrop="!!createdResetUrl"
    @hidden="onHidden"
    @ok="onSubmit"
  >
    <!-- Post-create: show reset URL for admin to copy -->
    <div v-if="createdResetUrl" data-testid="reset-url-display">
      <b-alert show variant="success" class="mb-3">
        <b-icon icon="check-circle" class="mr-1" />
        User created successfully.
      </b-alert>
      <p class="mb-1 font-weight-bold">Password Reset Link:</p>
      <p class="small text-muted mb-2">
        Copy this link and deliver it to the user so they can set their password.
      </p>
      <b-input-group>
        <b-form-input :value="createdResetUrl" readonly />
        <b-input-group-append>
          <b-button variant="outline-secondary" @click="copyResetUrl">
            <b-icon icon="clipboard" />
          </b-button>
        </b-input-group-append>
      </b-input-group>
    </div>

    <!-- Create form -->
    <b-form v-else @submit.prevent="onSubmit">
      <!-- Name -->
      <b-form-group label="Name" label-for="create-user-name">
        <b-form-input
          id="create-user-name"
          v-model="form.name"
          placeholder="Full name"
          required
          autocomplete="off"
        />
      </b-form-group>

      <!-- Email -->
      <b-form-group label="Email" label-for="create-user-email">
        <b-form-input
          id="create-user-email"
          v-model="form.email"
          type="email"
          placeholder="user@example.com"
          required
          autocomplete="off"
        />
      </b-form-group>

      <!-- Admin -->
      <b-form-group>
        <b-form-checkbox id="create-user-admin" v-model="form.admin">
          Grant admin privileges
        </b-form-checkbox>
      </b-form-group>

      <!-- Password section: only when SMTP is off -->
      <template v-if="!smtpEnabled">
        <hr />
        <p class="small text-muted mb-2">
          SMTP is not configured. Set a password directly, or leave blank to get a reset link after
          creation.
        </p>
        <b-form-group label="Password (optional)" label-for="create-user-password">
          <PasswordField
            id="create-user-password"
            v-model="form.password"
            name="user[password]"
            autocomplete="new-password"
            :policy="passwordPolicy"
          />
        </b-form-group>
        <b-form-group label="Confirm Password" label-for="create-user-password-confirm">
          <PasswordField
            id="create-user-password-confirm"
            v-model="form.passwordConfirm"
            name="user[password_confirmation]"
            autocomplete="new-password"
            :must-match="form.password"
          />
        </b-form-group>
      </template>

      <b-alert v-if="smtpEnabled" show variant="info" class="mb-0">
        <b-icon icon="envelope" class="mr-1" />
        A password setup email will be sent to the user.
      </b-alert>
    </b-form>

    <!-- Override footer when showing reset URL -->
    <template v-if="createdResetUrl" #modal-footer>
      <b-button variant="primary" @click="closeAfterCreate">Done</b-button>
    </template>
  </b-modal>
</template>

<script>
import axios from "axios";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import PasswordField from "../shared/PasswordField.vue";

export default {
  name: "CreateUserModal",
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
      form: {
        name: "",
        email: "",
        admin: false,
        password: "",
        passwordConfirm: "",
      },
      createdResetUrl: null,
    };
  },
  watch: {
    visible(newVal) {
      if (newVal) {
        this.form = { name: "", email: "", admin: false, password: "", passwordConfirm: "" };
        this.createdResetUrl = null;
      }
    },
  },
  methods: {
    async onSubmit(event) {
      if (event) event.preventDefault();

      // Validate password confirmation if password provided
      if (this.form.password && this.form.password !== this.form.passwordConfirm) {
        return;
      }

      const payload = {
        name: this.form.name,
        email: this.form.email,
        admin: this.form.admin,
      };
      // Only include password if admin typed one
      if (this.form.password) {
        payload.password = this.form.password;
      }

      try {
        const response = await axios.post("/users/admin_create", {
          user: payload,
        });
        this.alertOrNotifyResponse(response);
        this.$emit("user-created", response.data.user);

        // If backend returned a reset URL (no SMTP, no password), show it
        if (response.data.reset_url) {
          this.createdResetUrl = response.data.reset_url;
        } else {
          this.$emit("update:visible", false);
        }
      } catch (error) {
        this.alertOrNotifyResponse(error);
      }
    },
    copyResetUrl() {
      navigator.clipboard.writeText(this.createdResetUrl);
    },
    closeAfterCreate() {
      this.createdResetUrl = null;
      this.$emit("update:visible", false);
    },
    onHidden() {
      this.createdResetUrl = null;
      this.$emit("update:visible", false);
    },
  },
};
</script>
