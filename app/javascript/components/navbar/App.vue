<template>
  <div>
    <b-navbar toggleable="xl" type="dark" variant="dark">
      <b-navbar-brand id="heading" href="/">
        <b-icon icon="broadcast" aria-hidden="true" />
        VULCAN
        <b-link href="https://vulcan.mitre.org/CHANGELOG.html" target="_blank">
          <span class="latest-release">{{ currentVersion }}</span>
        </b-link>
      </b-navbar-brand>
      <b-navbar-toggle target="nav-collapse" />

      <b-collapse id="nav-collapse" is-nav>
        <div class="d-flex w-100 justify-content-xl-center text-xl-center">
          <b-navbar-nav>
            <div v-for="item in navigation" :key="item.name">
              <NavbarItem :icon="item.icon" :link="item.link" :name="item.name" />
            </div>
          </b-navbar-nav>
        </div>

        <div
          v-if="signed_in"
          class="d-flex flex-column flex-xl-row align-items-xl-center w-100 mt-2 mt-xl-0 right-container"
        >
          <GlobalSearch />
          <!-- Notification Dropdown -->
          <!-- Right aligned nav items -->
          <b-navbar-nav class="ml-auto">
            <b-nav-item-dropdown right no-caret class="position-relative ml-3">
              <template #button-content>
                <b-icon icon="bell" aria-hidden="true" />
                <b-badge
                  v-if="notificationCount"
                  variant="danger"
                  class="rounded-pill position-absolute top-0 start-100 translate-middle"
                  style="top: 0; right: 0"
                >
                  {{ notificationCount }}
                </b-badge>
              </template>
              <b-dropdown-item
                v-for="(access_request, index) in localAccessRequests"
                :key="'ar-' + index"
                :href="`/projects/${access_request.project_id}`"
              >
                {{
                  `${access_request.user.name} has requested access to project ${access_request.project.name}`
                }}
              </b-dropdown-item>
              <b-dropdown-item
                v-for="locked_user in localLockedUsers"
                :key="'lu-' + locked_user.id"
                :href="`/users?unlock=${locked_user.id}`"
              >
                <b-icon icon="lock" class="mr-1 text-warning" />
                {{ locked_user.name }} ({{ locked_user.email }}) account is locked
              </b-dropdown-item>
            </b-nav-item-dropdown>
            <b-nav-item-dropdown right>
              <template #button-content>
                <b-icon icon="person-circle" aria-hidden="true" />
                <span v-if="userDisplayName" class="ml-2 d-none d-xl-inline">
                  {{ userDisplayName }}
                </span>
              </template>
              <li v-if="userDisplayName" class="px-3 py-2 text-muted small">
                <div class="font-weight-bold text-body">{{ userDisplayName }}</div>
                <div v-if="current_user && current_user.email">{{ current_user.email }}</div>
              </li>
              <b-dropdown-divider v-if="userDisplayName" />
              <b-dropdown-item :href="profile_path">Profile</b-dropdown-item>
              <b-dropdown-item v-if="myCommentsPath" :href="myCommentsPath">
                My Comments
              </b-dropdown-item>
              <b-dropdown-item v-if="users_path" :href="users_path">Manage Users</b-dropdown-item>
              <b-dropdown-divider />
              <b-dropdown-item @click.prevent="signOut">Sign Out</b-dropdown-item>
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
    <ConsentModal v-if="consent_config && consent_config.enabled" :config="consent_config" />
  </div>
</template>

<script>
import axios from "axios";
import semver from "semver";
import FormMixinVue from "../../mixins/FormMixin.vue";
import NavbarItem from "./NavbarItem.vue";
import GlobalSearch from "./GlobalSearch.vue";
import ConsentModal from "../shared/ConsentModal.vue";
import { EVENTS, listen } from "../../utils/notificationEvents";

export default {
  name: "Navbar",
  components: { NavbarItem, GlobalSearch, ConsentModal },
  mixins: [FormMixinVue],
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
    current_user: {
      type: Object,
      required: false,
      default: null,
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
    locked_users: {
      type: Array,
      required: false,
      default: () => [],
    },
    consent_config: {
      type: Object,
      required: false,
      default: () => null,
    },
    app_version: {
      type: String,
      required: false,
      default: "0.0.0",
    },
  },
  data() {
    return {
      latestRelease: "",
      currentVersion: this.app_version,
      updateAvailable: false,
      localLockedUsers: [...this.locked_users],
      localAccessRequests: [...this.access_requests],
      cleanupLockout: null,
      cleanupAccessRequest: null,
    };
  },
  computed: {
    notificationCount() {
      return this.localAccessRequests.length + this.localLockedUsers.length;
    },
    userDisplayName() {
      if (!this.current_user) return null;
      return this.current_user.name || this.current_user.email || null;
    },
    myCommentsPath() {
      if (!this.current_user || !this.current_user.id) return null;
      return `/users/${this.current_user.id}/comments`;
    },
  },
  mounted() {
    this.fetchLatestRelease();
    this.cleanupLockout = listen(EVENTS.LOCKOUT_CHANGED, this.onLockoutChanged);
    this.cleanupAccessRequest = listen(EVENTS.ACCESS_REQUEST_CHANGED, this.onAccessRequestChanged);
  },
  beforeDestroy() {
    if (this.cleanupLockout) this.cleanupLockout();
    if (this.cleanupAccessRequest) this.cleanupAccessRequest();
  },
  methods: {
    onLockoutChanged(event) {
      const { action, user } = event.detail;
      if (action === "locked") {
        if (!this.localLockedUsers.some((u) => u.id === user.id)) {
          this.localLockedUsers.push({ id: user.id, name: user.name, email: user.email });
        }
      } else if (action === "unlocked") {
        this.localLockedUsers = this.localLockedUsers.filter((u) => u.id !== user.id);
      }
    },
    onAccessRequestChanged(event) {
      const { action, id } = event.detail;
      if (action === "resolved") {
        this.localAccessRequests = this.localAccessRequests.filter((r) => r.id !== id);
      }
    },
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
    async signOut() {
      try {
        await axios.delete(this.sign_out_path);
      } catch {
        // Sign-out may return a redirect (302) which axios treats as an error.
        // Either way, navigate to the root to complete sign-out.
      }
      globalThis.location.assign("/");
    },
    checkUpdateAvailable() {
      if (!this.latestRelease || this.latestRelease.trim() === "") return false;

      // Use semver.gt to check if latest is greater than current
      // Clean versions by removing 'v' prefix if present
      const latest = this.latestRelease.replace(/^v/, "");
      const current = this.currentVersion.replace(/^v/, "");

      try {
        return semver.gt(latest, current);
      } catch (error) {
        // Silently handle version comparison errors - likely malformed version strings
        // In this case, don't show the update banner
        return false;
      }
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
