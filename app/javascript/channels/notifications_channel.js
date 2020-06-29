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

// Vue.component('Notification', {
//   template:
//     <div>
//       <h1 style="text-align:center">Comment</h1>
//       <div class="well" id="commentbox" style="height:500px; border: solid 1px #222222; overflow-y: scroll">
//           <p v-bind:key="m" v-for="m in messages"> {{ m.created_at + ' ' + m.user_id.name + ': ' + m.body }} </p>
//       </div>
//       // <!-- %= form_with model: @message do |f| % -->
//       <div class="input-group mb-3" id="inputbar">
//           {/* <!-- <text_field :body, placeholder: "comment", class: 'form-control' /> --> */}
//           <div class="input-group-append">
//               <input type="text" id="comment" placeholder="Comment"></input>
//               <input type="submit" value="submit" on_click="sendMessage"></input>
//           {/* <!-- %= f.submit "Send", class: "btn btn-secondary", on_click: 'sendMessage' % --> */}
//           </div>
//       </div>
//       // <!-- % end % -->
//     </div>
// })

Vue.use(ActionCableVue, {
  debug: true,
  debugLevel: 'error',
  connectImmediately: true,
});

document.addEventListener('turbolinks:load', () => {
  // App.chat = App.cable.subscriptions.create("NotificationsChannel", () =>{
    new Vue({
      // template:
      //   <div>
      //     <h1 style="text-align:center">Comment</h1>
      //   </div>,
      // props: {
      //   messages:{
      //     type: Array,
      //     required: false}
      // },
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
            alert(this.message)
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
