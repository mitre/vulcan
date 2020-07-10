import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue'
import {NavbarPlugin, ButtonPlugin} from 'bootstrap-vue'
import Navbar from '../components/navbar/App.vue'
import NavbarItem from '../components/navbar/NavbarItem.vue'
import moment from 'moment'

Vue.use(TurbolinksAdapter)
Vue.use(NavbarPlugin)
Vue.use(ButtonPlugin)

Vue.filter('formatDate', function(value) {
    if (value) {
        return moment(String(value)).format('MM/DD/YYYY hh:mm a')
    }
});

Vue.component('navbar', Navbar)
Vue.component('NavbarItem', NavbarItem)

document.addEventListener('turbolinks:load', () => {
    new Vue({
        el: '#navbar',
    })
})
