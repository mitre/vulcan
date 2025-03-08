// Navbar entry point 
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'

console.log('Navbar.js initialized')

Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)

// Create a simple standalone navbar component for testing
const SimpleNavbar = {
  template: `
    <div>
      <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
        <a class="navbar-brand" id="heading" href="/">
          <b-icon icon="radar" aria-hidden="true"></b-icon>
          VULCAN
        </a>
        <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#nav-collapse" aria-controls="nav-collapse" aria-expanded="false" aria-label="Toggle navigation">
          <span class="navbar-toggler-icon"></span>
        </button>
        <div class="collapse navbar-collapse" id="nav-collapse">
          <ul class="navbar-nav mx-auto">
            <li v-for="item in navigation" :key="item.name" class="nav-item">
              <a class="nav-link" :href="item.link">
                <b-icon :icon="getBootstrapIconName(item.icon)" aria-hidden="true"></b-icon> {{ item.name }}
              </a>
            </li>
          </ul>
        </div>
      </nav>
    </div>
  `,
  methods: {
    // Helper method to convert MDI icon names to Bootstrap icon names
    getBootstrapIconName(mdiIconName) {
      // Common MDI to Bootstrap icon mappings
      const iconMap = {
        'mdi-home': 'house',
        'mdi-radar': 'radar',
        'mdi-account': 'person',
        'mdi-cog': 'gear',
        'mdi-folder': 'folder',
        'mdi-shield': 'shield',
        'mdi-file-document': 'file-text',
        'mdi-book': 'book',
        'mdi-alert': 'exclamation-triangle',
        'mdi-check': 'check',
        'mdi-close': 'x',
        'mdi-plus': 'plus'
      }
      
      // Extract the actual icon name without the mdi prefix
      const iconName = mdiIconName.replace('mdi-', '')
      
      // Return mapped icon or a default icon if not found
      return iconMap[`mdi-${iconName}`] || 'circle'
    }
  },
  props: {
    navigation: {
      type: Array,
      default: () => []
    },
    signed_in: {
      type: Boolean,
      default: false
    }
  },
  mounted() {
    console.log('SimpleNavbar component mounted')
    console.log('Navigation data:', this.navigation)
    console.log('Signed in status:', this.signed_in)
  }
}

// Register the component globally
Vue.component("Navbar", SimpleNavbar)
console.log('Navbar component registered')

// Wait for both turbolinks:load and DOMContentLoaded for maximum compatibility
const initNavbar = () => {
  console.log('Navbar initialization function called')
  const el = document.getElementById("navbar")
  console.log('Navbar element found:', !!el)
  
  if (el) {
    console.log('Navbar element HTML:', el.innerHTML.substr(0, 100) + '...')
    try {      
      // Mount the navbar
      const app = new Vue({
        el: "#navbar",
        mounted() {
          console.log('Navbar Vue instance mounted')
        }
      })
      console.log('Navbar Vue instance created successfully')
    } catch (error) {
      console.error('Error creating Navbar Vue instance:', error)
    }
  } else {
    console.warn('Navbar element not found in DOM, will retry in 500ms')
    setTimeout(initNavbar, 500) // Retry after a short delay
  }
}

// Try both event hooks for maximum compatibility
document.addEventListener("turbolinks:load", initNavbar)
document.addEventListener("DOMContentLoaded", initNavbar)