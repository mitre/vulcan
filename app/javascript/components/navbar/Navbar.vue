<template>
    <b-navbar toggleable="lg" type="dark" variant="dark">
      <b-navbar-brand id="heading" href="/">
        <i class="mdi mdi-radar" aria-hidden="true"></i>
        VULCAN
      </b-navbar-brand>

      <b-navbar-toggle target="nav-collapse"></b-navbar-toggle>

      <b-collapse id="nav-collapse" is-nav>
        <div class="d-flex w-100 justify-content-lg-center text-lg-center">
        <b-navbar-nav>
          <div v-bind:key="item.name" v-for="item in navigation">
            <NavbarItem v-bind:icon="item.icon" v-bind:link="item.link" v-bind:name="item.name" :href="item.link" />
          </div>
        </b-navbar-nav>
        </div>
        <!-- Right aligned nav items -->
        <b-navbar-nav class="ml-auto">
          <b-nav-item-dropdown v-if="signed_in" right>
            <!-- if there is a notification change symbol -->
            <template v-slot:button-content v-if="message_notifications == 0">
              <i class="mdi mdi-bell" aria-hidden="true"></i>
            </template>
            <template v-slot:button-content v-else>
              <div id="icon-wrapper">
                <i class="mdi mdi-bell" aria-hidden="true"></i>
                <span id="badge"> {{ message_notifications }} </span>
              </div>
            </template>
            <div v-if="message_notifications == 0">
              <p> No New Notifications </p>
            </div>
            <div v-else style="text-align:center">
              <b-dropdown-item v-bind:key="m.id" v-for="m in messages" :href="navigation[0].link" >
                {{ m.created_at | formatDate }}
                {{ " " + m.user["name"] + ": " + m.body }}
                <b-dropdown-divider></b-dropdown-divider>
              </b-dropdown-item>
              <b-button pill type="button" variant="secondary" size="sm" align-v="center" @click="updateTime">Mark All as Read</b-button>
            </div>
          </b-nav-item-dropdown>
        </b-navbar-nav>

        <b-navbar-nav class="ml-auto">
          <b-nav-item-dropdown v-if="signed_in" right>
            <template v-slot:button-content>
              <i class="mdi mdi-account-circle" aria-hidden="true"></i>
            </template>
            <b-dropdown-item :href="profile_path">Profile</b-dropdown-item>
            <b-dropdown-item :href="sign_out_path">Sign Out</b-dropdown-item>
          </b-nav-item-dropdown>
        </b-navbar-nav>
      </b-collapse>
    </b-navbar>
</template>

<script>
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
    user: {
      type: Object,
      required: true
    }
  },
  data() {
    return {
      messages: this.unread_messages,
      message_notifications: this.num_unread_messages
    }
  },
  channels: {
    NotificationsChannel: {
      connected() {
      },
      received(data) {
        if(JSON.parse(data["message"])["user_id"] != this.user.id){
          this.messages.push(JSON.parse(data["message"]))
          this.message_notifications += 1
        }
      },
      disconnected() {
      }
    }
  },
  methods: {
    markAll: function() {
      this.message_notifications = 0
    },
    updateTime: function() {
      this.$cable.perform({
        channel: 'NotificationsChannel',
        action: 'update_time'
      });
      this.messages = []
      this.message_notifications = 0
    }
  },
  mounted() {
    this.$cable.subscribe({
      channel: 'NotificationsChannel'
    });
  }
}
</script>

<style scoped>
#badge{
    background: #138596;
    height: auto;
    padding-left: 25%;
    padding-right: 25%;
    border-radius: 30%;
    position:absolute;
    top:-5px;
    right:-5px;
    font-size: 10px;
    color: white;
}

#icon-wrapper{
    position:relative;
    float:left;
}

i {
    width:100px;
    text-align:center;
}

</style>
