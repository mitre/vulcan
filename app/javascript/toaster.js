// Toaster entry point
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'

console.log('Toaster.js initialized')

Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)

// Create a simple standalone toaster component for testing
const SimpleToaster = {
  template: `
    <div>
      <div v-if="noticeMsg" class="toast show bg-success text-white" style="position: fixed; top: 20px; right: 20px; z-index: 9999;">
        <div class="toast-header bg-success text-white">
          <strong class="mr-auto">Success</strong>
          <button type="button" class="ml-2 mb-1 close" @click="dismissNotice">
            <span aria-hidden="true">&times;</span>
          </button>
        </div>
        <div class="toast-body">
          {{ noticeMsg }}
        </div>
      </div>
      
      <div v-if="alertMsg" class="toast show bg-danger text-white" style="position: fixed; top: 20px; right: 20px; z-index: 9999;">
        <div class="toast-header bg-danger text-white">
          <strong class="mr-auto">Error</strong>
          <button type="button" class="ml-2 mb-1 close" @click="dismissAlert">
            <span aria-hidden="true">&times;</span>
          </button>
        </div>
        <div class="toast-body">
          {{ alertMsg }}
        </div>
      </div>
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
  data() {
    return {
      showNotice: true,
      showAlert: true
    };
  },
  computed: {
    noticeMsg() {
      return this.showNotice ? this.notice : null;
    },
    alertMsg() {
      return this.showAlert ? this.alert : null;
    }
  },
  methods: {
    dismissNotice() {
      this.showNotice = false;
    },
    dismissAlert() {
      this.showAlert = false;
    }
  },
  mounted() {
    console.log('SimpleToaster component mounted')
    console.log('Notice:', this.notice)
    console.log('Alert:', this.alert)
  }
}

// Register the component globally
Vue.component("Toaster", SimpleToaster)
console.log('Toaster component registered')

// Wait for both turbolinks:load and DOMContentLoaded for maximum compatibility
const initToaster = () => {
  console.log('Toaster initialization function called')
  const el = document.getElementById("Toaster")
  console.log('Toaster element found:', !!el)
  
  if (el) {
    console.log('Toaster element HTML:', el.innerHTML.substr(0, 100) + '...')
    try {
      // Mount the toaster
      const app = new Vue({
        el: "#Toaster",
        mounted() {
          console.log('Toaster Vue instance mounted')
        }
      })
      console.log('Toaster Vue instance created successfully')
    } catch (error) {
      console.error('Error creating Toaster Vue instance:', error)
    }
  } else {
    console.warn('Toaster element not found in DOM, will retry in 500ms')
    setTimeout(initToaster, 500) // Retry after a short delay
  }
}

// Try both event hooks for maximum compatibility
document.addEventListener("turbolinks:load", initToaster)
document.addEventListener("DOMContentLoaded", initToaster)