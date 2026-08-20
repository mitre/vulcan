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
      <!-- ── Utility controls — OUTSIDE collapse, always visible ── -->
      <b-navbar-nav
        v-if="signed_in"
        class="utility-nav flex-row align-items-center ml-auto mr-2 order-xl-last"
      >
        <b-nav-item-dropdown right no-caret toggle-class="position-relative">
          <template #button-content>
            <b-icon icon="bell" aria-hidden="true" />
            <b-badge
              v-if="notificationCount"
              variant="danger"
              class="rounded-pill position-absolute"
              style="top: 0; right: 0"
            >
              {{ notificationCount }}
            </b-badge>
          </template>
          <b-dropdown-item
            v-for="(access_request, index) in localAccessRequests"
            :key="'ar-' + index"
            :href="`/projects/${access_request.project.id}?members=1`"
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

        <b-nav-item
          link-classes="text-light px-2"
          aria-label="Toggle dark mode"
          @click="toggleColorMode"
        >
          <b-icon :icon="isDarkMode ? 'sun' : 'moon'" />
        </b-nav-item>

        <b-nav-item-dropdown right no-caret>
          <template #button-content>
            <UserBadge v-if="current_user" :name="userDisplayName" :email="current_user.email" />
            <b-icon v-else icon="person-circle" aria-hidden="true" />
          </template>
          <b-dropdown-text v-if="userDisplayName" class="text-muted small">
            <div class="font-weight-bold text-body">{{ userDisplayName }}</div>
            <div v-if="current_user && current_user.email">{{ current_user.email }}</div>
          </b-dropdown-text>
          <b-dropdown-divider v-if="userDisplayName" />
          <b-dropdown-item :href="profile_path"> Profile </b-dropdown-item>
          <b-dropdown-item v-if="myCommentsPath" :href="myCommentsPath">
            My Comments
          </b-dropdown-item>
          <b-dropdown-item v-if="users_path" :href="users_path"> Manage Users </b-dropdown-item>
          <b-dropdown-divider />
          <!-- Navigational DELETE (rails-ujs data-method): Devise's HTML flow
               sets the signed-out flash and redirects straight to the sign-in
               page, where the Toaster shows it. An ajax DELETE returns 204
               with no flash — the AC-12(02) logoff message never appears. -->
          <b-dropdown-item :href="sign_out_path" data-method="delete">Sign Out</b-dropdown-item>
        </b-nav-item-dropdown>
      </b-navbar-nav>

      <!-- Dark mode toggle for non-signed-in users — also outside collapse -->
      <b-navbar-nav
        v-if="!signed_in"
        class="flex-row align-items-center ml-auto mr-2 order-xl-last"
      >
        <b-nav-item
          link-classes="text-light px-2"
          aria-label="Toggle dark mode"
          @click="toggleColorMode"
        >
          <b-icon :icon="isDarkMode ? 'sun' : 'moon'" />
        </b-nav-item>
      </b-navbar-nav>

      <b-navbar-toggle target="nav-collapse" />

      <!-- ── Collapsible section — nav links + search ── -->
      <b-collapse id="nav-collapse" is-nav>
        <b-navbar-nav class="mr-auto">
          <template v-for="item in navigation">
            <b-nav-item-dropdown
              v-if="item.children"
              :key="item.name"
              right
              no-caret
              toggle-class="nav-item__link"
            >
              <template #button-content>
                <b-icon :icon="item.icon" aria-hidden="true" class="nav-item__icon" />
                <span class="nav-item__label">{{ item.name }}</span>
              </template>
              <b-dropdown-item v-for="child in item.children" :key="child.name" :href="child.link">
                <b-icon v-if="child.icon" :icon="child.icon" class="mr-2" />{{ child.name }}
              </b-dropdown-item>
            </b-nav-item-dropdown>
            <NavbarItem
              v-else
              :key="item.name"
              :icon="item.icon"
              :link="item.link"
              :name="item.name"
            />
          </template>
        </b-navbar-nav>

        <b-nav-form v-if="signed_in">
          <GlobalSearch />
        </b-nav-form>
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
import semver from "semver";
import NavbarItem from "./NavbarItem.vue";
import GlobalSearch from "./GlobalSearch.vue";
import ConsentModal from "../shared/ConsentModal.vue";
import UserBadge from "../shared/UserBadge.vue";
import { EVENTS, listen } from "../../utils/notificationEvents";
import { useThemeStore } from "../../stores/theme";

export default {
  name: "Navbar",
  components: { NavbarItem, GlobalSearch, ConsentModal, UserBadge },
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
      default: null,
    },
    profile_path: {
      type: String,
      default: null,
    },
    current_user: {
      type: Object,
      default: null,
    },
    sign_out_path: {
      type: String,
      default: null,
    },
    access_requests: {
      type: Array,
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
  setup() {
    const themeStore = useThemeStore();
    return { themeStore };
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
    isDarkMode() {
      return this.themeStore.isDark;
    },
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
    this.themeStore.init();
    this.fetchLatestRelease();
    this.cleanupLockout = listen(EVENTS.LOCKOUT_CHANGED, this.onLockoutChanged);
    this.cleanupAccessRequest = listen(EVENTS.ACCESS_REQUEST_CHANGED, this.onAccessRequestChanged);
  },
  beforeDestroy() {
    if (this.cleanupLockout) this.cleanupLockout();
    if (this.cleanupAccessRequest) this.cleanupAccessRequest();
  },
  methods: {
    toggleColorMode() {
      this.themeStore.toggle();
    },
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
      // Uses fetch() intentionally — axios sends X-CSRF-Token globally (FormMixin),
      // which GitHub's CORS policy rejects. fetch() has no global interceptors.
      fetch(`https://api.github.com/repos/${owner}/${repo}/releases/latest`)
        .then((response) => response.json())
        .then((data) => {
          this.latestRelease = data.tag_name.substring(1);
          this.updateAvailable = this.checkUpdateAvailable();
        })
        .catch(() => {
          this.latestRelease = "";
        });
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

/* The utility nav (bell / theme / user menu) sits outside the collapse and
   is always an expanded row, but Bootstrap only restores dropdown
   `position: absolute` above the navbar's expand breakpoint (xl) — below it,
   `.navbar-nav .dropdown-menu` falls back to `position: static` and an open
   menu inflates the navbar instead of overlaying the page (dropdowns are
   CSS-positioned inside navbars; BootstrapVue never runs Popper there).
   Re-apply Bootstrap's own expanded-navbar rule (_navbar.scss) to this
   always-expanded nav so menus float over content at every width — the same
   behavior the bare `.navbar-expand` pattern gives Bootstrap's docs-site
   header. The base `.dropdown-menu` class supplies top: 100% and
   z-index: 1000.

   Menus anchor to the utility nav itself (Bootstrap's documented
   `.position-static`-on-the-dropdown-parent pattern) rather than each <li>,
   so a wide menu (e.g. long notification text) right-aligns to the nav —
   which hugs the viewport edge — instead of overflowing the left edge of
   small screens. The bell badge anchors to the toggle link
   (toggle-class="position-relative"), not the <li>. */
.utility-nav {
  position: relative;
}
.utility-nav >>> .b-nav-dropdown {
  position: static;
}
.utility-nav >>> .dropdown-menu {
  position: absolute;
  right: 0;
  left: auto;
  max-width: calc(100vw - 2rem);
}
/* Dropdown items are nowrap by default — let long notification strings wrap
   inside the capped menu width. */
.utility-nav >>> .dropdown-item {
  white-space: normal;
}

.latest-release {
  font-size: 0.6em;
}
</style>
