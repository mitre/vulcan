<template>
  <div>
    <b-navbar toggleable="lg" type="dark" variant="dark">
      <b-navbar-brand id="heading" href="/">
        <i class="mdi mdi-radar" aria-hidden="true" />
        VULCAN
      </b-navbar-brand>

      <b-navbar-toggle target="nav-collapse" />

      <b-collapse id="nav-collapse" is-nav>
        <div class="d-flex w-100 justify-content-lg-center text-lg-center">
          <b-navbar-nav>
            <div v-for="item in navigation" :key="item.name">
              <NavbarItem :icon="item.icon" :link="item.link" :name="item.name" />
            </div>
          </b-navbar-nav>
        </div>

        <div v-if="signed_in" class="d-flex justify-content-between right-container">
          <SrgIdSearch />

          <!-- Right aligned nav items -->
          <b-navbar-nav class="ml-auto">
            <b-nav-item-dropdown right>
              <template #button-content>
                <i class="mdi mdi-account-circle" aria-hidden="true" />
              </template>
              <b-dropdown-item :href="profile_path">Profile</b-dropdown-item>
              <b-dropdown-item v-if="users_path" :href="users_path">Manage Users</b-dropdown-item>
              <b-dropdown-item :href="sign_out_path">Sign Out</b-dropdown-item>
            </b-nav-item-dropdown>
          </b-navbar-nav>
        </div>
      </b-collapse>
    </b-navbar>
  </div>
</template>

<script>
import NavbarItem from "./NavbarItem.vue";
import SrgIdSearch from "./SrgIdSearch.vue";

export default {
  name: "Navbar",
  components: { NavbarItem, SrgIdSearch },
  props: {
    navigation: {
      type: Array,
      required: true,
    },
    signed_in: {
      type: Boolean,
      required: true,
    },
    users_path: {
      type: String,
      required: false,
    },
    profile_path: {
      type: String,
      required: false,
    },
    sign_out_path: {
      type: String,
      required: false,
    },
  },
};
</script>

<style scoped>
#heading {
  font-family: verdana, arial, helvetica, sans-serif;
  font-weight: 700;
  letter-spacing: 1px;
}
.right-container {
  gap: 32px;
}
</style>
