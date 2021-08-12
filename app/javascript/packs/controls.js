import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue'
import {ButtonPlugin, BreadcrumbPlugin, FormPlugin, FormGroupPlugin, FormTextareaPlugin} from 'bootstrap-vue'
import Controls from '../components/controls/Controls.vue'
import ControlsCodeEditorView from '../components/controls/ControlsCodeEditorView.vue'
import ControlComments from '../components/controls/ControlComments.vue'
import ControlHistories from '../components/controls/ControlHistories.vue'
import ControlNavigator from '../components/controls/ControlNavigator.vue'

Vue.use(TurbolinksAdapter)
Vue.use(ButtonPlugin)
Vue.use(BreadcrumbPlugin)
Vue.use(FormPlugin)
Vue.use(FormGroupPlugin)
Vue.use(FormTextareaPlugin)

Vue.component('Controls', Controls)
Vue.component('ControlsCodeEditorView', ControlsCodeEditorView)
Vue.component('ControlComments', ControlComments)
Vue.component('ControlNavigator', ControlNavigator)
Vue.component('ControlHistories', ControlHistories)


document.addEventListener('turbolinks:load', () => {
    new Vue({
        el: '#Controls',
    })
})
