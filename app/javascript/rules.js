// Rules entry point
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import Rules from './components/rules/Rules.vue'

// Use Vue plugins
Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)

// Register the component globally
Vue.component('Rules', Rules)

document.addEventListener('turbolinks:load', () => {
  const element = document.getElementById('Rules')
  if (element) {
    new Vue({
      el: '#Rules'
    })
  }
})