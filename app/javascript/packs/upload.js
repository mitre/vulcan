import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue'
// Import the individual components
import {
  BFormFile
} from 'bootstrap-vue'

// Add components globally
Vue.component('b-form-file', BFormFile)

Vue.use(TurbolinksAdapter)

document.addEventListener('turbolinks:load', () => {
  new Vue({
    el: '#upload',
  })
})
