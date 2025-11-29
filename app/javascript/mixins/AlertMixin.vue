<script>
import { useToast } from 'bootstrap-vue-next'
import { h } from 'vue'

// This mixin is for generating bootstrap toasts
export default {
  setup() {
    const toast = useToast()
    return { toast }
  },
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
    alertOrNotifyResponse(response) {
      let toastData
        = response.data && response.data.toast ? response.data.toast : null
      if (
        !toastData
        && response.response
        && response.response.data
        && response.response.data.toast
      ) {
        toastData = response.response.data.toast
      }

      // If toast is just a string, then assume it's a basic success message
      if (typeof toastData === 'string' || toastData instanceof String) {
        this.toast?.show({
          props: {
            title: 'Success',
            variant: 'success',
            solid: true,
            body: toastData,
          },
        })
        return
      }

      // If toast is an object, then gather its parameters with some defaults
      if (toastData && typeof toastData === 'object' && !Array.isArray(toastData)) {
        const title = toastData.title || 'Success'
        const variant = toastData.variant || 'success'
        let message = toastData.message
        if (Array.isArray(message)) {
          message = this.arrayToMessage(message)
        }

        this.toast?.show({
          props: {
            title,
            variant,
            solid: true,
            body: message,
          },
        })
        return
      }

      // At this point in the code it is likely an error has occurred
      if (response.message) {
        this.toast?.show({
          props: {
            title: 'Error',
            variant: 'danger',
            solid: true,
            body: response.message,
          },
        })
      }
    },
    // Takes an array of messages and forms them into a nicely formatted toast message
    arrayToMessage(messageArray) {
      return h(
        'div',
        messageArray.map(message => h('p', message)),
      )
    },
  },
}
</script>
