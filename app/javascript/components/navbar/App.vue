<template>
  <div>
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
            <template v-slot:button-content v-if="num_unread_messages == 0">
              <i class="mdi mdi-bell" aria-hidden="true"></i>
            </template>
            <template v-slot:button-content v-else>
              <i class="mdi mdi-bell-ring" aria-hidden="true"></i>
            </template>
            <div>
              <b-dropdown-item v-bind:key="message" v-bind:href = "profile_path" v-for="message in unread_messages">{{ message }}</b-dropdown-item>
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
  </div>
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
    }
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
