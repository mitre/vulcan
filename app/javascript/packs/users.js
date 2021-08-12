import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue'
import {ButtonPlugin, PaginationPlugin, TablePlugin} from 'bootstrap-vue'
import Users from '../components/users/Users.vue'
import UsersTable from '../components/users/UsersTable.vue'

Vue.use(TurbolinksAdapter)
Vue.use(ButtonPlugin)
Vue.use(PaginationPlugin)
Vue.use(TablePlugin)

Vue.component('users', Users)
Vue.component('UsersTable', UsersTable)

document.addEventListener('turbolinks:load', () => {
    new Vue({
        el: '#users',
    })
})
