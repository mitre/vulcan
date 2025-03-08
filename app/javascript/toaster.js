// Toaster entry point
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import Toaster from './components/toaster/Toaster.vue'
import AlertMixin from './mixins/AlertMixin.vue'

Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)

// Register the component
Vue.component("Toaster", Toaster)

// Initialize the toaster when the page loads
document.addEventListener("turbolinks:load", () => {
  const el = document.getElementById("Toaster")
  if (el) {
    try {
      const app = new Vue({
        el: "#Toaster"
      })
    } catch (error) {
      console.error('Error creating Toaster Vue instance:', error)
    }
  }
})