import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue'
import {ButtonPlugin} from 'bootstrap-vue'
import Users from '../components/users/Users.vue'
import UsersTable from '../components/users/UsersTable.vue'
import User from '../components/users/User.vue'

Vue.use(TurbolinksAdapter)
Vue.use(ButtonPlugin)

Vue.component('users', Users)
Vue.component('UsersTable', UsersTable)
Vue.component('User', User)

document.addEventListener('turbolinks:load', () => {
    new Vue({
        el: '#users',
    })
})
