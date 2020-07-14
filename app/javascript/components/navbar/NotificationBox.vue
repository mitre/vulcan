<template>
  <div>
    <h1 style="text-align:center">Comment</h1>
    <div class="well" id="commentbox" style="height:500px; border: solid 1px #222222; overflow-y: scroll">
        <p v-bind:key="m.id" v-for="m in allmessages">
          {{ formattedDate(m.created_at) }}
          {{ " " + m.user["name"] + ": " + m.body }}
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
    }
  },
  data() {
    return {
      allmessages: this.messages,
      comment: null
    };
  },
  channels: {
    NotificationsChannel: {
      connected() {
      },
      received(data) {
        this.allmessages = [...this.allmessages, JSON.parse(data["message"])]
        if (Notification.permission === 'granted'){
          var title = 'Notification Channel Alert'
          var body = JSON.parse(data["message"])
          var msg = body.user["name"] + ": " + body.body
          var options = {body: msg}
          new Notification(title, options)
        }
      },
      disconnected() {
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
    },
    formattedDate: function(d){
      let arr = d.split(/[\D]/);
      let date = new Date(Date.UTC(arr[0], arr[1]-1, arr[2], arr[3], arr[4], arr[5]));
      let min = date.getUTCMinutes()
      let hour = date.getUTCHours()
      let ampm = "am"
      if (min < 10) {
        min = "0" + min
      }
      if (hour > 12){
        hour = hour - 12
        ampm = "pm"
      }
      return (date.getMonth() + 1) + "/" + date.getDate() + "/" + date.getFullYear() + " " + hour + ":" + min + " " + ampm
    }
  },
  mounted() {
    this.$cable.subscribe({
      channel: 'NotificationsChannel'
    });
  }
}

</script>
