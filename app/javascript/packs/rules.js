import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue'
import {ButtonPlugin, BreadcrumbPlugin, FormPlugin, FormGroupPlugin, FormTextareaPlugin, BadgePlugin, CollapsePlugin} from 'bootstrap-vue'
import Rules from '../components/rules/Rules.vue'
import RulesCodeEditorView from '../components/rules/RulesCodeEditorView.vue'
import RuleComments from '../components/rules/RuleComments.vue'
import RuleHistories from '../components/rules/RuleHistories.vue'
import RuleNavigator from '../components/rules/RuleNavigator.vue'
import moment from 'moment'

Vue.use(TurbolinksAdapter)
Vue.use(ButtonPlugin)
Vue.use(BreadcrumbPlugin)
Vue.use(FormPlugin)
Vue.use(FormGroupPlugin)
Vue.use(FormTextareaPlugin)
Vue.use(BadgePlugin)
Vue.use(CollapsePlugin)

Vue.component('Rules', Rules)
Vue.component('RulesCodeEditorView', RulesCodeEditorView)
Vue.component('RuleComments', RuleComments)
Vue.component('RuleNavigator', RuleNavigator)
Vue.component('RuleHistories', RuleHistories)

// Based on what the server response is, account for
// generating an alert or notice on the user's screen
Vue.prototype.alertOrNotifyResponse = function(response) {
  let classes = 'alert alert-dismissable fade show ';
  let textContent = '';
  if (response['data'] && response['data']['notice']) {
    classes += ' alert-success';
    textContent = response['data']['notice'];
  }
  else if (response['data'] && response['data']['alert']) {
    classes += 'alert-danger';
    textContent = response['data']['alert'];
  } else {
    // The response did not contain data we can use for an alert or notice.
    return;
  }

  let element = document.createElement('p');
  element.className = classes;
  element.textContent = textContent;
  element.setAttribute('role', 'alert');
  navbar?.insertAdjacentElement('afterend', element);
  setTimeout(function() {element.remove()}, 5000);
}

// Format a date time string like '2021-08-10T19:43:24.950Z'
// into a more readable format.
Vue.prototype.friendlyDateTime = function(dateTimeString) {
  return moment(dateTimeString).format('lll');
}

document.addEventListener('turbolinks:load', () => {
    new Vue({
        el: '#Rules',
    })
})
