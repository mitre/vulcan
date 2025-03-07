// Project Components entry point
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import ProjectComponents from './components/components/ProjectComponents.vue'
import linkify from 'vue-linkify'

// Use Vue plugins
Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)

// Register Vue directives
Vue.directive('linkified', linkify)

// Register the component globally
Vue.component('Projectcomponents', ProjectComponents)

document.addEventListener('turbolinks:load', () => {
  const element = document.getElementById('projectcomponents')
  if (element) {
    new Vue({
      el: '#projectcomponents'
    })
  }
})