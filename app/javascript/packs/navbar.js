import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue'
import {NavbarPlugin, ButtonPlugin} from 'bootstrap-vue'
import Navbar from '../components/navbar/App.vue'
import NavbarItem from '../components/navbar/NavbarItem.vue'

Vue.use(TurbolinksAdapter)
Vue.use(NavbarPlugin)
Vue.use(ButtonPlugin)

Vue.component('navbar', Navbar)
Vue.component('NavbarItem', NavbarItem)

document.addEventListener('turbolinks:load', () => {
    new Vue({
        el: '#navbar',
    })
})
