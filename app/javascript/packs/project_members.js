import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue'
import {ButtonPlugin} from 'bootstrap-vue'
import ProjectMembers from '../components/project_members/ProjectMembers.vue'
import ProjectMembersTable from '../components/project_members/ProjectMembersTable.vue'
import ProjectMember from '../components/project_members/ProjectMember.vue'
import NewProjectMember from '../components/project_members/NewProjectMember.vue'

Vue.use(TurbolinksAdapter)
Vue.use(ButtonPlugin)

Vue.component('projectmembers', ProjectMembers)
Vue.component('ProjectMembersTable', ProjectMembersTable)
Vue.component('ProjectMember', ProjectMember)
Vue.component('NewProjectMember', NewProjectMember)

document.addEventListener('turbolinks:load', () => {
    new Vue({
        el: '#ProjectMembers',
    })
})
