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

consumer.subscriptions.create("NotificationsChannel", () => {
  new Vue({
    channels: {
      ChatChannel: {
        connected() {
          console.log("Connected to notification channel");
        },
        received(data) {
          var messages = $('#inputbar');
          messages.append(data['message']);
          messages.scrollTop(messages[0].scrollHeight);
          // alert($('#commentbar'))
        },
        disconnected() {
          console.log("Disconnected from notification channel");
        }
      }
    }
  })
});
