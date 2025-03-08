// Navbar entry point
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import App from './components/navbar/App.vue'
import NavbarItem from './components/navbar/NavbarItem.vue'
import SrgIdSearch from './components/navbar/SrgIdSearch.vue'

Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)

// Register the components
Vue.component("Navbar", App)
Vue.component("NavbarItem", NavbarItem)
Vue.component("SrgIdSearch", SrgIdSearch)

// Initialize the navbar when the page loads
document.addEventListener("turbolinks:load", () => {
  const el = document.getElementById("navbar")
  if (el) {
    try {
      const app = new Vue({
        el: "#navbar"
      })
    } catch (error) {
      console.error('Error creating Navbar Vue instance:', error)
    }
  }
})