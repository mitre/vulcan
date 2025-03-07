// Projects entry point
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import Projects from './components/projects/Projects.vue'

// Use Vue plugins
Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)

// Register the component globally
Vue.component('Projects', Projects)

document.addEventListener('turbolinks:load', () => {
  const element = document.getElementById('Projects')
  if (element) {
    new Vue({
      el: '#Projects'
    })
  }
})