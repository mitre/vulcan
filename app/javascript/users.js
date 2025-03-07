// Users entry point
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import Users from './components/users/Users.vue'

// Use Vue plugins
Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)

// Register the component globally
Vue.component('Users', Users)

document.addEventListener('turbolinks:load', () => {
  const element = document.getElementById('users')
  if (element) {
    new Vue({
      el: '#users'
    })
  }
})