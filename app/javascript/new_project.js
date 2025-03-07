// New Project entry point
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import NewProject from './components/project/NewProject.vue'

// Enable debugging
Vue.config.devtools = true
Vue.config.debug = true
Vue.config.silent = false
console.log('New Project entry point initialized')

// Use Vue plugins
Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)

// Register the component globally
Vue.component('NewProject', NewProject)

// Make Vue accessible globally for debugging
window.VueNewProject = Vue

// Initialize function similar to what's working in toaster.js
const initNewProject = () => {
  console.log('New Project initialization function called')
  const el = document.getElementById('NewProject')
  
  if (el) {
    console.log('New Project element found')
    try {
      // Mount the project component
      const app = new Vue({
        el: '#NewProject',
        render: h => h(NewProject)
      })
      console.log('New Project Vue instance created successfully')
    } catch (error) {
      console.error('Error creating New Project Vue instance:', error)
    }
  } else {
    console.warn('New Project element not found in DOM')
  }
}

// Try both event hooks for maximum compatibility
document.addEventListener('turbolinks:load', initNewProject)
document.addEventListener('DOMContentLoaded', initNewProject)