import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue'
import {ButtonPlugin, BreadcrumbPlugin} from 'bootstrap-vue'
import Controls from '../components/controls/Controls.vue'
import ControlsCodeEditorView from '../components/controls/ControlsCodeEditorView.vue'
import ControlComments from '../components/controls/ControlComments.vue'
import ControlNavigator from '../components/controls/ControlNavigator.vue'

Vue.use(TurbolinksAdapter)
Vue.use(ButtonPlugin)
Vue.use(BreadcrumbPlugin)

Vue.component('Controls', Controls)
Vue.component('ControlsCodeEditorView', ControlsCodeEditorView)
Vue.component('ControlComments', ControlComments)
Vue.component('ControlNavigator', ControlNavigator)

document.addEventListener('turbolinks:load', () => {
    new Vue({
        el: '#Controls',
    })
})
