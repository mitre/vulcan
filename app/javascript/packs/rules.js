import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue'
import {
    ButtonPlugin, BreadcrumbPlugin, FormPlugin, FormGroupPlugin, FormInputPlugin,
    FormTextareaPlugin, BadgePlugin, CollapsePlugin, FormSelectPlugin, FormCheckboxPlugin,
    TooltipPlugin
} from 'bootstrap-vue'
import Rules from '../components/rules/Rules.vue'
import RulesCodeEditorView from '../components/rules/RulesCodeEditorView.vue'
import RuleComments from '../components/rules/RuleComments.vue'
import RuleHistories from '../components/rules/RuleHistories.vue'
import RuleNavigator from '../components/rules/RuleNavigator.vue'
import RuleEditorHeader from '../components/rules/RuleEditorHeader.vue'
import RuleEditor from '../components/rules/RuleEditor.vue'

Vue.use(TurbolinksAdapter)
Vue.use(ButtonPlugin)
Vue.use(BreadcrumbPlugin)
Vue.use(FormPlugin)
Vue.use(FormGroupPlugin)
Vue.use(FormTextareaPlugin)
Vue.use(BadgePlugin)
Vue.use(CollapsePlugin)
Vue.use(FormInputPlugin)
Vue.use(FormSelectPlugin)
Vue.use(FormCheckboxPlugin)
Vue.use(TooltipPlugin)

Vue.component('Rules', Rules)
Vue.component('RulesCodeEditorView', RulesCodeEditorView)
Vue.component('RuleComments', RuleComments)
Vue.component('RuleNavigator', RuleNavigator)
Vue.component('RuleHistories', RuleHistories)
Vue.component('RuleEditorHeader', RuleEditorHeader)
Vue.component('RuleEditor', RuleEditor)

document.addEventListener('turbolinks:load', () => {
    new Vue({
        el: '#Rules',
    })
})
