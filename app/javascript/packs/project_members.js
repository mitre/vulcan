import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue'
import {ButtonPlugin, PaginationPlugin, TablePlugin} from 'bootstrap-vue'
import ProjectMembers from '../components/project_members/ProjectMembers.vue'
import ProjectMembersTable from '../components/project_members/ProjectMembersTable.vue'
import NewProjectMember from '../components/project_members/NewProjectMember.vue'

Vue.use(TurbolinksAdapter)
Vue.use(ButtonPlugin)
Vue.use(PaginationPlugin)
Vue.use(TablePlugin)

Vue.component('projectmembers', ProjectMembers)
Vue.component('ProjectMembersTable', ProjectMembersTable)
Vue.component('NewProjectMember', NewProjectMember)

document.addEventListener('turbolinks:load', () => {
    new Vue({
        el: '#ProjectMembers',
    })
})
