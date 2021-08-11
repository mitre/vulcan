import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue'
import {DropdownPlugin} from 'bootstrap-vue'
import Projects from '../components/projects/Projects.vue'
import Project from '../components/projects/Project.vue'

Vue.use(TurbolinksAdapter)
Vue.use(DropdownPlugin)

Vue.component('Projects', Projects)
Vue.component('Project', Project)

document.addEventListener('turbolinks:load', () => {
    new Vue({
        el: '#Projects',
    })
})
