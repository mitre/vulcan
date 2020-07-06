import TurbolinksAdapter from 'vue-turbolinks'
import Vue from 'vue';
import ActionCableVue from 'actioncable-vue';
import NotificationBox from '../components/navbar/NotificationBox.vue'
import BootstrapVue from "bootstrap-vue";

Vue.use(TurbolinksAdapter)

Vue.component('notificationbox', NotificationBox)

Vue.use(ActionCableVue, {
  debug: true,
  debugLevel: 'error',
  connectImmediately: true
});

Vue.use(BootstrapVue)

document.addEventListener('turbolinks:load', () => {
  new Vue({
    props: {
      messages: {
        type: Array,
        required: false
      }
    },
    methods: {
      send(){
        alert("message")
      }
    }
  }).$mount('#notifications')
})
