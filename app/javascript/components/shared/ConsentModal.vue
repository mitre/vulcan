<template>
  <b-modal
    id="consent-modal"
    :title="config.title"
    :visible="showModal"
    no-close-on-backdrop
    no-close-on-esc
    hide-header-close
    no-fade
    centered
    size="lg"
    @hidden="onHidden"
  >
    <!-- eslint-disable-next-line vue/no-v-html -- Content is sanitized via DOMPurify -->
    <div class="consent-content" v-html="sanitizedContent" />
    <b-alert :show="!!errorMessage" variant="danger" class="mt-3 mb-0" data-testid="consent-error">
      {{ errorMessage }}
    </b-alert>
    <template #modal-footer>
      <b-button variant="primary" data-testid="consent-agree" @click="onAgree"> I Agree </b-button>
    </template>
  </b-modal>
</template>

<script>
import { marked } from "marked";
import DOMPurify from "dompurify";
import { acknowledgeConsent } from "../../api/authApi";

export default {
  name: "ConsentModal",
  // FormMixin was imported here but its authenticityToken computed was never
  // consumed — CSRF is handled by the ky baseApi hooks (acknowledgeConsent).
  props: {
    config: {
      type: Object,
      required: true,
      default: () => ({
        enabled: false,
        required: false,
        version: "1",
        title: "Terms of Use",
        content: "",
      }),
    },
  },
  data() {
    return {
      showModal: false,
      acknowledged: false,
      errorMessage: "",
    };
  },
  computed: {
    sanitizedContent() {
      if (!this.config.content) return "";
      const html = marked(this.config.content);
      return DOMPurify.sanitize(html);
    },
  },
  mounted() {
    // Server tells us whether consent is required via config.required
    if (this.config.enabled && this.config.required) {
      this.showModal = true;
    }
  },
  methods: {
    async onAgree() {
      this.errorMessage = "";
      try {
        await acknowledgeConsent();
        this.acknowledged = true;
        this.showModal = false;
      } catch {
        // POST failed — keep modal visible, consent not recorded, and tell the
        // user (a silent catch made a failed acknowledgment look like a dead
        // button). A successful bodyless 200 no longer lands here — baseApi's
        // parseBody resolves an empty response instead of throwing on it.
        this.errorMessage =
          "We couldn't record your acknowledgment. Please check your connection and try again.";
        this.showModal = true;
      }
    },
    onHidden() {
      // Re-show if not acknowledged (prevents programmatic dismissal)
      if (!this.acknowledged) {
        this.$nextTick(() => {
          this.showModal = true;
        });
      }
    },
  },
};
</script>

<style scoped>
.consent-content {
  max-height: 60vh;
  overflow-y: auto;
}
</style>
