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
    // Second, it will check if the toast is a string or object
    // - If string -> generate a basic success toast with that message
    // - If object -> generate a toast using 'title', 'variant', and 'message' parameters
    //   - 'message' is required and can be a string or array of strings
    //   - 'title', and 'variant' are optional and will default to 'Success' and 'sucess'
    // - If no response is provided -> show 'message' as an alert on the screen
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

      // If toast is just a string, then assume it's a basic success message
      if (typeof toast === "string" || toast instanceof String) {
        this.$bvToast.toast(toast, {
          title: "Success",
          variant: "success",
          solid: true,
        });
        return;
      }

      // If toast is an object, then gather its parameters with some defaults
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
