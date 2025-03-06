// Toaster entry point
import Vue from 'vue'

// Create a simple standalone toaster component for testing
const SimpleToaster = {
  template: `
    <div>
      <b-toast v-if="noticeMsg" id="notice-toast" variant="success" solid>
        <template #toast-title>Success</template>
        {{ noticeMsg }}
      </b-toast>
      <b-toast v-if="alertMsg" id="alert-toast" variant="danger" solid>
        <template #toast-title>Error</template>
        {{ alertMsg }}
      </b-toast>
    </div>
  `,
  props: {
    notice: {
      type: String,
      default: null
    },
    alert: {
      type: String,
      default: null
    }
  },
  computed: {
    noticeMsg() {
      return this.notice;
    },
    alertMsg() {
      return this.alert;
    }
  },
  mounted() {
    if (this.noticeMsg) {
      this.$bvToast.show('notice-toast')
    }
    if (this.alertMsg) {
      this.$bvToast.show('alert-toast')
    }
  }
}

// Register the component globally
Vue.component("Toaster", SimpleToaster)

// Initialize when the DOM is ready
document.addEventListener("turbolinks:load", () => {
  const el = document.getElementById("Toaster")
  if (el) {
    new Vue({
      el: "#Toaster"
    })
  }
})