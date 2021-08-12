import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue'
import {ButtonPlugin, BreadcrumbPlugin, FormPlugin, FormGroupPlugin, FormTextareaPlugin} from 'bootstrap-vue'
import Rules from '../components/rules/Rules.vue'
import RulesCodeEditorView from '../components/rules/RulesCodeEditorView.vue'
import RuleComments from '../components/rules/RuleComments.vue'
import RuleHistories from '../components/rules/RuleHistories.vue'
import RuleNavigator from '../components/rules/RuleNavigator.vue'

Vue.use(TurbolinksAdapter)
Vue.use(ButtonPlugin)
Vue.use(BreadcrumbPlugin)
Vue.use(FormPlugin)
Vue.use(FormGroupPlugin)
Vue.use(FormTextareaPlugin)

Vue.component('Rules', Rules)
Vue.component('RulesCodeEditorView', RulesCodeEditorView)
Vue.component('RuleComments', RuleComments)
Vue.component('RuleNavigator', RuleNavigator)
Vue.component('RuleHistories', RuleHistories)


document.addEventListener('turbolinks:load', () => {
    new Vue({
        el: '#Rules',
    })
})
