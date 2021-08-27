
<script>
// This mixin is for generating bootstrap toasts
export default {
  methods: {
    // Take in a `response` directly from an AJAX call and see if it
    // contains data that we can make into either an alert or notice.
    //
    // `response['data']['notice']` and `response['data']['alert']` are
    // valid for generating alerts.
    alertOrNotifyResponse: function(response) {
      if (response['data'] && response['data']['notice']) {
        this.$bvToast.toast(response['data']['notice'], {
          title: `Success`,
          variant: 'success',
          solid: true
        })
      }
      else if (response['data'] && response['data']['alert']) {
        this.$bvToast.toast(response['data']['alert'], {
          title: `Error`,
          variant: 'danger',
          solid: true
        })
      } else {
        // The response did not contain data we can use for an alert or notice.
        return;
      }
    }
  }
}
</script>
