<script>
import semver from 'semver'
import { useColorMode } from '@/composables'
import { primaryModifierSymbol } from '@/composables/useKeyboardShortcuts'
import { version } from '../../../../package.json'
import NavbarItem from './NavbarItem.vue'

export default {
  name: 'Navbar',
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
    access_requests: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['openCommandPalette'],
  setup() {
    const { colorMode, resolvedMode, toggleColorMode, cycleColorMode } = useColorMode()
    return { colorMode, resolvedMode, toggleColorMode, cycleColorMode, primaryModifierSymbol }
  },
  data() {
    return {
      latestRelease: '',
      currentVersion: version,
      updateAvailable: false,
    }
  },
  computed: {
    colorModeIcon() {
      if (this.colorMode === 'auto') return 'bi-circle-half'
      return this.resolvedMode === 'dark' ? 'bi-moon-fill' : 'bi-sun-fill'
    },
    colorModeTitle() {
      const modes = { light: 'Light mode', dark: 'Dark mode', auto: 'System preference' }
      return modes[this.colorMode]
    },
  },
  mounted() {
    this.fetchLatestRelease()
  },
  methods: {
    fetchLatestRelease() {
      const owner = 'mitre'
      const repo = 'vulcan'
      // Make the API request to fetch the latest release
      fetch(`https://api.github.com/repos/${owner}/${repo}/releases/latest`)
        .then(response => response.json())
        .then((data) => {
          this.latestRelease = data.tag_name.substring(1)
          this.updateAvailable = this.checkUpdateAvailable()
        })
        .catch((error) => {
          this.latestRelease = ''
        })
    },
    checkUpdateAvailable() {
      if (!this.latestRelease || this.latestRelease.trim() === '') return false

      // Use semver.gt to check if latest is greater than current
      // Clean versions by removing 'v' prefix if present
      const latest = this.latestRelease.replace(/^v/, '')
      const current = this.currentVersion.replace(/^v/, '')

      try {
        return semver.gt(latest, current)
      }
      catch (error) {
        // Silently handle version comparison errors - likely malformed version strings
        // In this case, don't show the update banner
        return false
      }
    },
    openCommandPalette() {
      this.$emit('openCommandPalette')
    },
  },
}
</script>

<template>
  <div>
    <b-navbar v-b-color-mode="'dark'" toggleable="lg" variant="dark" class="navbar-dark bg-dark border-bottom">
      <div class="container-fluid container-app d-flex align-items-center">
        <b-navbar-brand id="heading" href="/">
          <i class="bi bi-broadcast" aria-hidden="true" />
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
            <!-- Global Search Button -->
            <button
              type="button"
              class="btn btn-outline-light btn-sm d-flex align-items-center gap-2"
              title="Search (Cmd+J)"
              @click="openCommandPalette"
            >
              <i class="bi bi-search" />
              <span class="d-none d-md-inline">Search</span>
              <kbd class="d-none d-lg-inline ms-1">{{ primaryModifierSymbol }}J</kbd>
            </button>
            <!-- Right aligned nav items -->
            <b-navbar-nav class="ml-auto">
              <!-- Color Mode Toggle -->
              <b-nav-item
                class="color-mode-toggle"
                :title="colorModeTitle"
                @click="cycleColorMode"
              >
                <i class="bi" :class="[colorModeIcon]" aria-hidden="true" />
              </b-nav-item>
              <!-- Notification Dropdown -->
              <b-nav-item-dropdown right no-caret class="position-relative ml-3">
                <template #button-content>
                  <i class="bi bi-bell" aria-hidden="true" />
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
                  <i class="bi bi-person-circle" aria-hidden="true" />
                </template>
                <b-dropdown-item :href="profile_path">
                  Profile
                </b-dropdown-item>
                <b-dropdown-item v-if="users_path" :href="users_path">
                  Manage Users
                </b-dropdown-item>
                <b-dropdown-item :href="sign_out_path">
                  Sign Out
                </b-dropdown-item>
              </b-nav-item-dropdown>
            </b-navbar-nav>
          </div>
        </b-collapse>
      </div>
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
.color-mode-toggle {
  cursor: pointer;
}
.color-mode-toggle :deep(.nav-link) {
  padding: 0.5rem 0.75rem;
}
.color-mode-toggle i {
  font-size: 1.1rem;
  transition: transform 0.2s ease;
}
.color-mode-toggle:hover i {
  transform: rotate(15deg);
}
/* Search button keyboard hint */
.btn kbd {
  padding: 0.125rem 0.25rem;
  font-size: 0.625rem;
  font-family: var(--bs-font-monospace);
  background-color: rgba(255, 255, 255, 0.15);
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 3px;
}
</style>
