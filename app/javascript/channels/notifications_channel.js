import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue';
import ActionCableVue from 'actioncable-vue';
import NotificationBox from '../components/navbar/NotificationBox.vue'
import BootstrapVue from "bootstrap-vue";
// import moment from "moment"

Vue.use(TurbolinksAdapter)

Vue.component('notificationbox', NotificationBox)

Vue.use(ActionCableVue, {
  debug: true,
  debugLevel: 'error',
  connectImmediately: true
});

Vue.use(BootstrapVue)

// Vue.filter('formatDate', function(value) {
//   if (value) {
//     return moment(String(value)).format('MM/DD/YYYY hh:mm a')
//   }
// });

document.addEventListener('turbolinks:load', () => {
  new Vue({
    props: {
      messages: {
        type: Array,
        required: false
      }
    }
  }).$mount('#notifications')
})
