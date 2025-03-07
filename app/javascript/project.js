// Project entry point
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import Project from './components/project/Project.vue'
import linkify from 'vue-linkify'

// Use Vue plugins
Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)

// Register Vue directives
Vue.directive('linkified', linkify)

// Register the component globally
Vue.component('Project', Project)

document.addEventListener('turbolinks:load', () => {
  const element = document.getElementById('Project')
  if (element) {
    new Vue({
      el: '#Project'
    })
  }
})