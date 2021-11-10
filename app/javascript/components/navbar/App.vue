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
        <!-- Right aligned nav items -->
        <b-navbar-nav v-if="signed_in" class="ml-auto">
          <b-input-group>
            <b-input-group-prepend>
              <b-input-group-text class="form-control">
                <i class="mdi mdi-magnify" aria-hidden="true" />
              </b-input-group-text>
            </b-input-group-prepend>
            <b-form-input
              id="srg-id-search"
              v-model="searchText"
              debounce="500"
              placeholder="Search by SRG ID"
            />
          </b-input-group>
          <b-popover
            disabled
            :show.sync="show"
            target="srg-id-search"
            placement="bottom"
            custom-class="srg-id-search-results"
          >
            <b-list-group-item href="#some-link">Awesome link</b-list-group-item>
            <b-list-group-item href="#" active>Link with active state</b-list-group-item>
            <b-list-group-item href="#">Action links are easy</b-list-group-item>
            <b-list-group-item href="#foobar" disabled>Disabled link</b-list-group-item>
          </b-popover>
          <b-nav-item-dropdown right>
            <template #button-content>
              <i class="mdi mdi-account-circle" aria-hidden="true" />
            </template>
            <b-dropdown-item :href="profile_path">Profile</b-dropdown-item>
            <b-dropdown-item v-if="users_path" :href="users_path">Manage Users</b-dropdown-item>
            <b-dropdown-item :href="sign_out_path">Sign Out</b-dropdown-item>
          </b-nav-item-dropdown>
        </b-navbar-nav>
      </b-collapse>
    </b-navbar>
  </div>
</template>

<script>
import NavbarItem from "./NavbarItem.vue";

export default {
  name: "Navbar",
  components: { NavbarItem },
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
  data() {
    return {
      show: false,
      searchText: "",
    };
  },
  watch: {
    searchText: function (value) {
      this.show = !!value;
    },
  },
};
</script>

<style>
.srg-id-search-results {
  font-size: large;
  margin-top: 0;
}

.srg-id-search-results > .arrow {
  display: none;
}

.srg-id-search-results > .popover-body {
  padding: 0;
}
</style>

<style scoped>
#heading {
  font-family: verdana, arial, helvetica, sans-serif;
  font-weight: 700;
  letter-spacing: 1px;
}

#srg-id-search {
  margin-right: 16px;
}
</style>
