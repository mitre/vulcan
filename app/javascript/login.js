// Login page entry point
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'

Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)

document.addEventListener("turbolinks:load", () => {
  // Mount login component
  const loginEl = document.getElementById("login")
  if (loginEl) {
    try {
      const loginApp = new Vue({
        el: "#login"
      })
    } catch (error) {
      console.error('Error creating Login Vue instance:', error)
    }
  }
})