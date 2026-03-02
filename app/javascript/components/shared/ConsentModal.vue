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
import axios from "axios";

export default {
  name: "ConsentModal",
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
      const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");
      try {
        await axios.post("/consent/acknowledge", null, {
          headers: {
            "X-CSRF-Token": csrfToken,
            Accept: "application/json",
          },
        });
        this.acknowledged = true;
        this.showModal = false;
      } catch {
        // POST failed — keep modal visible, consent not recorded
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
