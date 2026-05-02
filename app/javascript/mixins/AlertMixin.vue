<script>
import _ from "lodash";

// This mixin is for generating bootstrap toasts
export default {
  methods: {
    // Take in a `response` directly from an AJAX call and see if it
    // contains data that we can make into either an alert or notice.
    //
    // First, the function will try to collect a toast from either
    // - response["data"]["toast"]
    // - response["response"]["data"]["toast"]
    //
    // Second, it will render the toast object using 'title', 'variant',
    // and 'message' parameters
    //   - 'message' is required and can be a string or array of strings
    //   - 'title', and 'variant' are optional and will default to 'Success' and 'success'
    // - If no response is provided -> show 'message' as an alert on the screen
    // (PR-717 .19d: pre-fix the toast could also be a bare string;
    //  every controller now returns the canonical object shape so the
    //  string branch was removed.)
    alertOrNotifyResponse: function (response) {
      // Structured permission-denied path (Plan B / B3): render a rich toast
      // with the project admin contacts so the user knows who to ask for access.
      const errorData = response?.response?.data;
      if (response?.response?.status === 403 && errorData?.error === "permission_denied") {
        const admins = Array.isArray(errorData.admins) ? errorData.admins : [];
        this.$bvToast.toast(this.permissionDeniedBody(errorData.message, admins), {
          title: "Permission denied",
          variant: "danger",
          solid: true,
          autoHideDelay: 8000,
        });
        return;
      }

      let toast = response["data"] && response["data"]["toast"] ? response["data"]["toast"] : null;
      if (
        !toast &&
        response["response"] &&
        response["response"]["data"] &&
        response["response"]["data"]["toast"]
      ) {
        toast = response["response"]["data"]["toast"];
      }

      // PR-717 review remediation .19d — every controller now returns
      // canonical {title, message, variant} object toasts (was a mix of
      // string + object pre-fix). The string-handling branch was here
      // and has been removed; if a backend still returns a string we
      // fall through to the error branch below, which the dev sees in
      // the console — caller will fix the backend.
      if (_.isPlainObject(toast)) {
        const title = toast["title"] || "Success";
        const variant = toast["variant"] || "success";
        let message = toast["message"];
        if (_.isArray(message)) {
          message = this.arrayToMessage(message);
        }

        this.$bvToast.toast(message, {
          title: title,
          variant: variant,
          solid: true,
        });
        return;
      }

      // At this point in the code it is likely an error has occurred
      if (response.message) {
        this.$bvToast.toast(response.message, {
          title: "Error",
          variant: "danger",
          solid: true,
        });
        return;
      }
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
        children.push(h("p", { class: "mb-1 font-weight-bold" }, "Project administrators:"));
        children.push(
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
