<template>
  <div>
    <Navbar
      :navigation="navigation"
      :sign_out_path="sign_out_path"
      :signed_in="signed_in"
      :profile_path="profile_path"
      :num_unread_messages="num_unread_messages"
      :unread_messages="unread_messages"/>
    <notifications :messages="messages"/>
  </div>
</template>

<script>

import Notifications from './Notifications_channel.vue'
import Navbar from './Navbar.vue'

export default {
  name: 'Navbar',
  props: {
    navigation: {
      type: Array,
      required: true,
    },
    signed_in: {
      type: Boolean,
      required: true
    },
    profile_path: {
      type: String,
      required: false
    },
    sign_out_path: {
      type: String,
      required: false
    },
    num_unread_messages: {
      type: Number,
      required: false,
      default: 0
    },
    unread_messages: {
      type: Array,
      required: false
    },
    messages: {
      type: Array,
      required: false
    }
  },
  name: 'Notifcations',
  components: {
    Notifications,
    Navbar
  }
}
</script>

<style scoped>
#heading {
  font-family: verdana, arial, helvetica, sans-serif;
  font-weight: 700;
  letter-spacing: 1px;
}
</style>
