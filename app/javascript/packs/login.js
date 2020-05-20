import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue'
// Import the individual components
import {
  BCard,
  BTab,
  BTabs,
  BCardText,
  BNav,
  BNavItem,
  BNavText
} from 'bootstrap-vue'

// Add components globally
Vue.component('b-card', BCard)
Vue.component('b-card-text', BCardText)
Vue.component('b-nav', BNav)
Vue.component('b-nav-item', BNavItem)
Vue.component('b-nav-text', BNavText)
Vue.component('b-tab', BTab)
Vue.component('b-tabs', BTabs)

Vue.use(TurbolinksAdapter)

document.addEventListener('turbolinks:load', () => {
  new Vue({
    el: '#login',
  })
})
