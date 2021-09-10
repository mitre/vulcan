<script>
// This mixin is for generating bootstrap toasts
export default {
  methods: {
    // Take in a `response` directly from an AJAX call and see if it
    // contains data that we can make into either an alert or notice.
    //
    // `response['data']['notice']` and `response['data']['alert']` are
    // valid for generating alerts.
    alertOrNotifyResponse: function (response) {
      // check for a notice
      let notice =
        response["data"] && response["data"]["notice"] ? response["data"]["notice"] : null;
      if (
        !notice &&
        response["response"] &&
        response["response"]["data"] &&
        response["response"]["data"]["notice"]
      ) {
        notice = response["response"]["data"]["notice"];
      }

      if (notice) {
        this.$bvToast.toast(notice, {
          title: `Success`,
          variant: "success",
          solid: true,
        });
      }

      // check for an alert
      let alert = response["data"] && response["data"]["alert"] ? response["data"]["alert"] : null;
      if (
        !notice &&
        response["response"] &&
        response["response"]["data"] &&
        response["response"]["data"]["alert"]
      ) {
        alert = response["response"]["data"]["alert"];
      }

      if (alert) {
        this.$bvToast.toast(alert, {
          title: `Error`,
          variant: "danger",
          solid: true,
        });
      }
    },
  },
};
</script>
