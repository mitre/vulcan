import consumer from "./consumer"

// consumer.subscriptions.create("NotificationsChannel", {
//   connected() {
//     // Called when the subscription is ready for use on the server
//     alert("Connected to notification channel");
//   },

//   disconnected() {
//     // Called when the subscription has been terminated by the server
//     console.log("Disconnected from notification channel");
//   },

//   received(data) {
//     // Called when there's incoming data on the websocket for this channel
//     // var messages = $('#inputbar');
//     // messages.append(data['message']);
//     // messages.scrollTop(messages[0].scrollHeight);
//     alert($('#commentbar'))
//   }
// });

import Vue from 'vue';
import ActionCableVue from 'actioncable-vue';

Vue.use(ActionCableVue, {
  debug: true,
  debugLevel: 'error',
  connectImmediately: true,
});

document.addEventListener('turbolinks:load', () => {
  // App.chat = App.cable.subscriptions.create("NotificationsChannel", () =>{
    new Vue({
      channels: {
        NotificationsChannel: {
          data() {
            return {
              message: 'Hello world'
            };
          },
          connected() {
            console.log("Connected to notification channel");
          },
          received(data) {
          },
          disconnected() {
            console.log("Disconnected from notification channel");
          }
        }
      },
      methods: {
        sendMessage: function() {
          this.$cable.perform({
            channel: 'NotificationsChannel',
            action: 'send_message',
            data: {
              content: this.message
            }
          });
        }
      },
      mounted() {
        this.$cable.subscribe({
          channel: 'NotificationsChannel'
        });
      },
    }).$mount('#notifications')
  // })
})
