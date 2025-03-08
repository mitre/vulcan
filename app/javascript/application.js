// Entry point for the build script in your package.json
import Rails from '@rails/ujs'
import Turbolinks from 'turbolinks'
import * as ActiveStorage from '@rails/activestorage'
import './channels'
// Import jQuery and bootstrap with proper exports
import jQuery from 'jquery'
window.jQuery = jQuery
window.$ = jQuery
import 'bootstrap'

// No need to explicitly import MDI fonts - they will be handled by the SCSS import

console.log('Application.js initialized')

// Import debug utilities
import { setupDebugging } from './debug-utils'

// Setup debugging tools
setupDebugging()

// Start Rails UJS
Rails.start()
// Start Turbolinks
Turbolinks.start()
// Start ActiveStorage
ActiveStorage.start()

// Vue setup
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'

// Enable Vue debugging
Vue.config.devtools = true
Vue.config.debug = true
Vue.config.silent = false
Vue.config.productionTip = false

// Log Vue version for debugging
console.log(`Vue version: ${Vue.version}`)

// Make Vue available globally for debugging
window.Vue = Vue

// Use Vue plugins
Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)
console.log('Vue plugins initialized')

// Add Bootstrap JavaScript to the mix
document.addEventListener('DOMContentLoaded', () => {
  console.log('DOMContentLoaded event fired')
  
  // Set up popovers
  try {
    const popoverTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="popover"]'))
    popoverTriggerList.forEach(element => {
      new bootstrap.Popover(element)
    })
  } catch (error) {
    console.error('Error setting up popovers:', error)
  }

  // Set up tooltips
  try {
    const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'))
    tooltipTriggerList.forEach(element => {
      new bootstrap.Tooltip(element)
    })
  } catch (error) {
    console.error('Error setting up tooltips:', error)
  }
})
