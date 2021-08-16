import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue'
import {ButtonPlugin, DropdownPlugin, PaginationPlugin, TablePlugin, LinkPlugin} from 'bootstrap-vue'
import Projects from '../components/projects/Projects.vue'
import ProjectsTable from '../components/projects/ProjectsTable.vue'

Vue.use(TurbolinksAdapter)
Vue.use(ButtonPlugin)
Vue.use(DropdownPlugin)
Vue.use(PaginationPlugin)
Vue.use(TablePlugin)
Vue.use(LinkPlugin)

Vue.component('Projects', Projects)
Vue.component('ProjectsTable', ProjectsTable)

document.addEventListener('turbolinks:load', () => {
    new Vue({
        el: '#Projects',
    })
})
