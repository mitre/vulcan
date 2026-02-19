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
    <template #modal-footer>
      <b-button variant="primary" data-testid="consent-agree" @click="onAgree"> I Agree </b-button>
    </template>
  </b-modal>
</template>

<script>
import { marked } from "marked";
import DOMPurify from "dompurify";

const STORAGE_KEY_PREFIX = "vulcan-consent-v";

export default {
  name: "ConsentModal",
  props: {
    config: {
      type: Object,
      required: true,
      default: () => ({
        enabled: false,
        version: "1",
        title: "Terms of Use",
        content: "",
      }),
    },
  },
  data() {
    return {
      showModal: false,
    };
  },
  computed: {
    sanitizedContent() {
      if (!this.config.content) return "";
      const html = marked(this.config.content);
      return DOMPurify.sanitize(html);
    },
    storageKey() {
      return `${STORAGE_KEY_PREFIX}${this.config.version}`;
    },
  },
  mounted() {
    if (this.config.enabled && !this.isAcknowledged()) {
      this.showModal = true;
    }
  },
  methods: {
    isAcknowledged() {
      try {
        return localStorage.getItem(this.storageKey) === "true";
      } catch {
        return false;
      }
    },
    onAgree() {
      try {
        localStorage.setItem(this.storageKey, "true");
      } catch {
        // localStorage unavailable — allow access anyway
      }
      this.showModal = false;
    },
    onHidden() {
      // Re-show if not acknowledged (prevents programmatic dismissal)
      if (!this.isAcknowledged()) {
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
