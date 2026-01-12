<script setup lang="ts">
/**
 * Navbar Component
 *
 * Main navigation bar for the application.
 * Uses composables for color mode and release checking.
 */

import { computed, onMounted } from 'vue'
import AppBanner from '@/components/shared/AppBanner.vue'
import { useColorMode, useReleaseCheck } from '@/composables'
import { primaryModifierSymbol } from '@/composables/useKeyboardShortcuts'
import NavbarItem from './NavbarItem.vue'

// Types
interface INavItem {
  name: string
  link: string
  icon?: string
}

interface IAccessRequest {
  id: number
  project: { id: number, name: string }
  user: { id: number, name: string, email: string }
  created_at: string
}

// Props
defineProps<{
  navigation: INavItem[]
  signed_in: boolean
  users_path?: string
  profile_path?: string
  sign_out_path?: string
  access_requests?: IAccessRequest[]
}>()

// Emits
const emit = defineEmits<{
  openCommandPalette: []
}>()

// Composables
const { colorMode, resolvedMode, cycleColorMode } = useColorMode()
const { currentVersion, latestRelease, updateAvailable, dismissUpdate, fetchLatestRelease } = useReleaseCheck()

// Computed
const colorModeIcon = computed(() => {
  if (colorMode.value === 'auto') return 'bi-circle-half'
  return resolvedMode.value === 'dark' ? 'bi-moon-fill' : 'bi-sun-fill'
})

const colorModeTitle = computed(() => {
  const modes: Record<string, string> = {
    light: 'Light mode',
    dark: 'Dark mode',
    auto: 'System preference',
  }
  return modes[colorMode.value]
})

// Actions
function openCommandPalette() {
  emit('openCommandPalette')
}

// Lifecycle
onMounted(() => {
  fetchLatestRelease()
})
</script>

<template>
  <div>
    <!-- App banner (optional colored bar at top) -->
    <AppBanner />

    <BNavbar v-b-color-mode="'dark'" toggleable="lg" variant="dark" class="navbar-dark bg-dark border-bottom">
      <div class="container-fluid container-app d-flex align-items-center">
        <BNavbarBrand id="heading" href="/">
          <i class="bi bi-broadcast" aria-hidden="true" />
          VULCAN
          <BLink href="https://vulcan.mitre.org/CHANGELOG.html" target="_blank">
            <span class="latest-release">{{ currentVersion }}</span>
          </BLink>
        </BNavbarBrand>
        <BNavbarToggle target="nav-collapse" />

        <BCollapse id="nav-collapse" is-nav>
          <div class="d-flex w-100 justify-content-lg-center text-lg-center">
            <BNavbarNav>
              <div v-for="item in navigation" :key="item.name">
                <NavbarItem :icon="item.icon" :link="item.link" :name="item.name" />
              </div>
            </BNavbarNav>
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
            <BNavbarNav class="ml-auto">
              <!-- Color Mode Toggle -->
              <BNavItem
                class="color-mode-toggle"
                :title="colorModeTitle"
                @click="cycleColorMode"
              >
                <i class="bi" :class="[colorModeIcon]" aria-hidden="true" />
              </BNavItem>
              <!-- Notification Dropdown -->
              <BNavItemDropdown right no-caret class="position-relative ml-3">
                <template #button-content>
                  <i class="bi bi-bell" aria-hidden="true" />
                  <BBadge
                    v-if="access_requests?.length"
                    variant="danger"
                    class="rounded-pill position-absolute top-0 start-100 translate-middle"
                    style="top: 0; right: 0"
                  >
                    {{ access_requests.length }}
                  </BBadge>
                </template>
                <BDropdownItem
                  v-for="(access_request, index) in access_requests"
                  :key="index"
                  :href="`/projects/${access_request.project.id}#members`"
                >
                  {{
                    `${access_request.user.name} has requested access to project ${access_request.project.name}`
                  }}
                </BDropdownItem>
              </BNavItemDropdown>
              <BNavItemDropdown right>
                <template #button-content>
                  <i class="bi bi-person-circle" aria-hidden="true" />
                </template>
                <BDropdownItem :href="profile_path">
                  <i class="bi bi-person-gear me-1" />
                  Account Settings
                </BDropdownItem>
                <BDropdownItem v-if="users_path" href="/admin">
                  <i class="bi bi-gear me-1" />
                  Admin Panel
                </BDropdownItem>
                <BDropdownDivider v-if="users_path" />
                <BDropdownItem :href="sign_out_path">
                  <i class="bi bi-box-arrow-right me-1" />
                  Sign Out
                </BDropdownItem>
              </BNavItemDropdown>
            </BNavbarNav>
          </div>
        </BCollapse>
      </div>
    </BNavbar>
    <BAlert
      dismissible
      fade
      :model-value="updateAvailable"
      class="text-center"
      @update:model-value="dismissUpdate"
    >
      New version: Vulcan {{ latestRelease }} is now available!!
    </BAlert>
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
