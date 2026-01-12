<script setup lang="ts">
import { computed, onMounted, watch } from 'vue'
import { RouterView, useRoute } from 'vue-router'
import AuthHeader from '@/components/auth/AuthHeader.vue'
import Navbar from '@/components/navbar/App.vue'
import AppFooter from '@/components/shared/AppFooter.vue'
import CommandPalette from '@/components/shared/CommandPalette.vue'
import ErrorBoundary from '@/components/shared/ErrorBoundary.vue'
import PageContainer from '@/components/shared/PageContainer.vue'
import PageSpinner from '@/components/shared/PageSpinner.vue'
import Toaster from '@/components/toaster/Toaster.vue'
import { useColorMode, useCommandPalette } from '@/composables'
import { useAuthStore, useNavigationStore } from '@/stores'

const route = useRoute()

const authStore = useAuthStore()
const navigationStore = useNavigationStore()

// Command palette composable (manages open state, Cmd+J shortcut)
const { open: showCommandPalette } = useCommandPalette()

// Initialize color mode early to prevent flash
useColorMode()

// Determine if we should show simplified header (login page, etc.)
const showSimpleHeader = computed(() => {
  // Show simple header for login and other auth pages
  const authRoutes = ['/users/sign_in', '/auth/confirmation', '/auth/unlock', '/auth/reset-password']
  return authRoutes.includes(route.path) || !authStore.signedIn
})

// Fetch navigation when auth state changes
watch(
  () => authStore.signedIn,
  (signedIn) => {
    if (signedIn) {
      navigationStore.fetchNavigation()
    }
    else {
      navigationStore.reset()
    }
  },
)

onMounted(() => {
  // Fetch navigation if user is already signed in
  if (authStore.signedIn) {
    navigationStore.fetchNavigation()
  }
})
</script>

<template>
  <BApp>
    <div class="app-container">
      <!-- Command Palette (Cmd+J) - only show when authenticated -->
      <CommandPalette v-if="authStore.signedIn" />

      <!-- Toast container - positioned absolutely -->
      <div class="toast-container">
        <Toaster />
      </div>

      <!-- Header -->
      <AuthHeader v-if="showSimpleHeader" class="app-header" />
      <header v-else id="navbar" class="app-header shadow-sm">
        <Navbar
          :navigation="navigationStore.links"
          :signed_in="authStore.signedIn"
          :users_path="authStore.isAdmin ? '/users' : ''"
          profile_path="/account/settings"
          sign_out_path="/users/sign_out"
          :access_requests="navigationStore.accessRequests"
          @open-command-palette="showCommandPalette = true"
        />
      </header>

      <!-- Main content - scrolls if needed -->
      <main class="app-main bg-body-secondary">
        <RouterView v-slot="{ Component }">
          <template v-if="Component">
            <ErrorBoundary>
              <Suspense>
                <component :is="Component" />
                <template #fallback>
                  <PageContainer>
                    <PageSpinner message="Loading..." />
                  </PageContainer>
                </template>
              </Suspense>
            </ErrorBoundary>
          </template>
        </RouterView>
      </main>

      <!-- Footer -->
      <AppFooter class="app-footer" />
    </div>
  </BApp>
</template>

<style>
.app-container {
  display: grid;
  grid-template-rows: auto 1fr auto;
  height: 100vh;
  width: 100%;
}

.app-header {
  grid-row: 1;
}

.app-main {
  grid-row: 2;
  overflow-y: auto;
  min-height: 0;
}

.app-footer {
  grid-row: 3;
}

.toast-container {
  position: fixed;
  top: 1rem;
  right: 1rem;
  z-index: 9999;
}
</style>

