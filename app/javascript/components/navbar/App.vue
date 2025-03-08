<template>
  <div>
    <b-navbar toggleable="lg" type="dark" variant="dark">
      <b-navbar-brand id="heading" href="/">
        <b-icon icon="broadcast"></b-icon>
        VULCAN
        <b-link href="https://vulcan.mitre.org/CHANGELOG.html" target="_blank">
          <span class="latest-release">{{ currentVersion }}</span>
        </b-link>
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
          <!-- Notification Dropdown -->
          <!-- Right aligned nav items -->
          <b-navbar-nav class="ml-auto">
            <b-nav-item-dropdown right no-caret class="position-relative ml-3">
              <template #button-content>
                <b-icon icon="bell"></b-icon>
                <b-badge
                  v-if="access_requests.length"
                  variant="danger"
                  class="rounded-pill position-absolute top-0 start-100 translate-middle"
                  style="top: 0; right: 0"
                >
                  {{ access_requests.length }}
                </b-badge>
              </template>
              <b-dropdown-item
                v-for="(access_request, index) in access_requests"
                :key="index"
                :href="`/projects/${access_request.project_id}`"
              >
                {{
                  `${access_request.user.name} has requested access to project ${access_request.project.name}`
                }}
              </b-dropdown-item>
            </b-nav-item-dropdown>
            <b-nav-item-dropdown right>
              <template #button-content>
                <b-icon icon="person-circle"></b-icon>
              </template>
              <b-dropdown-item :href="profile_path">Profile</b-dropdown-item>
              <b-dropdown-item v-if="users_path" :href="users_path">Manage Users</b-dropdown-item>
              <b-dropdown-item :href="sign_out_path">Sign Out</b-dropdown-item>
            </b-nav-item-dropdown>
          </b-navbar-nav>
        </div>
      </b-collapse>
    </b-navbar>
    <b-alert
      dismissible
      fade
      :show="updateAvailable"
      class="text-center"
      @dismissed="updateAvailable = false"
    >
      New version: Vulcan {{ latestRelease }} is now available!!
    </b-alert>
  </div>
</template>

<script>
import NavbarItem from "./NavbarItem.vue";
import SrgIdSearch from "./SrgIdSearch.vue";
import { version } from "../../../../package.json";

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
    access_requests: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      latestRelease: "",
      currentVersion: version,
      updateAvailable: false,
    };
  },
  mounted() {
    this.fetchLatestRelease();
  },
  methods: {
    fetchLatestRelease() {
      const owner = "mitre";
      const repo = "vulcan";
      // Make the API request to fetch the latest release
      fetch(`https://api.github.com/repos/${owner}/${repo}/releases/latest`)
        .then((response) => response.json())
        .then((data) => {
          this.latestRelease = data.tag_name.substring(1);
          this.updateAvailable = this.checkUpdateAvailable();
        })
        .catch((error) => {
          this.latestRelease = "";
        });
    },
    checkUpdateAvailable() {
      return this.latestRelease.trim() !== "" && this.latestRelease !== this.currentVersion;
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

.latest-release {
  font-size: 0.6em;
}
.right-container {
  gap: 32px;
}
</style>
