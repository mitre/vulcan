<template>
  <div>
    <b-card no-body>
      <b-card-header class="d-flex justify-content-between align-items-center">
        <h5 class="mb-0"><b-icon icon="key" class="mr-1" /> API Tokens</h5>
        <b-button variant="primary" size="sm" @click="showCreateModal = true">
          <b-icon icon="plus" /> Create Token
        </b-button>
      </b-card-header>
      <b-card-body>
        <b-alert
          v-if="newlyCreatedToken"
          show
          variant="success"
          dismissible
          @dismissed="clearNewToken"
        >
          <h6 class="alert-heading"><b-icon icon="check-circle" /> Token created successfully</h6>
          <p class="mb-1">
            Copy this token now — <strong>you will not be able to see it again.</strong>
          </p>
          <div class="d-flex align-items-center">
            <code class="flex-grow-1 p-2 bg-light border rounded mr-2">{{
              newlyCreatedToken
            }}</code>
            <b-button variant="outline-primary" size="sm" @click="copyToken">
              <b-icon :icon="copied ? 'check' : 'clipboard'" />
              {{ copied ? "Copied!" : "Copy" }}
            </b-button>
          </div>
        </b-alert>

        <b-table
          v-if="tokens.length > 0"
          :items="tokens"
          :fields="tableFields"
          :tbody-tr-class="rowClass"
          striped
          hover
          responsive
          show-empty
        >
          <template #cell(token_prefix)="data">
            <code>{{ data.value }}...</code>
          </template>
          <template #cell(scopes)="data">
            <b-badge
              v-for="scope in data.value"
              :key="scope"
              :variant="scopeVariant(scope)"
              class="mr-1"
            >
              {{ scope }}
            </b-badge>
          </template>
          <template #cell(allowed_ips)="data">
            <template v-if="data.value && data.value.length > 0">
              <code v-for="ip in data.value" :key="ip" class="d-block">{{ ip }}</code>
            </template>
            <span v-else class="text-muted">Any</span>
          </template>
          <template #cell(last_used_at)="data">
            <span v-if="data.value">{{ formatDate(data.value) }}</span>
            <span v-else class="text-muted">Never</span>
          </template>
          <template #cell(expires_at)="data">
            <span v-if="data.value" :class="{ 'text-danger': isExpired(data.value) }">
              {{ data.value }}
            </span>
            <span v-else class="text-muted">No expiry</span>
          </template>
          <template #cell(actions)="data">
            <b-button
              v-if="!data.item.revoked_at"
              variant="outline-danger"
              size="sm"
              @click="confirmRevoke(data.item)"
            >
              <b-icon icon="x-circle" /> Revoke
            </b-button>
            <b-badge v-else variant="secondary">Revoked</b-badge>
          </template>
        </b-table>

        <div v-else class="text-center text-muted py-4">
          <b-icon icon="key" font-scale="2" class="mb-2 d-block mx-auto" />
          <p>No API tokens. Create one to access the Vulcan API programmatically.</p>
        </div>
      </b-card-body>
    </b-card>

    <CreateTokenModal
      :visible="showCreateModal"
      @hidden="showCreateModal = false"
      @created="onTokenCreated"
    />

    <ConfirmDeleteModal
      :visible="showRevokeConfirm"
      :item-name="tokenToRevoke && tokenToRevoke.name"
      item-type="API token"
      :is-deleting="revoking"
      warning-message="This token will be permanently revoked and cannot be restored."
      confirm-button-text="Revoke Token"
      @confirm="doRevoke"
      @cancel="showRevokeConfirm = false"
    />
  </div>
</template>

<script>
import { listTokens, revokeToken } from "../../api/tokensApi";
import CreateTokenModal from "./CreateTokenModal.vue";
import ConfirmDeleteModal from "../shared/ConfirmDeleteModal.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "UserTokens",
  components: { CreateTokenModal, ConfirmDeleteModal },
  mixins: [AlertMixinVue],
  data() {
    return {
      tokens: [],
      showCreateModal: false,
      newlyCreatedToken: null,
      copied: false,
      showRevokeConfirm: false,
      tokenToRevoke: null,
      revoking: false,
    };
  },
  computed: {
    tableFields() {
      return [
        { key: "name", label: "Name", sortable: true },
        { key: "token_prefix", label: "Token" },
        { key: "scopes", label: "Scopes" },
        { key: "allowed_ips", label: "IP Allowlist" },
        { key: "last_used_at", label: "Last Used", sortable: true },
        { key: "expires_at", label: "Expires", sortable: true },
        { key: "actions", label: "" },
      ];
    },
  },
  mounted() {
    this.loadTokens();
  },
  methods: {
    loadTokens() {
      listTokens()
        .then((res) => {
          this.tokens = res.data.personal_access_tokens;
        })
        .catch(() => {
          this.alertOrNotifyResponse({
            data: {
              toast: { title: "Error", message: ["Could not load tokens."], variant: "danger" },
            },
          });
        });
    },
    onTokenCreated(rawToken) {
      this.newlyCreatedToken = rawToken;
      this.copied = false;
      this.loadTokens();
    },
    clearNewToken() {
      this.newlyCreatedToken = null;
      this.copied = false;
    },
    copyToken() {
      navigator.clipboard.writeText(this.newlyCreatedToken).then(() => {
        this.copied = true;
        setTimeout(() => {
          this.copied = false;
        }, 3000);
      });
    },
    confirmRevoke(token) {
      this.tokenToRevoke = token;
      this.showRevokeConfirm = true;
    },
    doRevoke() {
      this.revoking = true;
      revokeToken(this.tokenToRevoke.id)
        .then((res) => {
          this.alertOrNotifyResponse(res);
          this.showRevokeConfirm = false;
          this.loadTokens();
        })
        .catch((err) => {
          this.alertOrNotifyResponse(err.response);
        })
        .finally(() => {
          this.revoking = false;
        });
    },
    scopeVariant(scope) {
      const map = { read: "info", write: "warning", admin: "danger" };
      return map[scope] || "secondary";
    },
    formatDate(dateStr) {
      if (!dateStr) return "";
      const d = new Date(dateStr);
      return d.toLocaleDateString();
    },
    isExpired(dateStr) {
      return new Date(dateStr) < new Date();
    },
    rowClass(item) {
      return item?.revoked_at ? "token-revoked" : "";
    },
  },
};
</script>

<style scoped>
::v-deep .token-revoked {
  opacity: 0.55;
}
::v-deep .token-revoked td {
  text-decoration: line-through;
}
::v-deep .token-revoked td:last-child {
  text-decoration: none;
}
</style>
