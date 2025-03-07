// Stigs entry point
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import Stigs from './components/stigs/Stigs.vue'

// Use Vue plugins
Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)

// Register the component globally
Vue.component('Stigs', Stigs)

document.addEventListener('turbolinks:load', () => {
  const element = document.getElementById('Stigs')
  if (element) {
    new Vue({
      el: '#Stigs'
    })
  }
})