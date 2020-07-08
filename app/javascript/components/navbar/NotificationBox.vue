<template>
  <div>
    <h1 style="text-align:center">Comment</h1>
    <div class="well" id="commentbox" style="height:500px; border: solid 1px #222222; overflow-y: scroll">
        <p v-bind:key="m.id" v-for="m in allmessages">
          {{ m.created_at + ' ' + m.user_id + ': ' + m.body }}
        </p>
    </div>
    <div>
      <b-form>
        <b-form-input id="comment" placeholder="Comment" v-model="comment" trim></b-form-input>
        <b-button type="submit" variant="secondary" @click="sendMessage">Submit</b-button>
      </b-form>
    </div>
  </div>
</template>

<script>

export default {
  name: 'NotificationBox',
  props: {
    messages: {
      type: Array,
      required: false
    },
    users: {
      type: Array,
      required: false
    }
  },
  data() {
    return {
      allmessages: this.messages,
      comment: null,
      dateFormatConfig: {
        dayOfWeekNames: [
          'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
          'Friday', 'Saturday'
        ],
        dayOfWeekNamesShort: [
          'Su', 'Mo', 'Tu', 'We', 'Tr', 'Fr', 'Sa'
        ],
        monthNames: [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ],
        monthNamesShort: [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ]
      }
    };
  },
  channels: {
    NotificationsChannel: {
      connected() {
        console.log("Connected");
      },
      received(data) {
        this.allmessages = [...this.allmessages, JSON.parse(data["message"])]
        if (Notification.permission === 'granted'){
          var title = 'Notification'
          var body = JSON.parse(data["message"])
          var temp = body.created_at + ' ' + body.user_id + ': ' + body.body
          var options = {body: temp}
          new Notification(title, options)
        }
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
          content: this.comment
        }
      });
    }
  },
  mounted() {
    this.$cable.subscribe({
      channel: 'NotificationsChannel'
    });
  }
}

</script>
