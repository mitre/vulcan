<template>
  <div />
</template>

<script>
import { TOAST_EVENT } from "../../composables/useToast";

/**
 * Toaster — the single $bvToast renderer for the app.
 *
 * Mounted on every page by the toaster pack. Producers in other packs cannot
 * share module state with this bundle (isolated iife packs), so they dispatch
 * TOAST_EVENT CustomEvents via useToast(); this component listens on document
 * and renders each payload with $bvToast. VNode bodies (paragraph arrays,
 * permission-denied admin lists) are built here, where a component render
 * context exists — useToast payloads stay plain data.
 *
 * Also renders Rails flash messages passed as props from the layout.
 */
export default {
  name: "Toaster",
  props: {
    notice: {
      type: String,
      required: false,
    },
    alert: {
      type: String,
      required: false,
    },
  },
  created: function () {
    this.onToastEvent = (event) => this.renderToast(event.detail);
    document.addEventListener(TOAST_EVENT, this.onToastEvent);
  },
  mounted: function () {
    if (this.notice) {
      this.renderToast({ title: "Notice", variant: "success", message: [this.notice] });
    }

    if (this.alert) {
      this.renderToast({ title: "Error", variant: "danger", message: [this.alert] });
    }
  },
  beforeDestroy: function () {
    document.removeEventListener(TOAST_EVENT, this.onToastEvent);
  },
  methods: {
    // Render one toast payload ({title, variant, message, admins?, autoHideDelay?}).
    renderToast: function ({ title, variant, message, admins, autoHideDelay }) {
      let body = message;
      if (admins) {
        body = this.permissionDeniedBody(message, admins);
      } else if (Array.isArray(message)) {
        body = this.arrayToMessage(message);
      }

      const options = { title: title, variant: variant, solid: true };
      if (autoHideDelay) {
        options.autoHideDelay = autoHideDelay;
      }
      this.$bvToast.toast(body, options);
    },
    // Takes an array of messages and forms them into a nicely formatted toast message
    arrayToMessage: function (messageArray) {
      return this.$createElement(
        "div",
        messageArray.map((message) => this.$createElement("p", message)),
      );
    },
    // Build a VNode body for a structured permission_denied response.
    // Renders the message paragraph followed by a "Project administrators:"
    // section listing each admin as "Name <email>" — so the user knows
    // exactly who to contact for access.
    permissionDeniedBody: function (message, admins) {
      const h = this.$createElement;
      const children = [h("p", { class: "mb-2" }, message)];
      if (admins.length > 0) {
        children.push(
          h("p", { class: "mb-1 font-weight-bold" }, "Project administrators:"),
          h(
            "ul",
            { class: "mb-0 pl-3" },
            admins.map((a) => h("li", `${a.name} <${a.email}>`)),
          ),
        );
      }
      return h("div", children);
    },
  },
};
</script>

<style scoped></style>
