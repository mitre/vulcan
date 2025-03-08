// Security Requirements Guides entry point
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import SecurityRequirementsGuides from './components/security_requirements_guides/SecurityRequirementsGuides.vue'

// Use Vue plugins
Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)

// Register the component globally
Vue.component('SecurityRequirementsGuides', SecurityRequirementsGuides)
Vue.component('securityrequirementsguides', SecurityRequirementsGuides)

document.addEventListener('turbolinks:load', () => {
  const element = document.getElementById('SecurityRequirementsGuides')
  if (element) {
    new Vue({
      el: '#SecurityRequirementsGuides'
    })
  }
})