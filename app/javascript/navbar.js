// Navbar entry point 
import Vue from 'vue'

// Create a simple standalone navbar component for testing
const SimpleNavbar = {
  template: `
    <div>
      <b-navbar toggleable="lg" type="dark" variant="dark">
        <b-navbar-brand id="heading" href="/">
          <i class="mdi mdi-radar" aria-hidden="true" />
          VULCAN
        </b-navbar-brand>
        <b-navbar-toggle target="nav-collapse" />
        <b-collapse id="nav-collapse" is-nav>
          <div class="d-flex w-100 justify-content-lg-center text-lg-center">
            <b-navbar-nav>
              <b-nav-item v-for="item in navigation" :key="item.name" :href="item.link">
                <i class="mdi" :class="item.icon" aria-hidden="true" /> {{ item.name }}
              </b-nav-item>
            </b-navbar-nav>
          </div>
        </b-collapse>
      </b-navbar>
    </div>
  `,
  props: {
    navigation: {
      type: Array,
      default: () => []
    },
    signed_in: {
      type: Boolean,
      default: false
    }
  }
}

// Register the component globally
Vue.component("Navbar", SimpleNavbar)

// Initialize when the DOM is ready
document.addEventListener("turbolinks:load", () => {
  const el = document.getElementById("navbar")
  if (el) {
    new Vue({
      el: "#navbar"
    })
  }
})