<template>
  <b-modal
    :visible="visible"
    title="Create API Token"
    centered
    ok-title="Create Token"
    :ok-disabled="!formValid || creating"
    @hidden="$emit('hidden')"
    @ok.prevent="onSubmit"
  >
    <b-form @submit.prevent="onSubmit">
      <b-form-group
        label="Token Name"
        label-for="token-name"
        description="A label to identify this token (e.g. 'CI Pipeline', 'MCP Server')"
      >
        <b-form-input
          id="token-name"
          v-model="form.name"
          required
          placeholder="My API Token"
          autocomplete="off"
        />
      </b-form-group>

      <b-form-group label="Scopes">
        <b-form-checkbox-group v-model="form.scopes" :options="scopeOptions" stacked />
      </b-form-group>

      <b-form-group
        label="Expiration Date"
        label-for="token-expiry"
        :description="`Maximum ${maxLifetimeDays} days from today`"
      >
        <b-form-input
          id="token-expiry"
          v-model="form.expires_at"
          type="date"
          :min="minDate"
          :max="maxDate"
          required
        />
      </b-form-group>

      <b-form-group
        label="IP Allowlist (optional)"
        label-for="token-ips"
        description="One CIDR per line. Leave empty to allow any IP."
      >
        <b-form-textarea
          id="token-ips"
          v-model="form.allowed_ips_text"
          placeholder="10.0.0.0/8&#10;192.168.1.0/24"
          rows="3"
        />
      </b-form-group>

      <hr />

      <b-form-group
        label="Current Password"
        label-for="token-password"
        description="Required to create a token (session hijack protection)"
      >
        <b-form-input
          id="token-password"
          v-model="form.current_password"
          type="password"
          required
          autocomplete="current-password"
        />
      </b-form-group>
    </b-form>

    <template #modal-footer="{ ok, cancel }">
      <b-button variant="secondary" @click="cancel()">Cancel</b-button>
      <b-button variant="primary" :disabled="!formValid || creating" @click="ok()">
        <b-spinner v-if="creating" small class="mr-1" />
        {{ creating ? "Creating..." : "Create Token" }}
      </b-button>
    </template>
  </b-modal>
</template>

<script>
import { createToken } from "../../api/tokensApi";
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "CreateTokenModal",
  mixins: [FormMixinVue, AlertMixinVue],
  props: {
    visible: { type: Boolean, default: false },
    maxLifetimeDays: { type: Number, default: 365 },
  },
  data() {
    return {
      form: this.freshForm(),
      creating: false,
    };
  },
  computed: {
    scopeOptions() {
      return [
        { text: "Read — GET endpoints only", value: "read" },
        { text: "Write — GET + POST/PUT/PATCH/DELETE", value: "write" },
        { text: "Admin — everything including user management", value: "admin" },
      ];
    },
    formValid() {
      return (
        this.form.name.trim().length > 0 &&
        this.form.scopes.length > 0 &&
        this.form.expires_at.length > 0 &&
        this.form.current_password.length > 0
      );
    },
    minDate() {
      const d = new Date();
      d.setDate(d.getDate() + 1);
      return d.toISOString().split("T")[0];
    },
    maxDate() {
      const d = new Date();
      d.setDate(d.getDate() + this.maxLifetimeDays);
      return d.toISOString().split("T")[0];
    },
  },
  watch: {
    visible(val) {
      if (val) this.form = this.freshForm();
    },
  },
  methods: {
    freshForm() {
      return {
        name: "",
        scopes: ["read"],
        expires_at: "",
        allowed_ips_text: "",
        current_password: "",
      };
    },
    onSubmit() {
      this.creating = true;
      const allowedIps = this.form.allowed_ips_text
        .split("\n")
        .map((l) => l.trim())
        .filter((l) => l.length > 0);

      const payload = {
        name: this.form.name,
        scopes: this.form.scopes,
        expires_at: this.form.expires_at,
        current_password: this.form.current_password,
      };
      if (allowedIps.length > 0) payload.allowed_ips = allowedIps;

      createToken(payload)
        .then((res) => {
          this.$emit("created", res.data.token);
          this.$emit("hidden");
        })
        .catch((err) => {
          this.alertOrNotifyResponse(err.response);
        })
        .finally(() => {
          this.creating = false;
        });
    },
  },
};
</script>
